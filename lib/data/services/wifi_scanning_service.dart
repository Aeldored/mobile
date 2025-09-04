import 'dart:async';
import 'dart:developer' as developer;
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../models/network_model.dart';
import 'geocoding_service.dart';

class WiFiScanningService {
  static final WiFiScanningService _instance = WiFiScanningService._internal();
  factory WiFiScanningService() => _instance;
  WiFiScanningService._internal();

  final GeocodingService _geocodingService = GeocodingService();
  Timer? _scanTimer;
  StreamController<List<NetworkModel>>? _scanController;
  bool _isScanning = false;
  Position? _currentLocation;

  /// Initialize the Wi-Fi scanning service
  Future<bool> initialize() async {
    try {
      // Check if Wi-Fi scanning is supported
      final canGetScannedResults = await WiFiScan.instance.canGetScannedResults();
      if (canGetScannedResults != CanGetScannedResults.yes) {
        developer.log('Wi-Fi scanning not supported on this device');
        return false;
      }

      // Request permissions
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        developer.log('Required permissions not granted');
        return false;
      }

      // Get current location for analysis
      await _updateLocation();

      developer.log('Wi-Fi scanning service initialized successfully');
      return true;
    } catch (e) {
      developer.log('Failed to initialize Wi-Fi scanning service: $e');
      return false;
    }
  }

  /// Request all required permissions for Wi-Fi scanning
  Future<bool> _requestPermissions() async {
    try {
      // Check and request location permissions (required for Wi-Fi scanning)
      LocationPermission locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        locationPermission = await Geolocator.requestPermission();
      }

      if (locationPermission == LocationPermission.denied || 
          locationPermission == LocationPermission.deniedForever) {
        return false;
      }

      // Request other permissions using permission_handler
      final Map<Permission, PermissionStatus> permissions = await [
        Permission.locationWhenInUse,
        Permission.nearbyWifiDevices, // Android 13+
      ].request();

      // Check if all permissions are granted
      for (final permission in permissions.values) {
        if (!permission.isGranted) {
          developer.log('Permission denied: $permission');
        }
      }

      return true;
    } catch (e) {
      developer.log('Error requesting permissions: $e');
      return false;
    }
  }

  /// Update current location for scan analysis
  Future<void> _updateLocation() async {
    try {
      _currentLocation = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      developer.log('Location updated: ${_currentLocation?.latitude}, ${_currentLocation?.longitude}');
    } catch (e) {
      developer.log('⚠️ PRODUCTION: Failed to get location: $e');
      developer.log('⚠️ PRODUCTION: Location-based network analysis not available');
      // No mock location in production - continue with null location
      _currentLocation = null;
    }
  }

  /// Perform a single Wi-Fi scan
  Future<List<NetworkModel>> performScan() async {
    try {
      developer.log('Starting Wi-Fi scan...');
      
      // Start scan
      await WiFiScan.instance.startScan();
      
      // Wait a moment for scan to complete
      await Future.delayed(const Duration(seconds: 2));
      
      // Get scan results
      final accessPoints = await WiFiScan.instance.getScannedResults();
      
      developer.log('Found ${accessPoints.length} access points');
      
      // Convert to NetworkModel objects
      final networks = <NetworkModel>[];
      for (int i = 0; i < accessPoints.length; i++) {
        final ap = accessPoints[i];
        networks.add(_convertToNetworkModel(ap, i));
      }
      
      return networks;
    } catch (e) {
      developer.log('Wi-Fi scan failed: $e');
      return [];
    }
  }

  /// Convert WiFiAccessPoint to NetworkModel
  NetworkModel _convertToNetworkModel(WiFiAccessPoint ap, int index) {
    // Determine city name from current location
    String? cityName;
    double? latitude;
    double? longitude;
    
    if (_currentLocation != null) {
      latitude = _currentLocation!.latitude;
      longitude = _currentLocation!.longitude;
      cityName = _geocodingService.getCityName(latitude, longitude);
    }

    // Determine security type
    SecurityType securityType = SecurityType.open;
    if (ap.capabilities.contains('WPA3')) {
      securityType = SecurityType.wpa3;
    } else if (ap.capabilities.contains('WPA2') || ap.capabilities.contains('WPA')) {
      securityType = SecurityType.wpa2;
    } else if (ap.capabilities.contains('WEP')) {
      securityType = SecurityType.wep;
    }

    // Analyze network status based on various factors
    final networkStatus = _analyzeNetworkStatus(ap, cityName);

    return NetworkModel(
      id: 'scan_${index}_${ap.bssid.replaceAll(':', '')}',
      name: ap.ssid.isNotEmpty ? ap.ssid : 'Hidden Network',
      description: _generateDescription(ap, cityName),
      status: networkStatus,
      securityType: securityType,
      signalStrength: _calculateSignalPercentage(ap.level),
      macAddress: ap.bssid,
      latitude: latitude,
      longitude: longitude,
      lastSeen: DateTime.now(),
      isConnected: false,
      cityName: cityName,
      address: cityName != null ? '$cityName, CALABARZON' : null,
    );
  }

  /// Analyze network status for threat detection
  NetworkStatus _analyzeNetworkStatus(WiFiAccessPoint ap, String? cityName) {
    // Simple threat analysis logic
    
    // Check for suspicious characteristics
    if (_isSuspiciousNetwork(ap)) {
      return NetworkStatus.suspicious;
    }
    
    // Check if it's a known government/institutional network
    if (_isGovernmentNetwork(ap.ssid)) {
      return NetworkStatus.verified;
    }
    
    // Check if it's a known commercial network
    if (_isCommercialNetwork(ap.ssid)) {
      return NetworkStatus.verified;
    }
    
    // Default to unknown for networks we can't classify
    return NetworkStatus.unknown;
  }

  /// Check if network exhibits suspicious characteristics
  bool _isSuspiciousNetwork(WiFiAccessPoint ap) {
    final ssid = ap.ssid.toLowerCase();
    final capabilities = ap.capabilities.toLowerCase();
    
    // Check for evil twin indicators
    final suspiciousPatterns = [
      'free wifi',
      'free internet',
      'guest',
      'public wifi',
      'hotel wifi',
      'airport wifi',
      'dict-calabarzon-free', // Suspicious variant of official network
      'sm_free_wifi',
      'starbucks_free',
      'mcdo_free',
    ];
    
    for (final pattern in suspiciousPatterns) {
      if (ssid.contains(pattern)) {
        // Additional checks for legitimacy
        if (ap.level > -30) { // Unusually strong signal
          return true;
        }
        if (capabilities.isEmpty || capabilities.contains('open')) {
          return true; // Open network with suspicious name
        }
      }
    }
    
    // Check for suspicious MAC addresses (randomized or spoofed)
    if (ap.bssid.startsWith('02:') || ap.bssid.startsWith('ff:ff:ff')) {
      return true;
    }
    
    return false;
  }

  /// Check if network is a known government network
  bool _isGovernmentNetwork(String ssid) {
    final governmentPatterns = [
      'dict',
      'dost',
      'deped',
      'doh',
      'dtc',
      'lgu',
      'gov-ph',
      'phlpost',
      'nbi',
      'dti',
    ];
    
    final lowerSsid = ssid.toLowerCase();
    return governmentPatterns.any((pattern) => lowerSsid.contains(pattern));
  }

  /// Check if network is a known commercial network
  bool _isCommercialNetwork(String ssid) {
    final commercialPatterns = [
      'sm mall',
      'sm_wifi',
      'robinson',
      'ayala',
      'starbucks',
      'mcdonalds',
      'jollibee',
      'pldt',
      'globe',
      'smart',
      'converge',
    ];
    
    final lowerSsid = ssid.toLowerCase();
    return commercialPatterns.any((pattern) => lowerSsid.contains(pattern));
  }

  /// Convert signal level (dBm) to percentage
  int _calculateSignalPercentage(int levelDbm) {
    // Convert dBm to percentage (rough approximation)
    // -30 dBm = 100%, -90 dBm = 0%
    final percentage = ((levelDbm + 90) * 100 / 60).round();
    return percentage.clamp(0, 100);
  }

  /// Generate network description
  String _generateDescription(WiFiAccessPoint ap, String? cityName) {
    if (cityName != null) {
      return 'Detected in $cityName, CALABARZON';
    }
    return 'Nearby network detected';
  }

  /// Start continuous scanning
  Stream<List<NetworkModel>> startContinuousScanning({Duration interval = const Duration(seconds: 10)}) {
    if (_isScanning) {
      return _scanController!.stream;
    }

    _scanController = StreamController<List<NetworkModel>>.broadcast();
    _isScanning = true;

    _scanTimer = Timer.periodic(interval, (timer) async {
      try {
        final networks = await performScan();
        if (!_scanController!.isClosed) {
          _scanController!.add(networks);
        }
      } catch (e) {
        developer.log('Continuous scan error: $e');
        if (!_scanController!.isClosed) {
          _scanController!.addError(e);
        }
      }
    });

    // Perform initial scan
    performScan().then((networks) {
      if (!_scanController!.isClosed) {
        _scanController!.add(networks);
      }
    });

    return _scanController!.stream;
  }

  /// Stop continuous scanning
  void stopContinuousScanning() {
    _scanTimer?.cancel();
    _scanController?.close();
    _scanTimer = null;
    _scanController = null;
    _isScanning = false;
  }

  /// Check if scanning is currently active
  bool get isScanning => _isScanning;

  /// Get permission status
  Future<bool> hasRequiredPermissions() async {
    try {
      final locationPermission = await Geolocator.checkPermission();
      return locationPermission == LocationPermission.always ||
             locationPermission == LocationPermission.whileInUse;
    } catch (e) {
      return false;
    }
  }

  /// Dispose of resources
  void dispose() {
    stopContinuousScanning();
  }
}