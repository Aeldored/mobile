import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/models/network_model.dart';
import '../data/services/firebase_service.dart';
import '../data/services/wifi_scanning_service.dart';
import '../data/services/access_point_service.dart';
import '../data/services/current_connection_service.dart';
import '../data/services/permission_service.dart';
import '../data/services/wifi_connection_service.dart';
import '../data/services/enhanced_wifi_service.dart';
import '../data/models/security_assessment.dart';
import '../data/repositories/whitelist_repository.dart';
import 'alert_provider.dart';

class NetworkProvider extends ChangeNotifier {
  List<NetworkModel> _networks = [];
  List<NetworkModel> _filteredNetworks = [];
  NetworkModel? _currentNetwork;
  bool _isLoading = false;
  bool _isScanning = false;
  double _scanProgress = 0.0;
  DateTime? _lastScanTime;
  String _searchQuery = '';
  final Set<String> _blockedNetworkIds = {};
  final Set<String> _trustedNetworkIds = {};
  final Set<String> _flaggedNetworkIds = {};
  final Map<String, NetworkStatus> _originalStatuses = {}; // Track original statuses before user modifications
  AlertProvider? _alertProvider;
  bool _hasPerformedScan = false;
  int _scanSessionId = 0;
  final Set<String> _alertedNetworksThisSession = <String>{};
  bool _isManualScan = false;
  
  // Scan statistics
  int _totalNetworksFound = 0;
  int _verifiedNetworksFound = 0;
  int _suspiciousNetworksFound = 0;
  int _threatsDetected = 0;
  
  // Firebase integration
  FirebaseService? _firebaseService;
  WhitelistRepository? _whitelistRepository;
  WhitelistData? _currentWhitelist;
  bool _firebaseEnabled = false;
  
  // Wi-Fi scanning integration
  final WiFiScanningService _wifiScanner = WiFiScanningService();
  bool _wifiScanningEnabled = false;
  
  // Access Point Service integration
  final AccessPointService _accessPointService = AccessPointService();
  
  // Wi-Fi Connection Service integration
  final WiFiConnectionService _wifiConnectionService = WiFiConnectionService();
  
  // Current connection service
  final CurrentConnectionService _currentConnectionService = CurrentConnectionService();
  
  // Permission service
  final PermissionService _permissionService = PermissionService();
  bool _hasLocationPermission = false;
  bool _hasWifiPermission = false;
  
  // Enhanced security service integration
  final EnhancedWiFiService _enhancedWifiService = EnhancedWiFiService();
  final Map<String, SecurityAssessment> _securityAssessments = {};
  bool _securityAnalysisEnabled = false;

  List<NetworkModel> get networks => _networks;
  List<NetworkModel> get filteredNetworks => _filteredNetworks;
  NetworkModel? get currentNetwork => _currentNetwork;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  double get scanProgress => _scanProgress;
  DateTime? get lastScanTime => _lastScanTime;
  bool get firebaseEnabled => _firebaseEnabled;
  bool get wifiScanningEnabled => _wifiScanningEnabled;
  bool get hasLocationPermission => _hasLocationPermission;
  bool get hasWifiPermission => _hasWifiPermission;
  bool get hasRequiredPermissions => _hasLocationPermission && _hasWifiPermission;
  WhitelistData? get currentWhitelist => _currentWhitelist;
  bool get hasPerformedScan => _hasPerformedScan;
  Set<String> get trustedNetworks => Set.from(_trustedNetworkIds);
  Set<String> get blockedNetworks => Set.from(_blockedNetworkIds);
  Set<String> get flaggedNetworks => Set.from(_flaggedNetworkIds);
  int get currentScanSessionId => _scanSessionId;
  
  // Scan statistics getters
  int get totalNetworksFound => _totalNetworksFound;
  int get verifiedNetworksFound => _verifiedNetworksFound;
  int get suspiciousNetworksFound => _suspiciousNetworksFound;
  int get threatsDetected => _threatsDetected;
  
  // Security assessment getters
  bool get securityAnalysisEnabled => _securityAnalysisEnabled;
  Map<String, SecurityAssessment> get securityAssessments => Map.from(_securityAssessments);
  
  /// Get security assessment for a specific network
  SecurityAssessment? getSecurityAssessment(String networkId) {
    return _securityAssessments[networkId];
  }
  
  /// Get all high-risk networks
  List<NetworkModel> get highRiskNetworks => _networks.where((network) {
    final assessment = _securityAssessments[network.id];
    return assessment?.shouldAvoidConnection == true;
  }).toList();
  
  /// Get all safe networks
  List<NetworkModel> get safeNetworks => _networks.where((network) {
    final assessment = _securityAssessments[network.id];
    return assessment?.isSafeToConnect == true;
  }).toList();

  NetworkProvider() {
    _initializeMockData();
    _initializeWiFiScanning();
    _initializeAccessPointService();
    _initializeCurrentConnection();
    _initializeSecurityAnalysis();
    loadUserPreferences();
  }

  /// Initialize Wi-Fi scanning service
  Future<void> _initializeWiFiScanning() async {
    try {
      _wifiScanningEnabled = await _wifiScanner.initialize();
      if (_wifiScanningEnabled) {
        developer.log('Wi-Fi scanning enabled successfully');
      } else {
        developer.log('Wi-Fi scanning not available, using mock data');
      }
    } catch (e) {
      developer.log('Wi-Fi scanning initialization failed: $e');
      _wifiScanningEnabled = false;
    }
  }

  /// Initialize Access Point Service
  Future<void> _initializeAccessPointService() async {
    try {
      await _accessPointService.initialize();
      developer.log('Access Point Service initialized successfully');
    } catch (e) {
      developer.log('Access Point Service initialization failed: $e');
    }
  }

  /// Initialize current connection monitoring
  Future<void> _initializeCurrentConnection() async {
    try {
      // Get initial current connection
      await refreshCurrentConnection();
      
      // Listen for connection changes
      _currentConnectionService.watchConnectionChanges().listen((network) {
        _currentNetwork = network;
        notifyListeners();
        developer.log('Connection changed: ${network?.name ?? 'Disconnected'}');
      });
      
      developer.log('Current connection monitoring initialized');
    } catch (e) {
      developer.log('Current connection initialization failed: $e');
    }
  }

  /// Refresh current connection information
  Future<void> refreshCurrentConnection() async {
    try {
      _currentNetwork = await _currentConnectionService.getCurrentConnection();
      notifyListeners();
      developer.log('Current connection refreshed: ${_currentNetwork?.name ?? 'None'}');
    } catch (e) {
      developer.log('Error refreshing current connection: $e');
    }
  }

  /// Initialize enhanced security analysis
  Future<void> _initializeSecurityAnalysis() async {
    try {
      developer.log('🛡️ Initializing enhanced security analysis...');
      
      final initialized = await _enhancedWifiService.initialize();
      _securityAnalysisEnabled = initialized;
      
      if (_securityAnalysisEnabled) {
        // Listen to security assessment updates
        _enhancedWifiService.securityAssessmentStream.listen((assessments) {
          _securityAssessments.clear();
          for (final assessment in assessments) {
            _securityAssessments[assessment.networkId] = assessment;
          }
          
          // Update threat statistics
          _updateThreatStatistics();
          notifyListeners();
          
          developer.log('🛡️ Security assessments updated: ${assessments.length} networks analyzed');
        });
        
        developer.log('✅ Enhanced security analysis initialized successfully');
      } else {
        developer.log('⚠️ Enhanced security analysis not available - continuing with basic mode');
      }
    } catch (e) {
      developer.log('❌ Failed to initialize security analysis: $e');
      _securityAnalysisEnabled = false;
    }
  }

