import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/models/network_model.dart';
import '../data/services/firebase_service.dart';
import '../data/services/whitelist_service.dart';
import '../data/services/wifi_scanning_service.dart';
import '../data/services/access_point_service.dart';
import '../data/services/current_connection_service.dart';
import '../data/services/permission_service.dart';
import '../data/services/wifi_connection_service.dart';
import '../data/services/enhanced_wifi_service.dart';
import '../data/services/scan_history_service.dart';
import '../data/models/security_assessment.dart';
import '../data/models/scan_history_model.dart';
import '../data/repositories/whitelist_repository.dart';
import 'alert_provider.dart';
import 'settings_provider.dart';

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
  Map<String, NetworkStatus> _macToStatusMap = {}; // CRITICAL FIX: MAC address to status mapping for AccessPointService sync
  AlertProvider? _alertProvider;
  SettingsProvider? _settingsProvider;
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

  // Scan history service
  final ScanHistoryService _scanHistoryService = ScanHistoryService();
  DateTime? _scanStartTime;
  
  // Mock threat service for testing suggestions

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

  // Scan history getters
  ScanHistoryService get scanHistoryService => _scanHistoryService;
  List<ScanHistoryEntry> get scanHistory => _scanHistoryService.history;
  
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
    _initializeRealNetworks();
    _initializeWiFiScanning();
    _initializeAccessPointService();
    _initializeCurrentConnection();
    _initializeSecurityAnalysis();
    _initializeScanHistory();
    loadUserPreferences();
    // CRITICAL FIX: Load user-defined statuses from AccessPointService after initialization
    _syncWithAccessPointService();
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
            
            // CRITICAL FIX: Apply security assessment results to network status
            _applySecurityAssessmentToNetworks(assessment);
            
            // Check for Evil Twin attacks against whitelist networks
            _checkForWhitelistMimicking(assessment);
          }
          
          // Update threat statistics
          _updateThreatStatistics();
          
          // CRITICAL FIX: Generate alerts for detected threats
          _generateScanBasedAlerts();
          
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

  /// Initialize scan history service
  Future<void> _initializeScanHistory() async {
    try {
      await _scanHistoryService.initialize();
      developer.log('📚 Scan history service initialized');
    } catch (e) {
      developer.log('❌ Failed to initialize scan history: $e');
    }
  }


  /// Record completed scan in history
  Future<void> _recordScanInHistory({required bool wasSuccessful, String? errorMessage}) async {
    if (_scanStartTime == null) return;
    
    try {
      final scanDuration = DateTime.now().difference(_scanStartTime!);
      final scanType = _isManualScan ? ScanType.manual : ScanType.background;
      
      await _scanHistoryService.addScanEntry(
        scanType: scanType,
        scanDuration: scanDuration,
        networksFound: _totalNetworksFound,
        verifiedNetworks: _verifiedNetworksFound,
        suspiciousNetworks: _suspiciousNetworksFound,
        threatsDetected: _threatsDetected,
        networks: _networks,
        wasSuccessful: wasSuccessful,
        errorMessage: errorMessage,
      );
      
      developer.log('📝 Recorded scan in history: ${scanType.name}, ${scanDuration.inSeconds}s, $_totalNetworksFound networks');
    } catch (e) {
      developer.log('❌ Failed to record scan in history: $e');
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

  void setSettingsProvider(SettingsProvider settingsProvider) {
    _settingsProvider = settingsProvider;
  }

  // Initialize Firebase integration
  Future<void> initializeFirebase(SharedPreferences prefs) async {
    developer.log('🔥 NETWORKPROVIDER: initializeFirebase called');
    try {
      developer.log('🔥 NETWORKPROVIDER: Creating FirebaseService...');
      _firebaseService = FirebaseService();
      developer.log('🔥 NETWORKPROVIDER: Creating WhitelistRepository...');
      _whitelistRepository = WhitelistRepository(
        firebaseService: _firebaseService!,
        prefs: prefs,
      );
      
      developer.log('🔥 NETWORKPROVIDER: Setting _firebaseEnabled = true');
      _firebaseEnabled = true;
      
      // Clear any cached data and force fresh fetch during initialization
      developer.log('🔥 NETWORKPROVIDER: Clearing cache and force refreshing...');
      await _whitelistRepository!.clearCache();
      await refreshWhitelist();
      
      // Listen for whitelist updates
      _whitelistRepository!.whitelistUpdates().listen((metadata) {
        developer.log('Whitelist updated: v${metadata.version}');
        refreshWhitelist();
      });
      
      
      developer.log('Firebase integration initialized successfully');
    } catch (e) {
      developer.log('Firebase initialization failed: $e');
      developer.log('Error details: ${e.toString()}');
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

  // Force refresh whitelist from Firebase (bypasses cache)
  Future<void> forceRefreshWhitelist() async {
    developer.log('🔄 FORCE REFRESH DEBUG: Starting...');
    developer.log('   - _firebaseEnabled: $_firebaseEnabled');
    developer.log('   - _whitelistRepository != null: ${_whitelistRepository != null}');
    
    if (!_firebaseEnabled || _whitelistRepository == null) {
      developer.log('❌ FORCE REFRESH: Early return - Firebase not enabled or repository null');
      return;
    }
    
    try {
      developer.log('🔄 Force refreshing whitelist from Firebase...');
      final data = await _whitelistRepository!.getWhitelist(forceRefresh: true);
      developer.log('🔄 FORCE REFRESH: Repository returned data = ${data != null}');
      if (data != null) {
        developer.log('🔄 FORCE REFRESH: Data has ${data.accessPoints.length} access points');
        _currentWhitelist = data;
        developer.log('✅ Force refresh completed: ${data.accessPoints.length} access points loaded');
        notifyListeners();
      } else {
        developer.log('⚠️ Force refresh returned null data');
      }
    } catch (e) {
      developer.log('❌ Error in force refresh whitelist: $e');
      developer.log('❌ Error stack: ${e.toString()}');
    }
  }

  // Check if network is whitelisted
  bool isNetworkWhitelisted(String macAddress) {
    if (!_firebaseEnabled || _whitelistRepository == null) return false;
    return _whitelistRepository!.isNetworkWhitelisted(macAddress, _currentWhitelist);
  }

  /// Convert WhitelistData to List<WhitelistEntry> for map widget compatibility
  List<WhitelistEntry> getWhitelistEntries() {
    developer.log('🔍 NETWORKPROVIDER DEBUG: getWhitelistEntries() called');
    developer.log('   - _currentWhitelist is null: ${_currentWhitelist == null}');
    if (_currentWhitelist != null) {
      developer.log('   - _currentWhitelist.accessPoints.length: ${_currentWhitelist!.accessPoints.length}');
      if (_currentWhitelist!.accessPoints.isNotEmpty) {
        final sample = _currentWhitelist!.accessPoints.first;
        developer.log('   - Sample access point: SSID="${sample.ssid}", status="${sample.status}", isVerified="${sample.isVerified}"');
        developer.log('   - Sample coordinates: lat=${sample.latitude}, lng=${sample.longitude}');
      }
    }
    
    if (_currentWhitelist == null) return [];
    
    final entries = <WhitelistEntry>[];
    int validLocationCount = 0;
    int invalidLocationCount = 0;
    
    for (final accessPoint in _currentWhitelist!.accessPoints) {
      final entry = WhitelistEntry(
        id: accessPoint.id,
        ssid: accessPoint.ssid,
        macAddress: accessPoint.macAddress,
        latitude: accessPoint.latitude,
        longitude: accessPoint.longitude,
        region: accessPoint.region,
        province: accessPoint.province,
        city: accessPoint.city,
        venue: accessPoint.venue, // Use actual venue from Firestore
        barangay: accessPoint.barangay, // Use actual barangay from Firestore  
        verifiedBy: accessPoint.verifiedBy ?? 'DICT CALABARZON',
        verifiedAt: accessPoint.verifiedAt ?? _currentWhitelist!.lastUpdated,
        addedAt: accessPoint.verifiedAt ?? _currentWhitelist!.lastUpdated,
        isActive: true,
        notes: null, // No notes displayed
      );
      
      // Debug the original AccessPointData coordinates
      developer.log('🔍 Processing AccessPointData: ${accessPoint.ssid}');
      developer.log('   - Original AP coordinates: lat=${accessPoint.latitude}, lng=${accessPoint.longitude}');
      developer.log('   - WhitelistEntry coordinates: lat=${entry.latitude}, lng=${entry.longitude}');
      developer.log('   - hasValidLocation: ${entry.hasValidLocation}');
      
      if (entry.hasValidLocation) {
        validLocationCount++;
        developer.log('✅ Valid entry: ${entry.ssid} at (${entry.latitude}, ${entry.longitude})');
      } else {
        invalidLocationCount++;
        developer.log('❌ Invalid entry: ${entry.ssid} at (${entry.latitude}, ${entry.longitude}) - will not show on map');
      }
      
      entries.add(entry);
    }
    
    developer.log('🎯 NETWORKPROVIDER SUMMARY:');
    developer.log('   - Total entries: ${entries.length}');
    developer.log('   - Valid locations: $validLocationCount');
    developer.log('   - Invalid locations: $invalidLocationCount');
    
    return entries;
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

  void _initializeRealNetworks() {
    // Initialize with empty network list - networks will only be populated from real scans
    _networks = [];
    
    // No mock current network - will be detected by CurrentConnectionService
    _currentNetwork = null;
    
    // Update filtered networks with current search query
    _updateFilteredNetworks();
    
    developer.log('🏗️ NetworkProvider initialized for PRODUCTION - no mock data');
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
    _scanStartTime = DateTime.now(); // Track scan start time for history
    
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
        developer.log('⚠️ PRODUCTION: Insufficient permissions for scanning - no networks will be shown');
        developer.log('⚠️ PRODUCTION: Please enable location and WiFi permissions to scan networks');
        // Don't show mock data - this is production mode
        _networks = [];
      } else if (_wifiScanningEnabled) {
        await _performRealWiFiScanWithProgress();
      } else {
        developer.log('⚠️ PRODUCTION: WiFi scanning not available - no networks will be shown');
        developer.log('⚠️ PRODUCTION: Real WiFi scanning required for network detection');
        _networks = [];
      }

      // Update networks with saved status first
      await _updateNetworksWithSavedStatus();
      
      // CRITICAL FIX: Sync with AccessPointService before applying statuses
      await _syncWithAccessPointService();
      
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
      developer.log('❌ PRODUCTION: Error during network scan: $e');
      developer.log('❌ PRODUCTION: No fallback data - scan failed');
      // No mock data fallback in production mode
      _networks = [];
      _calculateScanStatistics();
      _hasPerformedScan = true;
      
      // Record failed scan in history
      await _recordScanInHistory(wasSuccessful: false, errorMessage: e.toString());
    }

    _isScanning = false;
    _isLoading = false;
    _scanProgress = 1.0;
    
    // Record scan in history
    await _recordScanInHistory(wasSuccessful: true);
    
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
      await _performEvilTwinDetection();
      
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
    developer.log('🔍 WHITELIST DEBUG: Cross-referencing ${_networks.length} networks with whitelist');
    developer.log('🔍 WHITELIST DEBUG: Whitelist available: ${_currentWhitelist != null}');
    
    if (_currentWhitelist != null) {
      developer.log('🔍 WHITELIST DEBUG: Whitelist contains ${_currentWhitelist!.accessPoints.length} access points');
      for (final ap in _currentWhitelist!.accessPoints.take(5)) {
        developer.log('🔍 WHITELIST DEBUG: AP - SSID: "${ap.ssid}", MAC: "${ap.macAddress}", Status: "${ap.status}"');
      }
    }
    
    for (int i = 0; i < _networks.length; i++) {
      final network = _networks[i];
      developer.log('🔍 WHITELIST DEBUG: Checking network "${network.name}" (MAC: ${network.macAddress}, Current Status: ${network.status.name})');
      
      final isWhitelisted = isNetworkWhitelisted(network.macAddress);
      developer.log('🔍 WHITELIST DEBUG: isNetworkWhitelisted(${network.macAddress}) = $isWhitelisted');
      
      if (isWhitelisted) {
        // Don't override user-flagged networks - they should remain flagged even if whitelisted
        if (_flaggedNetworkIds.contains(network.id)) {
          developer.log('🚩 Network ${network.name} (${network.macAddress}) is whitelisted but user-flagged - keeping flagged status');
          continue;
        }
        
        // Don't override other user-managed statuses either
        if (_blockedNetworkIds.contains(network.id) || _trustedNetworkIds.contains(network.id)) {
          developer.log('👤 Network ${network.name} (${network.macAddress}) is whitelisted but user-managed - keeping user status');
          continue;
        }
        
        developer.log('✅ MARKING AS VERIFIED: Network ${network.name} (${network.macAddress}) - MAC address found in DICT whitelist');
        _networks[i] = network.copyWith(
          status: NetworkStatus.verified,
          description: '${network.description} (Verified via DICT whitelist)',
        );
      } else {
        // CRITICAL DEBUG: Check if network has same SSID as whitelist but different MAC
        if (_currentWhitelist != null) {
          final sameSSID = _currentWhitelist!.accessPoints.where(
            (ap) => ap.ssid.toLowerCase() == network.name.toLowerCase() && ap.status == 'active'
          ).toList();
          
          if (sameSSID.isNotEmpty) {
            developer.log('⚠️ POTENTIAL EVIL TWIN: Network "${network.name}" (MAC: ${network.macAddress}) has same SSID as ${sameSSID.length} whitelist entries but different MAC:');
            for (final ap in sameSSID) {
              developer.log('   - Whitelist MAC: ${ap.macAddress} vs Scanned MAC: ${network.macAddress}');
            }
            
            // This network should be flagged as suspicious, not verified
            if (network.status != NetworkStatus.suspicious) {
              developer.log('🚨 SHOULD BE FLAGGED: This network should be marked as suspicious (potential evil twin)');
            }
          }
        }
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
    await _performEvilTwinDetection();
    
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


  // REMOVED: Evil twin generation for production - only real threats will be detected

  Future<void> _performEvilTwinDetection() async {
    developer.log('🔍 EVIL TWIN DEBUG: Performing enhanced evil twin detection on ${_networks.length} real networks');
    
    final Map<String, List<NetworkModel>> networkGroups = {};
    
    // Group networks by similar names, but exclude hidden networks from evil twin detection
    for (var network in _networks) {
      // CRITICAL FIX: Skip hidden networks to prevent false evil twin detection
      if (network.name == 'Hidden Network') {
        developer.log('🔍 EVIL TWIN DEBUG: Skipping hidden network (MAC: ${network.macAddress}) - hidden networks are not candidates for evil twin detection');
        continue;
      }
      
      final normalizedName = _normalizeNetworkName(network.name);
      networkGroups.putIfAbsent(normalizedName, () => []).add(network);
      developer.log('🔍 EVIL TWIN DEBUG: Network "${network.name}" normalized to "$normalizedName" (MAC: ${network.macAddress}, Status: ${network.status.name})');
    }
    
    developer.log('🔍 EVIL TWIN DEBUG: Found ${networkGroups.length} unique network name groups');
    
    // Detect potential evil twins with enhanced validation
    for (var entry in networkGroups.entries) {
      if (entry.value.length > 1) {
        final networks = entry.value;
        developer.log('🔍 EVIL TWIN DEBUG: Analyzing ${networks.length} networks with similar name: "${entry.key}"');
        
        // List all networks in this group
        for (var network in networks) {
          developer.log('   - "${network.name}" (MAC: ${network.macAddress}, Status: ${network.status.name}, Signal: ${network.signalStrength})');
        }
        
        // CRITICAL FIX: Enhanced legitimacy detection
        final legitimate = _findLegitimateNetwork(networks);
        developer.log('🔍 EVIL TWIN DEBUG: Selected "${legitimate.name}" (MAC: ${legitimate.macAddress}) as legitimate network');
        
        // Check each network against the legitimate one
        for (var network in networks) {
          if (network.id != legitimate.id) {
            // CRITICAL FIX: Skip networks that are explicitly trusted by the user
            if (_macToStatusMap[network.macAddress] == NetworkStatus.trusted || 
                _trustedNetworkIds.contains(network.id)) {
              developer.log('✅ EVIL TWIN DEBUG: Skipping trusted network ${network.name} (MAC: ${network.macAddress}) - user has explicitly trusted this network');
              continue;
            }
            
            var suspicionScore = _calculateSuspicionScore(network, legitimate);
            developer.log('🔍 EVIL TWIN DEBUG: Suspicion score for ${network.name} (MAC: ${network.macAddress}): $suspicionScore');
            
            // CRITICAL: Check if this network has same SSID as whitelist but different MAC
            bool hasWhitelistSSID = false;
            if (_currentWhitelist != null) {
              hasWhitelistSSID = _currentWhitelist!.accessPoints.any(
                (ap) => ap.ssid.toLowerCase() == network.name.toLowerCase() && ap.status == 'active'
              );
              if (hasWhitelistSSID) {
                developer.log('🚨 EVIL TWIN DEBUG: Network "${network.name}" has SAME SSID as whitelist entry but DIFFERENT MAC - CRITICAL THREAT!');
                suspicionScore += 3; // Boost score for whitelist mimicking
                developer.log('🚨 EVIL TWIN DEBUG: Boosted suspicion score to $suspicionScore for whitelist mimicking');
              }
            }
            
            // Only mark as suspicious if suspicion score is high enough
            if (suspicionScore >= 3) { // Threshold for evil twin detection
              final index = _networks.indexWhere((n) => n.id == network.id);
              if (index != -1) {
                _networks[index] = NetworkModel(
                  id: network.id,
                  name: network.name,
                  description: hasWhitelistSSID 
                    ? 'CRITICAL: Mimicking government network ${legitimate.name} (Score: $suspicionScore)'
                    : 'Potential evil twin of ${legitimate.name} (Score: $suspicionScore)',
                  status: NetworkStatus.suspicious,
                  securityType: network.securityType,
                  signalStrength: network.signalStrength,
                  macAddress: network.macAddress,
                  latitude: network.latitude,
                  longitude: network.longitude,
                  lastSeen: network.lastSeen,
                  isConnected: network.isConnected,
                );
                developer.log('🚨 MARKED AS SUSPICIOUS: ${network.name} (MAC: ${network.macAddress}) - evil twin detected');
                
                // CRITICAL FIX: Apply auto-block if enabled
                if (_settingsProvider != null) {
                  await _settingsProvider!.applyAutoBlockToNetwork(_networks[index]);
                }
              }
            } else {
              developer.log('✅ PASSED VALIDATION: ${network.name} (MAC: ${network.macAddress}) with score $suspicionScore');
            }
          }
        }
      } else {
        // Single network in group - check if it's mimicking whitelist
        final network = entry.value.first;
        
        // CRITICAL FIX: Don't check hidden networks for whitelist mimicking
        if (network.name == 'Hidden Network') {
          developer.log('🔍 EVIL TWIN DEBUG: Skipping whitelist check for hidden network (MAC: ${network.macAddress})');
          continue;
        }
        
        // CRITICAL FIX: Skip networks that are explicitly trusted by the user
        if (_macToStatusMap[network.macAddress] == NetworkStatus.trusted || 
            _trustedNetworkIds.contains(network.id)) {
          developer.log('✅ EVIL TWIN DEBUG: Skipping whitelist mimicking check for trusted network ${network.name} (MAC: ${network.macAddress}) - user has explicitly trusted this network');
          continue;
        }
        
        if (_currentWhitelist != null) {
          final whitelistEntry = _currentWhitelist!.accessPoints.firstWhere(
            (ap) => ap.ssid.toLowerCase() == network.name.toLowerCase() && ap.status == 'active',
            orElse: () => AccessPointData(id: '', ssid: '', macAddress: '', latitude: 0, longitude: 0, region: '', province: '', city: '', signalStrength: {}, type: '', status: '', isVerified: false),
          );
          
          if (whitelistEntry.id.isNotEmpty && whitelistEntry.macAddress.toLowerCase() != network.macAddress.toLowerCase()) {
            developer.log('🚨 SINGLE NETWORK EVIL TWIN: "${network.name}" (MAC: ${network.macAddress}) mimicking whitelist MAC: ${whitelistEntry.macAddress}');
            
            final index = _networks.indexWhere((n) => n.id == network.id);
            if (index != -1) {
              _networks[index] = network.copyWith(
                status: NetworkStatus.suspicious,
                description: 'CRITICAL: Mimicking government network "${network.name}" with different MAC address',
              );
              developer.log('🚨 MARKED SINGLE MIMICKER AS SUSPICIOUS: ${network.name} (MAC: ${network.macAddress})');
              
              // CRITICAL FIX: Apply auto-block if enabled
              if (_settingsProvider != null) {
                await _settingsProvider!.applyAutoBlockToNetwork(_networks[index]);
              }
            }
          }
        }
      }
    }
  }

  /// CRITICAL FIX: Enhanced method to find the most legitimate network
  NetworkModel _findLegitimateNetwork(List<NetworkModel> networks) {
    // Priority order for legitimacy:
    // 1. Verified networks (highest priority)
    // 2. Networks that are already trusted by user
    // 3. Networks with stronger security (WPA3 > WPA2 > WEP > Open)
    // 4. Networks with stronger signal strength
    // 5. Networks that have been seen longer (older lastSeen)
    
    return networks.reduce((a, b) {
      // Check verification status
      if (a.status == NetworkStatus.verified && b.status != NetworkStatus.verified) {
        return a;
      }
      if (b.status == NetworkStatus.verified && a.status != NetworkStatus.verified) {
        return b;
      }
      
      // Check if user has trusted the network
      if (_macToStatusMap[a.macAddress] == NetworkStatus.trusted && 
          _macToStatusMap[b.macAddress] != NetworkStatus.trusted) {
        return a;
      }
      if (_macToStatusMap[b.macAddress] == NetworkStatus.trusted && 
          _macToStatusMap[a.macAddress] != NetworkStatus.trusted) {
        return b;
      }
      
      // Compare security types (higher value = more secure)
      final securityScoreA = _getSecurityScore(a.securityType);
      final securityScoreB = _getSecurityScore(b.securityType);
      if (securityScoreA != securityScoreB) {
        return securityScoreA > securityScoreB ? a : b;
      }
      
      // Compare signal strength
      if (a.signalStrength != b.signalStrength) {
        return a.signalStrength > b.signalStrength ? a : b;
      }
      
      // Prefer network seen earlier (more established)
      return a.lastSeen.isBefore(b.lastSeen) ? a : b;
    });
  }

  /// Calculate suspicion score for potential evil twin
  int _calculateSuspicionScore(NetworkModel suspect, NetworkModel legitimate) {
    int score = 0;
    
    // CRITICAL FIX: Enhanced evil twin detection criteria
    
    // 1. Different MAC addresses with same SSID (+2 points)
    if (suspect.macAddress != legitimate.macAddress) {
      score += 2;
      developer.log('   - Different MAC addresses: +2 points');
    }
    
    // 2. Weaker security than legitimate (+2 points)
    if (_getSecurityScore(suspect.securityType) < _getSecurityScore(legitimate.securityType)) {
      score += 2;
      developer.log('   - Weaker security: +2 points');
    }
    
    // 3. Much weaker signal strength (+1 point) - might be farther away trying to mimic
    if (suspect.signalStrength < legitimate.signalStrength - 30) {
      score += 1;
      developer.log('   - Much weaker signal: +1 point');
    }
    
    // 4. Very similar signal strength (+1 point) - might be very close, trying to compete
    if ((suspect.signalStrength - legitimate.signalStrength).abs() < 5) {
      score += 1;
      developer.log('   - Very similar signal strength: +1 point');
    }
    
    // 5. Recently appeared compared to legitimate (+1 point)
    if (suspect.lastSeen.isAfter(legitimate.lastSeen.add(const Duration(minutes: 5)))) {
      score += 1;
      developer.log('   - Recently appeared: +1 point');
    }
    
    // 6. Location-based validation (if coordinates available)
    if (suspect.latitude != null && suspect.longitude != null &&
        legitimate.latitude != null && legitimate.longitude != null) {
      final distance = _calculateDistance(
        suspect.latitude!, suspect.longitude!,
        legitimate.latitude!, legitimate.longitude!,
      );
      
      // If networks are very close but have different MACs, suspicious (+1 point)
      if (distance < 100 && suspect.macAddress != legitimate.macAddress) { // Within 100 meters
        score += 1;
        developer.log('   - Very close location with different MAC: +1 point');
      }
    }
    
    return score;
  }
  
  /// Get security score for comparison (higher = more secure)
  int _getSecurityScore(SecurityType type) {
    switch (type) {
      case SecurityType.wpa3: return 4;
      case SecurityType.wpa2: return 3;
      case SecurityType.wep: return 2;
      case SecurityType.open: return 1;
    }
  }
  
  /// Calculate distance between two coordinates in meters
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double lat1Rad = lat1 * (pi / 180);
    final double lat2Rad = lat2 * (pi / 180);
    final double deltaLat = (lat2 - lat1) * (pi / 180);
    final double deltaLon = (lon2 - lon1) * (pi / 180);
    
    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
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
    developer.log('🔍 _updateFilteredNetworks: Starting with ${_networks.length} total networks');
    
    // Debug: Show current network statuses
    for (final network in _networks) {
      developer.log('   - ${network.name} (${network.id}): ${network.status.name}');
    }
    
    List<NetworkModel> networksToFilter;
    
    if (_searchQuery.isEmpty) {
      networksToFilter = List.from(_networks);
    } else {
      networksToFilter = _networks.where((network) {
        return network.name.toLowerCase().contains(_searchQuery) ||
            (network.description?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }
    
    developer.log('🔍 After search filter: ${networksToFilter.length} networks');
    
    // CRITICAL FIX: Filter out blocked networks from display
    final originalCount = networksToFilter.length;
    final blockedNetworks = <NetworkModel>[];
    
    networksToFilter = networksToFilter.where((network) {
      final isBlocked = network.status == NetworkStatus.blocked;
      final isBlockedByUser = _blockedNetworkIds.contains(network.id);
      if (isBlocked || isBlockedByUser) {
        blockedNetworks.add(network);
        developer.log('🚫 FILTERING OUT blocked network: ${network.name} (${network.id})');
        developer.log('   - network.status: ${network.status.name}');
        developer.log('   - isBlocked: $isBlocked');
        developer.log('   - isBlockedByUser: $isBlockedByUser');
        developer.log('   - _blockedNetworkIds contains ${network.id}: ${_blockedNetworkIds.contains(network.id)}');
      }
      return !isBlocked && !isBlockedByUser;
    }).toList();
    
    final blockedCount = originalCount - networksToFilter.length;
    if (blockedCount > 0) {
      developer.log('🚫 Filtered out $blockedCount blocked networks from nearby networks display');
      developer.log('🚫 Blocked networks: ${blockedNetworks.map((n) => '${n.name} (${n.status.name})').join(', ')}');
    } else {
      developer.log('✅ No blocked networks found to filter');
    }
    
    // CRITICAL FIX: Sort networks by safety level (safest to suspicious)
    networksToFilter.sort((a, b) {
      final priorityA = _getNetworkSafetyPriority(a.status);
      final priorityB = _getNetworkSafetyPriority(b.status);
      
      // Sort by safety priority first (lower number = safer = shown first)
      int result = priorityA.compareTo(priorityB);
      if (result != 0) return result;
      
      // If same safety level, sort by signal strength (stronger first)
      result = b.signalStrength.compareTo(a.signalStrength);
      if (result != 0) return result;
      
      // If same signal strength, sort alphabetically by name
      return a.name.compareTo(b.name);
    });
    
    _filteredNetworks = networksToFilter;
    
    // Log the sorting order for debugging
    developer.log('🔍 Final filtered networks count: ${_filteredNetworks.length}');
    if (_filteredNetworks.isNotEmpty) {
      developer.log('📶 Networks sorted by safety: ${_filteredNetworks.map((n) => '${n.name}(${n.status.name})').join(', ')}');
    }
    developer.log('🔍 All blocked network IDs: ${_blockedNetworkIds.toList()}');
    
    // Verify no blocked networks made it through
    final blockedInFiltered = _filteredNetworks.where((n) => n.status == NetworkStatus.blocked || _blockedNetworkIds.contains(n.id)).toList();
    if (blockedInFiltered.isNotEmpty) {
      developer.log('❌ ERROR: Blocked networks found in filtered list: ${blockedInFiltered.map((n) => '${n.name} (${n.id})').join(', ')}');
    } else {
      developer.log('✅ SUCCESS: No blocked networks in filtered list');
    }
  }
  
  /// Get safety priority for sorting (lower number = safer = shown first)
  int _getNetworkSafetyPriority(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.trusted:    return 1; // Safest - show first
      case NetworkStatus.verified:   return 2; // Very safe
      case NetworkStatus.unknown:    return 3; // Neutral
      case NetworkStatus.flagged:    return 4; // User-marked suspicious
      case NetworkStatus.suspicious: return 5; // System-detected threats
      case NetworkStatus.blocked:    return 99; // Should never appear (filtered out above)
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
      
      developer.log('AccessPointService Trusted: ${trustedAPs.map((n) => '${n.name}(${n.macAddress})').join(', ')}');
      developer.log('AccessPointService Blocked: ${blockedAPs.map((n) => '${n.name}(${n.macAddress})').join(', ')}');
      developer.log('AccessPointService Flagged: ${flaggedAPs.map((n) => '${n.name}(${n.macAddress})').join(', ')}');
      
      developer.log('NetworkProvider MAC-to-Status Map: ${_macToStatusMap.entries.map((e) => '${e.key}:${e.value.name}').join(', ')}');
      
      // Check for synchronization between current networks and AccessPointService
      for (final network in _networks) {
        final accessPointStatus = _macToStatusMap[network.macAddress];
        if (accessPointStatus != null && accessPointStatus != network.status) {
          developer.log('⚠️ SYNC ISSUE: Network ${network.name} (${network.macAddress}) - NetworkProvider: ${network.status.name}, AccessPointService: $accessPointStatus.name');
        }
      }
      
      developer.log('=====================================');
    } catch (e) {
      developer.log('Error checking AccessPointService sync: $e');
    }
  }
  
  /// Force synchronization with AccessPointService (for testing)
  Future<void> forceSyncWithAccessPointService() async {
    developer.log('🔄 Force synchronizing with AccessPointService...');
    await _syncWithAccessPointService();
    _applyUserDefinedStatuses();
    _updateFilteredNetworks();
    notifyListeners();
    developer.log('✅ Force synchronization completed');
  }

  /// Clean up false positive suspicious status for hidden networks and trusted networks
  void cleanupHiddenNetworkStatuses() {
    developer.log('🧹 Checking for networks with incorrect suspicious status...');
    
    bool hasChanges = false;
    
    for (int i = 0; i < _networks.length; i++) {
      final network = _networks[i];
      
      // Fix hidden networks marked as suspicious
      if (network.name == 'Hidden Network' && network.status == NetworkStatus.suspicious) {
        developer.log('🧹 Fixing hidden network (MAC: ${network.macAddress}) - changing from suspicious to unknown');
        _networks[i] = network.copyWith(
          status: NetworkStatus.unknown,
          description: 'Hidden network - SSID not broadcast',
        );
        hasChanges = true;
      }
      
      // CRITICAL FIX: Fix trusted networks that were incorrectly marked as suspicious
      if (network.status == NetworkStatus.suspicious && 
          (_macToStatusMap[network.macAddress] == NetworkStatus.trusted || 
           _trustedNetworkIds.contains(network.id))) {
        developer.log('🧹 CRITICAL FIX: Restoring trusted network ${network.name} (MAC: ${network.macAddress}) - changing from suspicious to trusted');
        _networks[i] = network.copyWith(
          status: NetworkStatus.trusted,
          description: 'Trusted network - verified by user',
          isUserManaged: true,
          lastActionDate: DateTime.now(),
        );
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      developer.log('✅ Fixed incorrect suspicious status for networks');
      _updateFilteredNetworks();
      notifyListeners();
    } else {
      developer.log('✅ No networks with incorrect suspicious status found');
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
      _alertProvider!.generateTrustedNetworkAlert(network, scanSessionId: _scanSessionId);
    }
    
    // Sync with AccessPointService
    try {
      await _accessPointService.trustAccessPoint(network);
    } catch (e) {
      developer.log('Failed to sync trusted network with AccessPointService: $e');
    }
    
    await _saveUserPreferences();
    _applyUserDefinedStatuses();
    
    // CRITICAL FIX: Clean up any incorrect suspicious status for this now-trusted network
    cleanupHiddenNetworkStatuses();
    
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
      _alertProvider!.generateFlaggedNetworkAlert(network, scanSessionId: _scanSessionId);
    }
    
    // Sync with AccessPointService
    try {
      await _accessPointService.flagAccessPoint(network);
    } catch (e) {
      developer.log('Failed to sync flagged network with AccessPointService: $e');
    }
    
    await _saveUserPreferences();
    _applyUserDefinedStatuses();
    
    // CRITICAL FIX: Update filtered networks to reflect flagged status in sorting
    _updateFilteredNetworks();
    
    notifyListeners();
    
    developer.log('🚩 Flagged network ${network.name} ($networkId) - moved to suspicious section');
  }

  /// Block a network - hide it from all lists and prevent connection
  Future<void> blockNetwork(String networkId) async {
    developer.log('🚫 blockNetwork called for networkId: $networkId');
    
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
    
    developer.log('🚫 Found network to block: ${network.name} (${network.id})');
    developer.log('🚫 Current network status: ${network.status.name}');
    developer.log('🚫 _blockedNetworkIds BEFORE: ${_blockedNetworkIds.toList()}');
    
    _blockedNetworkIds.add(networkId);
    _trustedNetworkIds.remove(networkId);
    _flaggedNetworkIds.remove(networkId);
    
    developer.log('🚫 _blockedNetworkIds AFTER: ${_blockedNetworkIds.toList()}');
    
    // Generate alert for blocked network
    if (_alertProvider != null) {
      _alertProvider!.generateBlockedNetworkAlert(network, scanSessionId: _scanSessionId);
    }
    
    // Sync with AccessPointService
    try {
      await _accessPointService.blockAccessPoint(network);
    } catch (e) {
      developer.log('Failed to sync blocked network with AccessPointService: $e');
    }
    
    await _saveUserPreferences();
    
    developer.log('🚫 BEFORE _applyUserDefinedStatuses: Network ${network.name} status: ${network.status.name}');
    _applyUserDefinedStatuses();
    
    // Check if the network status was properly updated
    final updatedNetwork = _networks.firstWhere((n) => n.id == networkId, orElse: () => network);
    developer.log('🚫 AFTER _applyUserDefinedStatuses: Network ${updatedNetwork.name} status: ${updatedNetwork.status.name}');
    
    // CRITICAL FIX: Update filtered networks to immediately hide blocked network
    _updateFilteredNetworks();
    
    notifyListeners();
    
    developer.log('🚫 Blocked network ${network.name} ($networkId) - should be removed from display');
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
    
    // CRITICAL FIX: Remove MAC-based status immediately to prevent re-trusting
    final removedStatus = _macToStatusMap.remove(network.macAddress);
    developer.log('🗑️ Removed MAC-based trusted status for ${network.macAddress}: ${removedStatus?.name ?? 'none'}');
    developer.log('📊 Remaining MAC statuses: ${_macToStatusMap.length} entries');
    
    // Sync with AccessPointService
    try {
      await _accessPointService.untrustAccessPoint(network);
    } catch (e) {
      developer.log('Failed to sync untrusted network with AccessPointService: $e');
    }
    
    await _saveUserPreferences();
    
    // CRITICAL FIX: Remove untrusted network from current networks list to force fresh evaluation
    // This ensures that if trust was masking suspicious behavior, it will be re-detected
    _networks.removeWhere((n) => n.id == networkId);
    developer.log('🔄 REMOVED FROM SCAN: ${network.name} removed from current networks - will reappear after fresh scan with proper security evaluation');
    
    // Clean up original status entry since it will be re-evaluated
    _originalStatuses.remove(networkId);
    developer.log('🧹 Cleaned up original status entry for fresh evaluation');
    
    // Update filtered networks to reflect removal
    _updateFilteredNetworks();
    
    notifyListeners();
    
    developer.log('🔓 Untrusted network ${network.name} ($networkId) - removed from nearby networks, will reappear after next scan');
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
    
    // CRITICAL FIX: Remove MAC-based status immediately to prevent re-flagging
    final removedStatus = _macToStatusMap.remove(network.macAddress);
    developer.log('🗑️ Removed MAC-based flagged status for ${network.macAddress}: ${removedStatus?.name ?? 'none'}');
    developer.log('📊 Remaining MAC statuses: ${_macToStatusMap.length} entries');
    
    // Sync with AccessPointService
    try {
      await _accessPointService.unflagAccessPoint(network);
    } catch (e) {
      developer.log('Failed to sync unflagged network with AccessPointService: $e');
    }
    
    await _saveUserPreferences();
    
    // CRITICAL FIX: Force restore to natural status immediately
    _forceRestoreNaturalStatus(networkId, network);
    
    _applyUserDefinedStatuses();
    
    // CRITICAL FIX: Update filtered networks to reflect restored natural status
    _updateFilteredNetworks();
    
    notifyListeners();
    
    developer.log('🏃 Unflagged network ${network.name} ($networkId) - restored to natural status');
  }

  /// Force restore network to its natural status after user removal
  /// Used for flagged networks which remain visible but need status restoration
  /// (Blocked/trusted networks are removed entirely and reappear after fresh scan)
  void _forceRestoreNaturalStatus(String networkId, NetworkModel network) {
    final originalStatus = _originalStatuses[networkId];
    final networkIndex = _networks.indexWhere((n) => n.id == networkId);
    
    if (networkIndex != -1) {
      if (originalStatus != null) {
        // Restore to documented original status
        _networks[networkIndex] = _networks[networkIndex].copyWith(
          status: originalStatus,
          isUserManaged: false,
          lastActionDate: null,
          description: 'Network restored to original status',
        );
        developer.log('🔄 IMMEDIATE RESTORE: ${network.name} restored to original status: ${originalStatus.name}');
        
        // Clean up original status since network is no longer user-managed
        _originalStatuses.remove(networkId);
        developer.log('🧹 Cleaned up original status entry for ${network.name}');
      } else {
        // No original status recorded, determine natural status based on security analysis
        NetworkStatus naturalStatus = NetworkStatus.unknown; // Default fallback
        
        // Check if it's a verified government network
        if (_currentWhitelist != null) {
          final whitelistEntry = _currentWhitelist!.accessPoints.firstWhere(
            (ap) => ap.macAddress.toLowerCase() == network.macAddress.toLowerCase() && ap.status == 'active',
            orElse: () => AccessPointData(id: '', ssid: '', macAddress: '', latitude: 0, longitude: 0, region: '', province: '', city: '', signalStrength: {}, type: '', status: '', isVerified: false),
          );
          if (whitelistEntry.id.isNotEmpty) {
            naturalStatus = NetworkStatus.verified;
          }
        }
        
        _networks[networkIndex] = _networks[networkIndex].copyWith(
          status: naturalStatus,
          isUserManaged: false,
          lastActionDate: null,
          description: naturalStatus == NetworkStatus.verified ? 'Government verified network' : 'Network status determined by security analysis',
        );
        developer.log('🔄 NATURAL STATUS: ${network.name} set to natural status: ${naturalStatus.name}');
        
        // Re-evaluate security status if network is set to unknown
        if (naturalStatus == NetworkStatus.unknown) {
          developer.log('🔍 Re-evaluating security status for newly unmanaged network: ${network.name}');
          // The evil twin detection and security analysis will run during the next _applyUserDefinedStatuses call
        }
      }
    }
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
    
    // CRITICAL FIX: Remove MAC-based status immediately to prevent re-blocking
    final removedStatus = _macToStatusMap.remove(network.macAddress);
    developer.log('🗑️ Removed MAC-based status for ${network.macAddress}: ${removedStatus?.name ?? 'none'}');
    developer.log('📊 Remaining MAC statuses: ${_macToStatusMap.length} entries');
    
    // Sync with AccessPointService
    try {
      await _accessPointService.unblockAccessPoint(network);
    } catch (e) {
      developer.log('Failed to sync unblocked network with AccessPointService: $e');
    }
    
    await _saveUserPreferences();
    
    // CRITICAL FIX: Remove unblocked network from current networks list to force fresh evaluation
    _networks.removeWhere((n) => n.id == networkId);
    developer.log('🔄 REMOVED FROM SCAN: ${network.name} removed from current networks - will reappear after fresh scan with proper security evaluation');
    
    // Clean up original status entry since it will be re-evaluated
    _originalStatuses.remove(networkId);
    developer.log('🧹 Cleaned up original status entry for fresh evaluation');
    
    // Update filtered networks to reflect removal
    _updateFilteredNetworks();
    
    notifyListeners();
    
    developer.log('✅ Unblocked network ${network.name} ($networkId) - removed from nearby networks, will reappear after next scan');
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
      
      // Clear scan history
      await _scanHistoryService.clearHistory();
      
      // Save cleared state
      await _saveUserPreferences();
      
      notifyListeners();
      developer.log('Network data cleared successfully');
    } catch (e) {
      developer.log('Error clearing network data: $e');
      throw Exception('Failed to clear network data: $e');
    }
  }

  /// Clear scan history only (not all network data)
  Future<void> clearScanHistory() async {
    try {
      await _scanHistoryService.clearHistory();
      notifyListeners();
      developer.log('Scan history cleared successfully');
    } catch (e) {
      developer.log('Error clearing scan history: $e');
      throw Exception('Failed to clear scan history: $e');
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
    
    developer.log('🔧 _applyUserDefinedStatuses: Blocked network IDs: ${_blockedNetworkIds.toList()}');
    developer.log('🔧 _applyUserDefinedStatuses: Trusted network IDs: ${_trustedNetworkIds.toList()}');
    developer.log('🔧 _applyUserDefinedStatuses: Flagged network IDs: ${_flaggedNetworkIds.toList()}');
    developer.log('🔧 _applyUserDefinedStatuses: MAC-based statuses: ${_macToStatusMap.length} entries');
    
    for (int i = 0; i < _networks.length; i++) {
      final network = _networks[i];
      
      // Store original status if not already stored and not user-managed
      if (!_originalStatuses.containsKey(network.id) && !network.isUserManaged) {
        _originalStatuses[network.id] = network.status;
      }
      
      NetworkStatus newStatus;
      bool isUserManaged = false;
      
      // CRITICAL FIX: Check MAC-based status first (AccessPointService sync)
      final macBasedStatus = _macToStatusMap[network.macAddress];
      if (macBasedStatus != null) {
        newStatus = macBasedStatus;
        isUserManaged = true;
        developer.log('🔄 _applyUserDefinedStatuses: Setting ${network.name} (MAC: ${network.macAddress}) to ${macBasedStatus.name} from AccessPointService');
        
        // Sync the network ID to the appropriate set for consistency
        switch (macBasedStatus) {
          case NetworkStatus.blocked:
            _blockedNetworkIds.add(network.id);
            _trustedNetworkIds.remove(network.id);
            _flaggedNetworkIds.remove(network.id);
            break;
          case NetworkStatus.trusted:
            _trustedNetworkIds.add(network.id);
            _blockedNetworkIds.remove(network.id);
            _flaggedNetworkIds.remove(network.id);
            break;
          case NetworkStatus.flagged:
            _flaggedNetworkIds.add(network.id);
            _blockedNetworkIds.remove(network.id);
            _trustedNetworkIds.remove(network.id);
            break;
          default:
            break;
        }
      } else if (_blockedNetworkIds.contains(network.id)) {
        newStatus = NetworkStatus.blocked;
        isUserManaged = true;
        developer.log('🚫 _applyUserDefinedStatuses: Setting ${network.name} (${network.id}) to BLOCKED status');
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
      
      developer.log('📚 Loaded user preferences: ${_trustedNetworkIds.length} trusted, ${_blockedNetworkIds.length} blocked, ${_flaggedNetworkIds.length} flagged');
    } catch (e) {
      developer.log('Error loading user preferences: $e');
    }
  }

  /// CRITICAL FIX: Synchronize with AccessPointService to load MAC-based network statuses
  Future<void> _syncWithAccessPointService() async {
    try {
      developer.log('🔄 Starting AccessPointService synchronization...');
      
      // Load all access points from AccessPointService
      final trustedAPs = await _accessPointService.getTrustedAccessPoints();
      final blockedAPs = await _accessPointService.getBlockedAccessPoints();
      final flaggedAPs = await _accessPointService.getFlaggedAccessPoints();
      
      developer.log('🔄 AccessPointService loaded: ${trustedAPs.length} trusted, ${blockedAPs.length} blocked, ${flaggedAPs.length} flagged');
      
      // Create MAC address to network status mapping for fast lookup
      final macToStatusMap = <String, NetworkStatus>{};
      
      for (final ap in trustedAPs) {
        macToStatusMap[ap.macAddress] = NetworkStatus.trusted;
      }
      for (final ap in blockedAPs) {
        macToStatusMap[ap.macAddress] = NetworkStatus.blocked;
      }
      for (final ap in flaggedAPs) {
        macToStatusMap[ap.macAddress] = NetworkStatus.flagged;
      }
      
      // Store MAC-based statuses for use during network scanning
      _macToStatusMap = macToStatusMap;
      
      developer.log('✅ AccessPointService synchronization completed: ${macToStatusMap.length} total MAC-based network statuses loaded');
      
    } catch (e) {
      developer.log('❌ Error synchronizing with AccessPointService: $e');
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
  
  // REMOVED: All mock data generation methods for production
  // The app now only shows real WiFi networks detected by the device
  
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
      await _performEvilTwinDetection();
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
      developer.log('❌ PRODUCTION: Real Wi-Fi scan failed: $e');
      developer.log('❌ PRODUCTION: No networks will be shown - scan failed');
      // No fallback to mock data in production
      _networks = [];
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
    if (_alertProvider == null) {
      developer.log('⚠️ Alert provider not available for alert generation');
      return;
    }
    
    developer.log('🔍 Starting alert generation for ${_networks.length} networks');
    
    // Generate alerts for detected threats (AlertProvider handles all deduplication)
    final newThreats = <NetworkModel>[];
    int suspiciousCount = 0;
    int flaggedCount = 0;
    
    for (var network in _networks) {
      // Generate alerts for both suspicious and flagged networks
      if (network.status == NetworkStatus.suspicious || network.status == NetworkStatus.flagged) {
        if (network.status == NetworkStatus.suspicious) {
          suspiciousCount++;
        } else if (network.status == NetworkStatus.flagged) {
          flaggedCount++;
        }
        
        developer.log('🚨 Processing ${network.status.name} network: ${network.name} (${network.macAddress})');
        
        // For flagged networks, create a suspicious version for alert generation
        final alertNetwork = network.status == NetworkStatus.flagged 
          ? NetworkModel(
              id: network.id,
              name: network.name,
              description: 'User-flagged suspicious network: ${network.name}',
              status: NetworkStatus.suspicious, // Convert to suspicious for alert
              securityType: network.securityType,
              signalStrength: network.signalStrength,
              macAddress: network.macAddress,
              latitude: network.latitude,
              longitude: network.longitude,
              lastSeen: network.lastSeen,
            )
          : network;
        
        // Let AlertProvider handle all deduplication logic - it will update existing alerts if they exist
        _alertProvider!.generateAlertForNetwork(alertNetwork, scanSessionId: _scanSessionId);
        
        // Track for session statistics only (not for deduplication)
        final networkKey = '${network.name}_${network.macAddress}';
        if (!_alertedNetworksThisSession.contains(networkKey)) {
          _alertedNetworksThisSession.add(networkKey);
          newThreats.add(network); // Only count as "new" for this session
        }
      }
    }
    
    developer.log('🔍 Alert generation complete: $suspiciousCount suspicious, $flaggedCount flagged networks processed');
    
    // Generate summary alert only for manual scans
    if (_hasPerformedScan && _lastScanTime != null && _isManualScan) {
      _alertProvider!.generateScanSummaryAlert(_totalNetworksFound, _threatsDetected, _lastScanTime!, scanSessionId: _scanSessionId);
    }
    
    // If we found new threats in this scan, show an immediate notification
    if (newThreats.isNotEmpty) {
      developer.log('New threats detected in this scan: ${newThreats.length}');
      // Force UI refresh to show new alerts immediately
      notifyListeners();
    }
  }



  /// Apply security assessment results to mark networks as suspicious/threats
  void _applySecurityAssessmentToNetworks(SecurityAssessment assessment) {
    try {
      // Find the network that matches this assessment
      final networkIndex = _networks.indexWhere((network) => 
        network.macAddress == assessment.networkId || 
        network.id == assessment.networkId);
        
      if (networkIndex == -1) {
        developer.log('⚠️ Network not found for security assessment: ${assessment.networkId}');
        return;
      }
      
      final network = _networks[networkIndex];
      final hasThreats = assessment.detectedThreats.isNotEmpty;
      
      // Apply threat assessment to network status
      if (hasThreats) {
        NetworkStatus newStatus = NetworkStatus.suspicious;
        String threatDescription = 'Security threats detected: ';
        
        // Build threat description from detected threats
        final threatTypes = assessment.detectedThreats.map((t) => t.type.toString().split('.').last).toList();
        threatDescription += threatTypes.join(', ');
        
        // Add threat details if available
        if (assessment.detectedThreats.isNotEmpty) {
          final primaryThreat = assessment.detectedThreats.first;
          if (primaryThreat.description.isNotEmpty) {
            threatDescription += '. ${primaryThreat.description}';
          }
        }
        
        // Update network with threat information
        _networks[networkIndex] = network.copyWith(
          status: newStatus,
          description: threatDescription,
        );
        
        developer.log('🚨 MARKED NETWORK AS SUSPICIOUS: ${network.name} (${assessment.networkId})');
        developer.log('🔍 Threats: ${threatTypes.join(', ')}');
        developer.log('📊 Threat Level: ${assessment.threatLevel}');
        developer.log('🔢 Confidence: ${(assessment.confidenceScore * 100).toStringAsFixed(1)}%');
      } else {
        developer.log('✅ Network passed security assessment: ${network.name}');
      }
      
    } catch (e) {
      developer.log('❌ Error applying security assessment: $e');
    }
  }

  /// Check for Evil Twin attacks against verified whitelist networks
  void _checkForWhitelistMimicking(SecurityAssessment assessment) {
    try {
      // Only process if this assessment indicates an Evil Twin threat
      final hasEvilTwinThreat = assessment.detectedThreats.any(
        (threat) => threat.type == ThreatType.evilTwin || 
                   threat.description.toLowerCase().contains('evil twin') ||
                   threat.description.toLowerCase().contains('mimicking') ||
                   threat.description.toLowerCase().contains('spoofing')
      );
      
      if (!hasEvilTwinThreat) {
        return; // No Evil Twin threat detected
      }
      
      // Find the network being analyzed
      final suspiciousNetwork = _networks.firstWhere(
        (network) => network.macAddress == assessment.networkId,
        orElse: () => NetworkModel(
          id: assessment.networkId,
          name: assessment.networkId, // Fallback
          status: NetworkStatus.suspicious,
          securityType: SecurityType.open,
          signalStrength: 0,
          macAddress: assessment.networkId,
          lastSeen: DateTime.now(),
        ),
      );
      
      // Check if this network is mimicking a verified whitelist network
      final isWhitelistMimicking = _isNetworkMimickingWhitelist(suspiciousNetwork);
      
      if (!isWhitelistMimicking) {
        developer.log('⚠️ Evil Twin detected but not mimicking a whitelist network: ${suspiciousNetwork.name}');
        return; // Not mimicking a whitelist network
      }
      
      // Generate threat reporting suggestion for verified whitelist mimicking
      if (_alertProvider != null) {
        final threatDescription = assessment.detectedThreats
            .firstWhere((t) => t.type == ThreatType.evilTwin, 
                      orElse: () => assessment.detectedThreats.first)
            .description;
        
        developer.log('🚨 Whitelist mimicking detected! Generating threat report suggestion for: ${suspiciousNetwork.name}');
        
        _alertProvider!.generateUnifiedSuspiciousNetworkAlert(
          suspiciousNetwork,
          threatDescription,
          assessment.recommendations,
          isWhitelistMimicking: true,
        );
      }
    } catch (e) {
      developer.log('❌ Error checking for whitelist mimicking: $e');
    }
  }
  
  /// Check if a suspicious network is mimicking a verified whitelist network
  bool _isNetworkMimickingWhitelist(NetworkModel suspiciousNetwork) {
    try {
      // CRITICAL: First check for government network pattern mimicking
      final isGovernmentPattern = _isGovernmentNetworkPattern(suspiciousNetwork.name);
      if (isGovernmentPattern) {
        developer.log('🚨 Government network pattern detected: ${suspiciousNetwork.name}');
        return true; // Always consider government patterns as whitelist mimicking
      }
      
      // Then check traditional whitelist
      if (_currentWhitelist == null) {
        developer.log('⚠️ No whitelist available for mimicking check');
        return false;
      }
      
      // Check if there's a verified network with the same SSID in the whitelist
      final whitelistAccessPoint = _currentWhitelist!.accessPoints.firstWhere(
        (ap) => ap.ssid.toLowerCase() == suspiciousNetwork.name.toLowerCase(),
        orElse: () => AccessPointData(
          id: '',
          ssid: '',
          macAddress: '',
          latitude: 0,
          longitude: 0,
          region: '',
          province: '',
          city: '',
          signalStrength: {},
          type: '',
          status: '',
          isVerified: false,
        ),
      );
      
      // If no whitelist entry found, not mimicking
      if (whitelistAccessPoint.ssid.isEmpty) {
        return false;
      }
      
      // Check if the suspicious network has a different MAC address than the whitelist entry
      final isDifferentMAC = whitelistAccessPoint.macAddress.toLowerCase() != suspiciousNetwork.macAddress.toLowerCase();
      
      if (isDifferentMAC && whitelistAccessPoint.status.toLowerCase() == 'active') {
        developer.log('🎯 Whitelist mimicking detected: ${suspiciousNetwork.name}');
        developer.log('   Legitimate MAC: ${whitelistAccessPoint.macAddress}');
        developer.log('   Suspicious MAC: ${suspiciousNetwork.macAddress}');
        return true;
      }
      
      return false;
    } catch (e) {
      developer.log('❌ Error checking whitelist mimicking: $e');
      return false;
    }
  }

  /// Check if network name contains government patterns that should trigger reporting
  bool _isGovernmentNetworkPattern(String networkName) {
    final governmentPatterns = [
      // DICT patterns
      'dict', 'DICT', 'Dict',
      'dict-calabarzon', 'DICT-CALABARZON', 'Dict-Calabarzon',
      'dict_calabarzon', 'DICT_CALABARZON',
      // Government office patterns  
      'dost', 'DOST', 'dilg', 'DILG', 'deped', 'DepEd', 'DEPED',
      'doh', 'DOH', 'dti', 'DTI', 'dswd', 'DSWD',
      // Regional patterns
      'calabarzon', 'CALABARZON', 'Calabarzon',
      'region4a', 'REGION4A', 'Region4A',
      // Municipal patterns
      'lgu', 'LGU', 'municipal', 'MUNICIPAL', 'Municipal',
      'city_hall', 'CITY_HALL', 'cityhall', 'CITYHALL',
      // Generic government patterns
      'gov', 'GOV', 'Gov', 'government', 'GOVERNMENT', 'Government',
      'official', 'OFFICIAL', 'Official'
    ];

    final lowerName = networkName.toLowerCase();
    return governmentPatterns.any((pattern) => lowerName.contains(pattern.toLowerCase()));
  }

}