  /// Update threat statistics based on security assessments
  void _updateThreatStatistics() {
    if (!_securityAnalysisEnabled) return;
    
    var threats = 0;
    var suspicious = 0;
    
    for (final assessment in _securityAssessments.values) {
      threats += assessment.detectedThreats.length;
      
      if (assessment.threatLevel == ThreatLevel.high || 
          assessment.threatLevel == ThreatLevel.critical) {
        suspicious++;
      }
    }
    
    _threatsDetected = threats;
    _suspiciousNetworksFound = suspicious;
  }

  /// Check and request required permissions
  Future<bool> checkAndRequestPermissions() async {
    try {
      final currentStatus = await _permissionService.checkAllPermissions();
      developer.log('Current permission status: $currentStatus');
      
      // Update individual permission states
      await _updatePermissionStates();
      
      if (currentStatus == PermissionStatus.granted) {
        developer.log('All permissions already granted');
        return true;
      }
      
      if (currentStatus == PermissionStatus.permanentlyDenied) {
        developer.log('Permissions permanently denied - cannot request again');
        return false;
      }
      
      // Don't auto-request permissions - let the UI handle this
      developer.log('Permissions not granted: $currentStatus');
      return false;
    } catch (e) {
      developer.log('Error checking permissions: $e');
      return false;
    }
  }

  /// Update individual permission states
  Future<void> _updatePermissionStates() async {
    try {
      final locationStatus = await _permissionService.checkLocationPermission();
      final wifiStatus = await _permissionService.checkWifiPermissions();
      
      _hasLocationPermission = locationStatus == PermissionStatus.granted;
      _hasWifiPermission = wifiStatus == PermissionStatus.granted;
      
      developer.log('Permission states - Location: $_hasLocationPermission, WiFi: $_hasWifiPermission');
      notifyListeners();
    } catch (e) {
      developer.log('Error updating permission states: $e');
      _hasLocationPermission = false;
      _hasWifiPermission = false;
      notifyListeners();
    }
  }

  /// Request Wi-Fi scanning permissions
  Future<bool> requestWiFiScanningPermissions() async {
    try {
      final results = await _permissionService.requestAllPermissions();
      await _updatePermissionStates();
      
      final allGranted = results.values.every((status) => status == PermissionStatus.granted);
      if (allGranted) {
        _wifiScanningEnabled = true;
        developer.log('Wi-Fi scanning permissions granted and enabled');
        notifyListeners();
        return true;
      } else {
        developer.log('Wi-Fi scanning permissions not fully granted');
        notifyListeners();
        return false;
      }
    } catch (e) {
      developer.log('Error requesting Wi-Fi scanning permissions: $e');
      notifyListeners();
      return false;
    }
  }

  void setAlertProvider(AlertProvider alertProvider) {
    _alertProvider = alertProvider;
  }

  // Initialize Firebase integration
  Future<void> initializeFirebase(SharedPreferences prefs) async {
    try {
      _firebaseService = FirebaseService();
      _whitelistRepository = WhitelistRepository(
        firebaseService: _firebaseService!,
        prefs: prefs,
      );
      
      _firebaseEnabled = true;
      
      // Load whitelist
      await refreshWhitelist();
      
      // Listen for whitelist updates
      _whitelistRepository!.whitelistUpdates().listen((metadata) {
        developer.log('Whitelist updated: v${metadata.version}');
        refreshWhitelist();
      });
      
      developer.log('Firebase integration initialized successfully');
    } catch (e) {
      developer.log('Firebase initialization failed: $e');
      _firebaseEnabled = false;
    }
  }

  // Refresh whitelist from Firebase
  Future<void> refreshWhitelist() async {
    if (!_firebaseEnabled || _whitelistRepository == null) return;
    
    try {
      final data = await _whitelistRepository!.getWhitelist();
      if (data != null) {
        _currentWhitelist = data;
        developer.log('Whitelist loaded: ${data.accessPoints.length} access points');
        notifyListeners();
      }
    } catch (e) {
      developer.log('Error refreshing whitelist: $e');
    }
  }

  // Check if network is whitelisted
  bool isNetworkWhitelisted(String macAddress) {
    if (!_firebaseEnabled || _whitelistRepository == null) return false;
    return _whitelistRepository!.isNetworkWhitelisted(macAddress, _currentWhitelist);
  }

  // Report suspicious network to Firebase
  Future<void> reportSuspiciousNetwork(NetworkModel network) async {
    if (!_firebaseEnabled || _firebaseService == null) return;
    
    try {
      await _firebaseService!.submitThreatReport(
        network: network,
        latitude: network.latitude ?? 14.2117, // Fallback to Calamba coordinates
        longitude: network.longitude ?? 121.1644,
        deviceId: 'device_${DateTime.now().millisecondsSinceEpoch}', // Generate unique device ID
        additionalInfo: 'Reported as suspicious from mobile app',
      );
      developer.log('Threat report submitted for network: ${network.name}');
    } catch (e) {
      developer.log('Error reporting network: $e');
    }
  }

  // Log scan event to Firebase Analytics
  Future<void> logScanEvent() async {
    if (!_firebaseEnabled || _firebaseService == null) return;
    
    try {
      final threatsDetected = _networks.where((n) => n.status == NetworkStatus.suspicious).length;
      await _firebaseService!.logScan(
        networksFound: _networks.length,
        threatsDetected: threatsDetected,
        scanType: 'manual_scan',
      );
    } catch (e) {
      developer.log('Error logging scan event: $e');
    }
  }

  void _initializeMockData() {
    // Initialize with empty network list - networks will be populated during scans
    _networks = [];
    
    // No mock current network - will be detected by CurrentConnectionService
    _currentNetwork = null;
    
    // Update filtered networks with current search query
    _updateFilteredNetworks();
  }

  /// Start a new network scan with progress tracking
  Future<void> startNetworkScan({bool forceRescan = false, bool isManualScan = false}) async {
    if (_isScanning && !forceRescan) return;
    
    _isScanning = true;
    _isLoading = true;
    _scanProgress = 0.0;
    _scanSessionId++;
    _lastScanTime = DateTime.now();
    _isManualScan = isManualScan;
    
    // Reset statistics
    _totalNetworksFound = 0;
    _verifiedNetworksFound = 0;
    _suspiciousNetworksFound = 0;
    _threatsDetected = 0;
    
    notifyListeners();

    try {
      // Check permissions before scanning
      _scanProgress = 0.1;
      notifyListeners();
      
      final hasPermissions = await checkAndRequestPermissions();
      if (!hasPermissions) {
        developer.log('Insufficient permissions for scanning, using mock data');
        await _performRealisticScanWithProgress();
      } else if (_wifiScanningEnabled) {
        await _performRealWiFiScanWithProgress();
      } else if (_firebaseEnabled && _currentWhitelist != null) {
        await _performFirebaseEnhancedScanWithProgress();
      } else {
        await _performRealisticScanWithProgress();
      }

      // Update networks with saved status first
      await _updateNetworksWithSavedStatus();
      
      // Apply user-defined statuses after updating with saved status
      _applyUserDefinedStatuses();
      
      // Calculate final statistics
      _calculateScanStatistics();
      
      // Mark that we've performed a scan
      _hasPerformedScan = true;

      // Perform enhanced security analysis if available
      await _performSecurityAnalysis();

      // Generate real-time threat alerts
      await _generateScanBasedAlerts();

      // Log scan event to Firebase Analytics
      await logScanEvent();
    } catch (e) {
      developer.log('Error during network scan: $e');
      await _performRealisticScanWithProgress();
      await _updateNetworksWithSavedStatus();
      _applyUserDefinedStatuses();
      _calculateScanStatistics();
      _hasPerformedScan = true;
    }

    _isScanning = false;
    _isLoading = false;
    _scanProgress = 1.0;
    
    // Ensure filtered networks are properly updated with current search query
    _updateFilteredNetworks();
    
    // Final notification to ensure all tabs are updated
    notifyListeners();
    
    // Log scan completion for debugging
    developer.log('Scan completed: $_totalNetworksFound networks found, $_threatsDetected threats detected');
  }
  
  /// Stop ongoing scan
  void stopNetworkScan() {
    _isScanning = false;
    _scanProgress = 1.0;
    notifyListeners();
  }
  
  /// Legacy method for backward compatibility
  Future<void> loadNearbyNetworks() async {
    await startNetworkScan();
  }
  
  /// Update networks with saved status information
  Future<void> _updateNetworksWithSavedStatus() async {
    try {
      final updatedNetworks = await _wifiConnectionService.checkForAutoConnect(_networks);
      _networks = updatedNetworks;
      developer.log('Updated ${_networks.length} networks with saved status');
    } catch (e) {
      developer.log('Error updating networks with saved status: $e');
    }
  }

  // Unused method - reserved for future real Wi-Fi scanning implementation
  /* Future<void> _performRealWiFiScan() async {
    developer.log('Performing real Wi-Fi scan...');
    
    // Clear existing networks
    _networks.clear();
    notifyListeners();
    
    try {
      // Perform Wi-Fi scan
      final scannedNetworks = await _wifiScanner.performScan();
      
      // Process and validate scanned networks
      _networks = scannedNetworks;
      
      // Perform evil twin detection on real scan results
      _performEvilTwinDetection();
      
      // Cross-reference with whitelist if available
      if (_firebaseEnabled && _currentWhitelist != null) {
        _crossReferenceWithWhitelist();
      }
      
      // Generate alerts for suspicious networks
      _generateAlertsForSuspiciousNetworks();
      
      // Auto-report suspicious networks to Firebase
      if (_firebaseEnabled) {
        for (final network in _networks.where((n) => n.status == NetworkStatus.suspicious)) {
          await reportSuspiciousNetwork(network);
        }
      }
      
      // Set current network (check if we're connected to any of the scanned networks)
      await _identifyCurrentNetwork();
      
      developer.log('Real Wi-Fi scan completed: ${_networks.length} networks found');
      
    } catch (e) {
      developer.log('Real Wi-Fi scan failed: $e');
      // Fall back to mock data
      await _performRealisticScan();
    }
    
    // Update filtered networks with current search query
    _updateFilteredNetworks();
  } */

  /// Cross-reference scanned networks with Firebase whitelist
  void _crossReferenceWithWhitelist() {
    for (int i = 0; i < _networks.length; i++) {
      final network = _networks[i];
      if (isNetworkWhitelisted(network.macAddress)) {
        _networks[i] = network.copyWith(
          status: NetworkStatus.verified,
          description: '${network.description} (Verified via DICT whitelist)',
        );
      }
    }
  }

  /// Identify current connected network from scan results
  Future<void> _identifyCurrentNetwork() async {
    try {
      // Get actual current connection using CurrentConnectionService
      final actualCurrentNetwork = await _currentConnectionService.getCurrentConnection();
      
      if (actualCurrentNetwork != null) {
        // Update the global current network
        _currentNetwork = actualCurrentNetwork;
        
        // Try to find matching network in scan results and mark as connected
        final matchingNetworkIndex = _networks.indexWhere((network) => 
          network.name.toLowerCase() == actualCurrentNetwork.name.toLowerCase() ||
          (network.macAddress.isNotEmpty && 
           actualCurrentNetwork.macAddress.isNotEmpty &&
           network.macAddress.toLowerCase() == actualCurrentNetwork.macAddress.toLowerCase())
        );
        
        if (matchingNetworkIndex != -1) {
          // Update the scanned network to mark as connected
          _networks[matchingNetworkIndex] = _networks[matchingNetworkIndex].copyWith(
            isConnected: true,
            ipAddress: actualCurrentNetwork.ipAddress,
          );
          
          // Use the scanned network data (which has more complete threat analysis)
          // but preserve the connection status and IP from current connection
          _currentNetwork = _networks[matchingNetworkIndex];
          developer.log('Matched current connection "${actualCurrentNetwork.name}" with scanned network');
        } else {
          developer.log('Current connection "${actualCurrentNetwork.name}" not found in scan results');
        }
      } else {
        // No current connection, clear current network
        _currentNetwork = null;
        
        // Ensure no scanned networks are marked as connected
        for (int i = 0; i < _networks.length; i++) {
          if (_networks[i].isConnected) {
            _networks[i] = _networks[i].copyWith(isConnected: false);
          }
        }
        developer.log('No current Wi-Fi connection detected');
      }
    } catch (e) {
      developer.log('Error identifying current network: $e');
      
      // Fallback to previous mock behavior
      if (_networks.isNotEmpty) {
        final strongestNetwork = _networks.reduce((a, b) => 
          a.signalStrength > b.signalStrength ? a : b);
        
        if ((strongestNetwork.status == NetworkStatus.verified || 
             strongestNetwork.status == NetworkStatus.trusted) &&
            strongestNetwork.signalStrength > 80) {
          
          final index = _networks.indexWhere((n) => n.id == strongestNetwork.id);
          if (index != -1) {
            _networks[index] = strongestNetwork.copyWith(isConnected: true);
            _currentNetwork = _networks[index];
          }
        }
      }
    }
  }

  // Unused method - reserved for future Firebase enhanced scanning
  /* Future<void> _performFirebaseEnhancedScan() async {
    // Clear existing networks
    _networks.clear();
    
    // Simulate scanning delay with progressive discovery
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Add verified networks from Firebase whitelist (simulated as nearby)
    if (_currentWhitelist != null) {
      final nearbyWhitelistedAPs = _currentWhitelist!.accessPoints
          .where((ap) => ap.status == 'active')
          .take(3) // Simulate only some being nearby
          .toList();
      
      for (final ap in nearbyWhitelistedAPs) {
        _networks.add(NetworkModel(
          id: 'whitelist_${ap.id}',
          name: ap.ssid,
          description: 'DICT Verified Access Point - ${ap.city}, ${ap.province}',
          status: NetworkStatus.verified,
          securityType: SecurityType.wpa2,
          signalStrength: 75 + (ap.ssid.hashCode % 20), // Simulate signal strength
          macAddress: ap.macAddress,
          latitude: ap.latitude,
          longitude: ap.longitude,
          lastSeen: DateTime.now(),
          isConnected: ap.ssid == 'DICT-CALABARZON-OFFICIAL', // Simulate connection to main network
        ));
      }
    }
    
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Add some commercial networks (mix of verified and unknown)
    _networks.addAll([
      NetworkModel(
        id: 'commercial_1',
        name: 'SM_WiFi',
        description: 'SM Calamba',
        status: NetworkStatus.verified,
        securityType: SecurityType.wpa2,
        signalStrength: 60,
        macAddress: 'A1:B2:C3:D4:E5:F6',
        latitude: 14.2050,
        longitude: 121.1580,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      NetworkModel(
        id: 'commercial_2',
        name: 'PLDT_HomeWiFi_5G',
        description: 'Private Network',
        status: NetworkStatus.unknown,
        securityType: SecurityType.wpa3,
        signalStrength: 90,
        macAddress: '11:22:33:44:55:66',
        latitude: 14.2080,
        longitude: 121.1600,
        lastSeen: DateTime.now(),
      ),
    ]);
    
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1200));
    
    // Add potentially suspicious networks (evil twins) - enhanced with Firebase verification
    final suspiciousNetworks = _generateEvilTwinNetworks();
    _networks.addAll(suspiciousNetworks);
    
    // Verify networks against whitelist
    for (int i = 0; i < _networks.length; i++) {
      final network = _networks[i];
      if (network.status == NetworkStatus.unknown) {
        // Check if MAC address is in whitelist
        if (isNetworkWhitelisted(network.macAddress)) {
          _networks[i] = NetworkModel(
            id: network.id,
            name: network.name,
            description: '${network.description} (Verified via whitelist)',
            status: NetworkStatus.verified,
            securityType: network.securityType,
            signalStrength: network.signalStrength,
            macAddress: network.macAddress,
            latitude: network.latitude,
            longitude: network.longitude,
            lastSeen: network.lastSeen,
            isConnected: network.isConnected,
          );
        }
      }
    }
    
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Add some unknown networks
    _networks.addAll([
      NetworkModel(
        id: 'unknown_1',
        name: 'Coffee_Shop_WiFi',
        description: 'Unknown location',
        status: NetworkStatus.unknown,
        securityType: SecurityType.open,
        signalStrength: 45,
        macAddress: 'B1:C2:D3:E4:F5:A6',
        latitude: 14.2090,
        longitude: 121.1610,
        lastSeen: DateTime.now(),
      ),
      NetworkModel(
        id: 'unknown_2',
        name: 'Guest_Network',
        description: 'Unknown network',
        status: NetworkStatus.unknown,
        securityType: SecurityType.wep,
        signalStrength: 55,
        macAddress: 'C1:D2:E3:F4:A5:B6',
        latitude: 14.2070,
        longitude: 121.1590,
        lastSeen: DateTime.now(),
      ),
    ]);
    
    // Perform evil twin detection
    _performEvilTwinDetection();
    
    // Generate alerts for suspicious networks and report them
    _generateAlertsForSuspiciousNetworks();
    
    // Auto-report suspicious networks to Firebase
    for (final network in _networks.where((n) => n.status == NetworkStatus.suspicious)) {
      await reportSuspiciousNetwork(network);
    }
    
    // Set current network if not already set
    if (_currentNetwork == null) {
      final connectedNetwork = _networks.firstWhere(
        (n) => n.isConnected, 
        orElse: () => _networks.isNotEmpty && _networks.any((n) => n.status == NetworkStatus.verified) 
            ? _networks.firstWhere((n) => n.status == NetworkStatus.verified).copyWith(isConnected: true)
            : _networks.isNotEmpty 
                ? _networks.first.copyWith(isConnected: true) 
                : NetworkModel(
                    id: 'mock_connected',
                    name: 'DICT-CALABARZON-OFFICIAL',
                    description: 'DICT Public Access Point',
                    status: NetworkStatus.verified,
                    securityType: SecurityType.wpa2,
                    signalStrength: 85,
                    macAddress: '00:1A:2B:3C:4D:5E',
                    latitude: 14.2117,
                    longitude: 121.1644,
                    lastSeen: DateTime.now(),
                    isConnected: true,
                  ),
      );
      _currentNetwork = connectedNetwork;
      
      // Update the network in the list to show it as connected
      if (_networks.isNotEmpty) {
        final index = _networks.indexWhere((n) => n.id == _currentNetwork!.id);
        if (index != -1) {
          _networks[index] = _currentNetwork!;
        }
      }
    }
    
    // Update filtered networks with current search query
    _updateFilteredNetworks();
  } */


  List<NetworkModel> _generateEvilTwinNetworks() {
    final DateTime now = DateTime.now();
    return [
      // Evil twin of DICT network
      NetworkModel(
        id: 'evil_1',
        name: 'DICT-CALABARZON-FREE', // Suspicious variant
        description: 'Suspicious network mimicking government WiFi',
        status: NetworkStatus.suspicious,
        securityType: SecurityType.open, // Red flag: open when original is secured
        signalStrength: 95, // Suspiciously strong signal
        macAddress: 'FF:FF:FF:FF:FF:FF', // Suspicious MAC
        latitude: 14.2115, // Very close to legitimate network
        longitude: 121.1642,
        lastSeen: now.subtract(const Duration(minutes: 1)),
      ),
      // Evil twin of commercial network
      NetworkModel(
        id: 'evil_2',
        name: 'SM_Free_WiFi', // Variant of SM_WiFi
        description: 'Potentially malicious network',
        status: NetworkStatus.suspicious,
        securityType: SecurityType.open,
        signalStrength: 85,
        macAddress: 'AA:BB:CC:DD:EE:FF',
        latitude: 14.2048,
        longitude: 121.1578,
        lastSeen: now.subtract(const Duration(minutes: 3)),
      ),
      // Generic evil twin
      NetworkModel(
        id: 'evil_3',
        name: 'FREE_WiFi_CalambaCity',
        description: 'Suspicious open network',
        status: NetworkStatus.suspicious,
        securityType: SecurityType.open,
        signalStrength: 75,
        macAddress: 'DE:AD:BE:EF:CA:FE',
        latitude: 14.2100,
        longitude: 121.1650,
        lastSeen: now.subtract(const Duration(minutes: 2)),
      ),
    ];
  }

  void _performEvilTwinDetection() {
    final Map<String, List<NetworkModel>> networkGroups = {};
    
    // Group networks by similar names
    for (var network in _networks) {
      final normalizedName = _normalizeNetworkName(network.name);
      networkGroups.putIfAbsent(normalizedName, () => []).add(network);
    }
    
    // Detect potential evil twins
    for (var entry in networkGroups.entries) {
      if (entry.value.length > 1) {
        final networks = entry.value;
        
        // Find the most legitimate network (secured, known MAC, etc.)
        final legitimate = networks.firstWhere(
          (n) => n.status == NetworkStatus.verified || 
                 n.securityType != SecurityType.open,
          orElse: () => networks.first,
        );
        
        // Mark others as suspicious if they don't match the legitimate one
        for (var network in networks) {
          if (network.id != legitimate.id) {
            final index = _networks.indexWhere((n) => n.id == network.id);
            if (index != -1) {
              _networks[index] = NetworkModel(
                id: network.id,
                name: network.name,
                description: 'Potential evil twin of ${legitimate.name}',
                status: NetworkStatus.suspicious,
                securityType: network.securityType,
                signalStrength: network.signalStrength,
                macAddress: network.macAddress,
                latitude: network.latitude,
                longitude: network.longitude,
                lastSeen: network.lastSeen,
                isConnected: network.isConnected,
              );
            }
          }
        }
      }
    }
  }

  String _normalizeNetworkName(String name) {
    // Remove common variations and normalize for comparison
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-\s]'), '')
        .replaceAll('free', '')
        .replaceAll('wifi', '')
        .replaceAll('public', '')
        .replaceAll('guest', '');
  }

  void filterNetworks(String query) {
    _searchQuery = query.toLowerCase();
    _updateFilteredNetworks();
    notifyListeners();
  }
  
  void _updateFilteredNetworks() {
    if (_searchQuery.isEmpty) {
      _filteredNetworks = List.from(_networks);
    } else {
      _filteredNetworks = _networks.where((network) {
        return network.name.toLowerCase().contains(_searchQuery) ||
            (network.description?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }
  }
  
  /// Get network by ID with current status
  NetworkModel? getNetworkById(String networkId) {
    try {
      return _networks.firstWhere((n) => n.id == networkId);
    } catch (e) {
      return null;
    }
  }
  
  /// Check if network is currently trusted
  bool isNetworkTrusted(String networkId) {
    return _trustedNetworkIds.contains(networkId);
  }
  
  /// Check if network is currently blocked
  bool isNetworkBlocked(String networkId) {
    return _blockedNetworkIds.contains(networkId);
  }
  
  /// Check if network is currently flagged
  bool isNetworkFlagged(String networkId) {
    return _flaggedNetworkIds.contains(networkId);
  }
  
  /// Get all networks with current user-applied statuses
  List<NetworkModel> getNetworksWithStatus(NetworkStatus status) {
    return _networks.where((n) => n.status == status).toList();
  }
  
  /// Force refresh UI for all tabs
  void forceUIRefresh() {
    // Ensure filtered networks are up to date
    _updateFilteredNetworks();
    notifyListeners();
  }
  
  /// Get the AccessPointService instance for external access
  AccessPointService get accessPointService => _accessPointService;
  
  /// Check if the last scan detected any new threats
  bool get hasNewThreatsFromLastScan => _threatsDetected > 0 && _hasPerformedScan;
  
  /// Get a summary of the last scan results
  String getLastScanSummary() {
    if (!_hasPerformedScan) return 'No scan performed yet';
    
    final String threatText = _threatsDetected > 0 
        ? '$_threatsDetected threat${_threatsDetected == 1 ? '' : 's'} detected'
        : 'No threats detected';
    
    return 'Found $_totalNetworksFound network${_totalNetworksFound == 1 ? '' : 's'}, $threatText';
  }

  /// Perform enhanced security analysis on discovered networks
  Future<void> _performSecurityAnalysis() async {
    if (!_securityAnalysisEnabled || _networks.isEmpty) {
      developer.log('🛡️ Security analysis skipped: enabled=$_securityAnalysisEnabled, networks=${_networks.length}');
      return;
    }

    try {
      developer.log('🛡️ Starting security analysis for ${_networks.length} networks...');
      
      // Trigger security analysis through enhanced service
      await _enhancedWifiService.scanNetworksWithSecurityAnalysis();
      
      // The results will come through the stream listener we set up in _initializeSecurityAnalysis
      developer.log('🛡️ Security analysis triggered successfully');
      
    } catch (e) {
      developer.log('❌ Error during security analysis: $e');
    }
  }
  
  /// Debug method to check network sync status
  void debugNetworkSync() {
    developer.log('=== NetworkProvider Debug ===');
    developer.log('_networks.length: ${_networks.length}');
    developer.log('_filteredNetworks.length: ${_filteredNetworks.length}');
    developer.log('_searchQuery: "$_searchQuery"');
    developer.log('_hasPerformedScan: $_hasPerformedScan');
    developer.log('_isScanning: $_isScanning');
    developer.log('_isLoading: $_isLoading');
    developer.log('Trusted Networks: $_trustedNetworkIds');
    developer.log('Blocked Networks: $_blockedNetworkIds');
    developer.log('Flagged Networks: $_flaggedNetworkIds');
    developer.log('Networks: ${_networks.map((n) => n.name).join(', ')}');
    developer.log('Filtered: ${_filteredNetworks.map((n) => n.name).join(', ')}');
    developer.log('=============================');
  }
  
  /// Debug method to verify AccessPointService synchronization
  Future<void> debugAccessPointSync() async {
    developer.log('=== AccessPointService Sync Debug ===');
    try {
      final trustedAPs = await _accessPointService.getTrustedAccessPoints();
      final blockedAPs = await _accessPointService.getBlockedAccessPoints();
      final flaggedAPs = await _accessPointService.getFlaggedAccessPoints();
      
      developer.log('AccessPointService Trusted: ${trustedAPs.map((n) => n.name).join(', ')}');
      developer.log('AccessPointService Blocked: ${blockedAPs.map((n) => n.name).join(', ')}');
      developer.log('AccessPointService Flagged: ${flaggedAPs.map((n) => n.name).join(', ')}');
      developer.log('=====================================');
    } catch (e) {
      developer.log('Error checking AccessPointService sync: $e');
    }
  }


  /// Trust a network - mark it as safe and allow direct connection
  Future<void> trustNetwork(String networkId) async {
    _trustedNetworkIds.add(networkId);
    _blockedNetworkIds.remove(networkId);
    _flaggedNetworkIds.remove(networkId);
    
    // Find the network and generate alert
    final network = _networks.firstWhere((n) => n.id == networkId, orElse: () => NetworkModel(
      id: networkId,
      name: 'Unknown Network',
      description: 'Network details not available',
      status: NetworkStatus.trusted,
      securityType: SecurityType.open,
      signalStrength: 0,
      macAddress: '00:00:00:00:00:00',
      lastSeen: DateTime.now(),
    ));
    
    // Generate alert for trusted network
    if (_alertProvider != null) {
      _alertProvider!.generateTrustedNetworkAlert(network);
    }
    
    // Sync with AccessPointService
    try {
      await _accessPointService.trustAccessPoint(network);
    } catch (e) {
      developer.log('Failed to sync trusted network with AccessPointService: $e');
    }
    
    await _saveUserPreferences();
    _applyUserDefinedStatuses();
    notifyListeners();
    
    // Force refresh of filtered networks to ensure all tabs update
    filterNetworks(_searchQuery);
  }

  /// Flag a network - mark it as suspicious but still allow connection with warning
  Future<void> flagNetwork(String networkId) async {
    _flaggedNetworkIds.add(networkId);
    _trustedNetworkIds.remove(networkId);
    
    final network = _networks.firstWhere((n) => n.id == networkId, orElse: () => NetworkModel(
      id: networkId,
      name: 'Unknown Network',
      description: 'Network details not available',
      status: NetworkStatus.flagged,
      securityType: SecurityType.open,
      signalStrength: 0,
      macAddress: '00:00:00:00:00:00',
      lastSeen: DateTime.now(),
    ));
    
    // Generate alert for flagged network
    if (_alertProvider != null) {
      _alertProvider!.generateFlaggedNetworkAlert(network);
    }
    
    // Sync with AccessPointService
    try {
      await _accessPointService.flagAccessPoint(network);
    } catch (e) {
      developer.log('Failed to sync flagged network with AccessPointService: $e');
    }
    
    await _saveUserPreferences();
    _applyUserDefinedStatuses();
    notifyListeners();
  }

  /// Block a network - hide it from all lists and prevent connection
  Future<void> blockNetwork(String networkId) async {
    final network = _networks.firstWhere((n) => n.id == networkId, orElse: () => NetworkModel(
      id: networkId,
      name: 'Unknown Network',
      description: 'Network details not available',
      status: NetworkStatus.blocked,
      securityType: SecurityType.open,
      signalStrength: 0,
      macAddress: '00:00:00:00:00:00',
      lastSeen: DateTime.now(),
    ));
    
    _blockedNetworkIds.add(networkId);
    _trustedNetworkIds.remove(networkId);
    _flaggedNetworkIds.remove(networkId);
    
    // Generate alert for blocked network
    if (_alertProvider != null) {
      _alertProvider!.generateBlockedNetworkAlert(network);
    }
    
    // Sync with AccessPointService
    try {
      await _accessPointService.blockAccessPoint(network);
    } catch (e) {
      developer.log('Failed to sync blocked network with AccessPointService: $e');
    }
    
    await _saveUserPreferences();
    _applyUserDefinedStatuses();
    notifyListeners();
  }

  /// Remove trust from a network
  Future<void> untrustNetwork(String networkId) async {
    _trustedNetworkIds.remove(networkId);
    
    // Find the network for AccessPointService sync
    final network = _networks.firstWhere((n) => n.id == networkId, orElse: () => NetworkModel(
      id: networkId,
      name: 'Unknown Network',
      description: 'Network details not available',
      status: NetworkStatus.unknown,
      securityType: SecurityType.open,
      signalStrength: 0,
      macAddress: '00:00:00:00:00:00',
      lastSeen: DateTime.now(),
    ));
    
    // Sync with AccessPointService
    try {
      await _accessPointService.untrustAccessPoint(network);
    } catch (e) {
      developer.log('Failed to sync untrusted network with AccessPointService: $e');
    }
    
    await _saveUserPreferences();
    _applyUserDefinedStatuses();
    notifyListeners();
  }

  /// Remove flag from a network
  Future<void> unflagNetwork(String networkId) async {
    _flaggedNetworkIds.remove(networkId);
    
    // Find the network for AccessPointService sync
    final network = _networks.firstWhere((n) => n.id == networkId, orElse: () => NetworkModel(
      id: networkId,
      name: 'Unknown Network',
      description: 'Network details not available',
      status: NetworkStatus.unknown,
      securityType: SecurityType.open,
      signalStrength: 0,
      macAddress: '00:00:00:00:00:00',
      lastSeen: DateTime.now(),
    ));
    
    // Sync with AccessPointService
    try {
      await _accessPointService.unflagAccessPoint(network);
    } catch (e) {
      developer.log('Failed to sync unflagged network with AccessPointService: $e');
    }
    
    await _saveUserPreferences();
    _applyUserDefinedStatuses();
    notifyListeners();
  }

  /// Unblock a network
  Future<void> unblockNetwork(String networkId) async {
    _blockedNetworkIds.remove(networkId);
    
    // Find the network for AccessPointService sync
    final network = _networks.firstWhere((n) => n.id == networkId, orElse: () => NetworkModel(
      id: networkId,
      name: 'Unknown Network',
      description: 'Network details not available',
      status: NetworkStatus.unknown,
      securityType: SecurityType.open,
      signalStrength: 0,
      macAddress: '00:00:00:00:00:00',
      lastSeen: DateTime.now(),
    ));
    
    // Sync with AccessPointService
    try {
      await _accessPointService.unblockAccessPoint(network);
    } catch (e) {
      developer.log('Failed to sync unblocked network with AccessPointService: $e');
    }
    
    await _saveUserPreferences();
    _applyUserDefinedStatuses();
    notifyListeners();
  }

  Future<void> connectToNetwork(String networkId) async {
    // Disconnect from current network
    if (_currentNetwork != null) {
      final index = _networks.indexWhere((n) => n.id == _currentNetwork!.id);
      if (index != -1) {
        _networks[index] = NetworkModel(
          id: _currentNetwork!.id,
          name: _currentNetwork!.name,
          description: _currentNetwork!.description,
          status: _currentNetwork!.status,
          securityType: _currentNetwork!.securityType,
          signalStrength: _currentNetwork!.signalStrength,
          macAddress: _currentNetwork!.macAddress,
          latitude: _currentNetwork!.latitude,
          longitude: _currentNetwork!.longitude,
          lastSeen: _currentNetwork!.lastSeen,
          isConnected: false,
        );
      }
    }

    // Connect to new network
    final networkIndex = _networks.indexWhere((n) => n.id == networkId);
    if (networkIndex != -1) {
      final network = _networks[networkIndex];
      _networks[networkIndex] = NetworkModel(
        id: network.id,
        name: network.name,
        description: network.description,
        status: network.status,
        securityType: network.securityType,
        signalStrength: network.signalStrength,
        macAddress: network.macAddress,
        latitude: network.latitude,
        longitude: network.longitude,
        lastSeen: network.lastSeen,
        isConnected: true,
      );
      _currentNetwork = _networks[networkIndex];
    }

    // Refresh filtered list
    filterNetworks(_searchQuery);
    notifyListeners();
  }

  List<NetworkModel> getNetworksForMap() {
    return _networks.where((n) => n.latitude != null && n.longitude != null).toList();
  }

  /// Refresh the networks list to reflect any status changes
  Future<void> refreshNetworks() async {
    await loadNearbyNetworks();
  }

  /// Check if Wi-Fi scanning permissions are granted
  Future<bool> hasWiFiScanningPermissions() async {
    return await _wifiScanner.hasRequiredPermissions();
  }
  
  /// Refresh permission status (called by SettingsProvider)
  Future<void> refreshPermissionStatus() async {
    try {
      final hasPermissions = await checkAndRequestPermissions();
      if (hasPermissions && !_wifiScanningEnabled) {
        _wifiScanningEnabled = await _wifiScanner.initialize();
        notifyListeners();
        developer.log('Wi-Fi scanning re-enabled after permission grant');
      }
    } catch (e) {
      developer.log('Error refreshing permission status: $e');
    }
  }
  
  /// Start background scanning (called by SettingsProvider)
  Future<void> startBackgroundScanning() async {
    try {
      if (_wifiScanningEnabled) {
        // Start periodic background scans
        developer.log('Starting background Wi-Fi scanning');
        // Implementation would start a timer for periodic scans
        // For now, just log the intent
      }
    } catch (e) {
      developer.log('Error starting background scanning: $e');
    }
  }
  
  /// Stop background scanning (called by SettingsProvider)
  Future<void> stopBackgroundScanning() async {
    try {
      developer.log('Stopping background Wi-Fi scanning');
      // Implementation would stop the background scan timer
      // For now, just log the intent
    } catch (e) {
      developer.log('Error stopping background scanning: $e');
    }
  }
  
  /// Clear all network data (called when clearing app data)
  Future<void> clearNetworkData() async {
    try {
      _networks.clear();
      _filteredNetworks.clear();
      _currentNetwork = null;
      _blockedNetworkIds.clear();
      _trustedNetworkIds.clear();
      _flaggedNetworkIds.clear();
      _originalStatuses.clear();
      _alertedNetworksThisSession.clear();
      _hasPerformedScan = false;
      _scanSessionId = 0;
      
      // Reset statistics
      _totalNetworksFound = 0;
      _verifiedNetworksFound = 0;
      _suspiciousNetworksFound = 0;
      _threatsDetected = 0;
      
      // Save cleared state
      await _saveUserPreferences();
      
      notifyListeners();
      developer.log('Network data cleared successfully');
    } catch (e) {
      developer.log('Error clearing network data: $e');
      throw Exception('Failed to clear network data: $e');
    }
  }

  /// Start continuous Wi-Fi scanning (for real-time updates)
  Stream<List<NetworkModel>>? startContinuousScanning() {
    if (_wifiScanningEnabled) {
      return _wifiScanner.startContinuousScanning();
    }
    return null;
  }

  /// Stop continuous Wi-Fi scanning
  void stopContinuousScanning() {
    _wifiScanner.stopContinuousScanning();
  }

  /// Apply user-defined statuses to networks
  void _applyUserDefinedStatuses() {
    bool hasChanges = false;
    
    for (int i = 0; i < _networks.length; i++) {
      final network = _networks[i];
      
      // Store original status if not already stored and not user-managed
      if (!_originalStatuses.containsKey(network.id) && !network.isUserManaged) {
        _originalStatuses[network.id] = network.status;
      }
      
      NetworkStatus newStatus;
      bool isUserManaged = false;
      
      // Check if this network has user-defined status overrides
      if (_blockedNetworkIds.contains(network.id)) {
        newStatus = NetworkStatus.blocked;
        isUserManaged = true;
      } else if (_trustedNetworkIds.contains(network.id)) {
        newStatus = NetworkStatus.trusted;
        isUserManaged = true;
      } else if (_flaggedNetworkIds.contains(network.id)) {
        newStatus = NetworkStatus.flagged;
        isUserManaged = true;
      } else {
        // No user-defined status, restore original or keep current
        newStatus = _originalStatuses[network.id] ?? network.status;
        isUserManaged = _originalStatuses.containsKey(network.id) && network.isUserManaged;
      }
      
      if (newStatus != network.status || isUserManaged != network.isUserManaged) {
        _networks[i] = network.copyWith(
          status: newStatus,
          isUserManaged: isUserManaged,
          lastActionDate: isUserManaged ? DateTime.now() : network.lastActionDate,
        );
        
        // Update current network if it's the same network
        if (_currentNetwork?.id == network.id) {
          _currentNetwork = _networks[i];
        }
        
        hasChanges = true;
      }
    }
    
    // Update filtered networks only if there were changes
    if (hasChanges) {
      filterNetworks(_searchQuery);
      
      // Recalculate statistics to reflect status changes
      _calculateScanStatistics();
    }
  }

  /// Save user preferences to SharedPreferences
  Future<void> _saveUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('trusted_networks', _trustedNetworkIds.toList());
      await prefs.setStringList('blocked_networks', _blockedNetworkIds.toList());
      await prefs.setStringList('flagged_networks', _flaggedNetworkIds.toList());
      
      // Save original statuses
      final originalStatusesJson = <String>[];
      _originalStatuses.forEach((networkId, status) {
        originalStatusesJson.add('$networkId:${status.toString().split('.').last}');
      });
      await prefs.setStringList('original_statuses', originalStatusesJson);
    } catch (e) {
      developer.log('Error saving user preferences: $e');
    }
  }

  /// Load user preferences from SharedPreferences
  Future<void> loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _trustedNetworkIds.addAll(prefs.getStringList('trusted_networks') ?? []);
      _blockedNetworkIds.addAll(prefs.getStringList('blocked_networks') ?? []);
      _flaggedNetworkIds.addAll(prefs.getStringList('flagged_networks') ?? []);
      
      // Load original statuses
      final originalStatusesJson = prefs.getStringList('original_statuses') ?? [];
      for (final entry in originalStatusesJson) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          final networkId = parts[0];
          final statusName = parts[1];
          try {
            final status = NetworkStatus.values.firstWhere(
              (e) => e.toString().split('.').last == statusName,
            );
            _originalStatuses[networkId] = status;
          } catch (e) {
            developer.log('Error parsing original status for $networkId: $e');
          }
        }
      }
    } catch (e) {
      developer.log('Error loading user preferences: $e');
    }
  }

  /// Check if connection should show warning
  bool shouldShowConnectionWarning(String networkId) {
    return _flaggedNetworkIds.contains(networkId) || 
           _networks.any((n) => n.id == networkId && n.status == NetworkStatus.suspicious);
  }

  /// Get connection warning message
  String getConnectionWarningMessage(String networkId) {
    final network = _networks.firstWhere((n) => n.id == networkId, orElse: () => NetworkModel(
      id: networkId,
      name: 'Unknown Network',
      description: 'Network details not available',
      status: NetworkStatus.unknown,
      securityType: SecurityType.open,
      signalStrength: 0,
      macAddress: '00:00:00:00:00:00',
      lastSeen: DateTime.now(),
    ));
    
    if (network.status == NetworkStatus.suspicious) {
      return 'This network has been identified as potentially malicious. Connecting may put your device at risk.';
    } else if (_flaggedNetworkIds.contains(networkId)) {
      return 'You have flagged this network as suspicious. Proceed with caution.';
    } else {
      return 'This network is not verified. Use caution when connecting.';
    }
  }
  
  /// Add verified government networks
  Future<void> _addVerifiedGovernmentNetworks() async {
    _networks.addAll([
      NetworkModel(
        id: 'gov_1',
        name: 'DICT-CALABARZON-OFFICIAL',
        description: 'DICT Public Access Point',
        status: NetworkStatus.verified,
        securityType: SecurityType.wpa2,
        signalStrength: 85,
        macAddress: '00:1A:2B:3C:4D:5E',
        latitude: 14.2117,
        longitude: 121.1644,
        lastSeen: DateTime.now(),
        isConnected: true,
      ),
      NetworkModel(
        id: 'gov_2',
        name: 'GOV-PH-SECURE',
        description: 'Government Network',
        status: NetworkStatus.verified,
        securityType: SecurityType.wpa3,
        signalStrength: 78,
        macAddress: '00:1A:2B:3C:4D:5F',
        latitude: 14.2120,
        longitude: 121.1650,
        lastSeen: DateTime.now(),
      ),
    ]);
  }
  
  /// Add commercial networks
  Future<void> _addCommercialNetworks() async {
    _networks.addAll([
      NetworkModel(
        id: 'commercial_1',
        name: 'SM_WiFi',
        description: 'SM Calamba',
        status: NetworkStatus.verified,
        securityType: SecurityType.wpa2,
        signalStrength: 60,
        macAddress: 'A1:B2:C3:D4:E5:F6',
        latitude: 14.2050,
        longitude: 121.1580,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      NetworkModel(
        id: 'commercial_2',
        name: 'PLDT_HomeWiFi_5G',
        description: 'Private Network',
        status: NetworkStatus.verified,
        securityType: SecurityType.wpa3,
        signalStrength: 90,
        macAddress: '11:22:33:44:55:66',
        latitude: 14.2080,
        longitude: 121.1600,
        lastSeen: DateTime.now(),
      ),
    ]);
  }
  
  /// Add suspicious networks (evil twins)
  Future<void> _addSuspiciousNetworks() async {
    final suspiciousNetworks = _generateEvilTwinNetworks();
    _networks.addAll(suspiciousNetworks);
    _performEvilTwinDetection();
  }
  
  /// Add unknown networks
  Future<void> _addUnknownNetworks() async {
    _networks.addAll([
      NetworkModel(
        id: 'unknown_1',
        name: 'Coffee_Shop_WiFi',
        description: 'Unknown location',
        status: NetworkStatus.unknown,
        securityType: SecurityType.open,
        signalStrength: 45,
        macAddress: 'B1:C2:D3:E4:F5:A6',
        latitude: 14.2090,
        longitude: 121.1610,
        lastSeen: DateTime.now(),
      ),
      NetworkModel(
        id: 'unknown_2',
        name: 'Guest_Network',
        description: 'Unknown network',
        status: NetworkStatus.unknown,
        securityType: SecurityType.wep,
        signalStrength: 55,
        macAddress: 'C1:D2:E3:F4:A5:B6',
        latitude: 14.2070,
        longitude: 121.1590,
        lastSeen: DateTime.now(),
      ),
    ]);
  }
  
  /// Perform realistic scan with progress tracking
  Future<void> _performRealisticScanWithProgress() async {
    _networks.clear();
    notifyListeners();
    
    final scanSteps = [
      () => _addVerifiedGovernmentNetworks(),
      () => _addCommercialNetworks(), 
      () => _addSuspiciousNetworks(),
      () => _addUnknownNetworks(),
    ];
    
    for (int i = 0; i < scanSteps.length; i++) {
      await scanSteps[i]();
      _scanProgress = (i + 1) / scanSteps.length;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }
  
  /// Perform Firebase-enhanced scan with progress tracking
  Future<void> _performFirebaseEnhancedScanWithProgress() async {
    _networks.clear();
    notifyListeners();
    
    // Step 1: Add verified networks from Firebase whitelist
    _scanProgress = 0.25;
    if (_currentWhitelist != null) {
      final nearbyWhitelistedAPs = _currentWhitelist!.accessPoints
          .where((ap) => ap.status == 'active')
          .take(3)
          .toList();
      
      for (final ap in nearbyWhitelistedAPs) {
        _networks.add(NetworkModel(
          id: 'whitelist_${ap.id}',
          name: ap.ssid,
          description: 'DICT Verified Access Point - ${ap.city}, ${ap.province}',
          status: NetworkStatus.verified,
          securityType: SecurityType.wpa2,
          signalStrength: 75 + (ap.ssid.hashCode % 20),
          macAddress: ap.macAddress,
          latitude: ap.latitude,
          longitude: ap.longitude,
          lastSeen: DateTime.now(),
          isConnected: ap.ssid == 'DICT-CALABARZON-OFFICIAL',
        ));
      }
    }
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Step 2: Add commercial networks
    _scanProgress = 0.5;
    await _addCommercialNetworks();
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Step 3: Add suspicious networks with Firebase verification
    _scanProgress = 0.75;
    await _addSuspiciousNetworks();
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Step 4: Add unknown networks
    _scanProgress = 1.0;
    await _addUnknownNetworks();
    notifyListeners();
  }
  
  /// Perform real Wi-Fi scan with progress tracking
  Future<void> _performRealWiFiScanWithProgress() async {
    developer.log('Performing real Wi-Fi scan with progress...');
    
    _networks.clear();
    notifyListeners();
    
    try {
      // Step 1: Initialize scan
      _scanProgress = 0.1;
      notifyListeners();
      
      // Step 2: Perform Wi-Fi scan
      _scanProgress = 0.3;
      final scannedNetworks = await _wifiScanner.performScan();
      notifyListeners();
      
      // Step 3: Process networks
      _scanProgress = 0.6;
      _networks = scannedNetworks;
      notifyListeners();
      
      // Step 4: Threat detection
      _scanProgress = 0.8;
      _performEvilTwinDetection();
      notifyListeners();
      
      // Step 5: Cross-reference with whitelist
      _scanProgress = 0.9;
      if (_firebaseEnabled && _currentWhitelist != null) {
        _crossReferenceWithWhitelist();
      }
      notifyListeners();
      
      // Step 6: Identify current network
      _scanProgress = 1.0;
      await _identifyCurrentNetwork();
      
      developer.log('Real Wi-Fi scan completed: ${_networks.length} networks found');
      
    } catch (e) {
      developer.log('Real Wi-Fi scan failed: $e');
      await _performRealisticScanWithProgress();
    }
  }
  
  /// Calculate scan statistics
  void _calculateScanStatistics() {
    _totalNetworksFound = _networks.length;
    _verifiedNetworksFound = _networks.where((n) => n.status == NetworkStatus.verified || n.status == NetworkStatus.trusted).length;
    _suspiciousNetworksFound = _networks.where((n) => n.status == NetworkStatus.suspicious).length;
    _threatsDetected = _suspiciousNetworksFound + _networks.where((n) => n.status == NetworkStatus.flagged).length;
  }
  
  /// Generate real-time alerts based on scan results
  Future<void> _generateScanBasedAlerts() async {
    if (_alertProvider == null) return;
    
    // Generate alerts for newly detected threats (only if not already alerted)
    final newThreats = <NetworkModel>[];
    for (var network in _networks) {
      if (network.status == NetworkStatus.suspicious) {
        final networkKey = '${network.name}_${network.macAddress}';
        if (!_alertedNetworksThisSession.contains(networkKey)) {
          _alertProvider!.generateAlertForNetwork(network);
          _alertedNetworksThisSession.add(networkKey);
          newThreats.add(network);
        }
      }
    }
    
    // Generate summary alert only for manual scans
    if (_hasPerformedScan && _lastScanTime != null && _isManualScan) {
      _alertProvider!.generateScanSummaryAlert(_totalNetworksFound, _threatsDetected, _lastScanTime!);
    }
    
    // If we found new threats in this scan, show an immediate notification
    if (newThreats.isNotEmpty) {
      developer.log('New threats detected in this scan: ${newThreats.length}');
      // Force UI refresh to show new alerts immediately
      notifyListeners();
    }
  }
}