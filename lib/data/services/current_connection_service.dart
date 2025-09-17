import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/network_model.dart';
import '../models/security_assessment.dart';
import 'permission_service.dart';
import 'wifi_status_monitor.dart';

/// Service to manage current Wi-Fi connection information
class CurrentConnectionService {
  static final CurrentConnectionService _instance = CurrentConnectionService._internal();
  factory CurrentConnectionService() => _instance;
  CurrentConnectionService._internal();

  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();
  final PermissionService _permissionService = PermissionService();
  final WiFiStatusMonitor _statusMonitor = WiFiStatusMonitor();

  /// Initialize the service
  Future<void> initialize() async {
    try {
      await _statusMonitor.initialize();
      developer.log('CurrentConnectionService initialized with native monitoring');
    } catch (e) {
      developer.log('Failed to initialize CurrentConnectionService: $e');
    }
  }

  /// Get current Wi-Fi connection information using native monitoring
  Future<NetworkModel?> getCurrentConnection() async {
    try {
      // Initialize if not already done
      await initialize();
      
      // Try to get connection from native monitor first
      final nativeConnection = _statusMonitor.getCurrentNetworkModel();
      if (nativeConnection != null) {
        developer.log('Got current connection from native monitor: ${nativeConnection.name}');
        return nativeConnection;
      }
      
      // Fallback to legacy method
      return await _getCurrentConnectionLegacy();
    } catch (e) {
      developer.log('Error getting current connection: $e');
      return await _getCurrentConnectionLegacy();
    }
  }

  /// Legacy method for getting current connection (fallback)
  Future<NetworkModel?> _getCurrentConnectionLegacy() async {
    try {
      // Check connection type
      final connectivityResult = await _connectivity.checkConnectivity();
      
      if (!connectivityResult.contains(ConnectivityResult.wifi)) {
        developer.log('Not connected to Wi-Fi. Connection types: $connectivityResult');
        return null;
      }

      // Check permissions
      final hasPermissions = await _permissionService.checkAllPermissions();
      if (hasPermissions != PermissionStatus.granted) {
        developer.log('Insufficient permissions to get connection info');
        return null;
      }

      // Get Wi-Fi network information
      final ssid = await _networkInfo.getWifiName();
      final bssid = await _networkInfo.getWifiBSSID();
      final ip = await _networkInfo.getWifiIP();

      if (ssid == null || ssid.isEmpty) {
        developer.log('Unable to get SSID - may be hidden or permissions insufficient');
        return null;
      }

      // Clean SSID (remove quotes if present)
      final cleanSsid = ssid.replaceAll('"', '');

      // Create network model for current connection
      final currentNetwork = NetworkModel(
        id: 'current_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanSsid,
        description: 'Currently connected network',
        status: _analyzeCurrentNetworkStatus(cleanSsid, bssid),
        securityType: _determineSecurityType(cleanSsid),
        signalStrength: await _getCurrentSignalStrength(),
        macAddress: bssid ?? 'Unknown',
        isConnected: true,
        lastSeen: DateTime.now(),
        ipAddress: ip,
      );

      developer.log('Current connection: ${currentNetwork.name} (${currentNetwork.macAddress})');
      return currentNetwork;
    } catch (e) {
      developer.log('Error getting current connection: $e');
      return null;
    }
  }

  /// Get current Wi-Fi signal strength
  Future<int> _getCurrentSignalStrength() async {
    try {
      // Note: Getting exact signal strength requires platform-specific code
      // For now, we'll return a default value indicating connection is active
      return 75; // Assume good signal for connected network
    } catch (e) {
      developer.log('Error getting signal strength: $e');
      return 50; // Default moderate signal
    }
  }

  /// Analyze current network status for security
  NetworkStatus _analyzeCurrentNetworkStatus(String ssid, String? bssid) {
    final lowerSsid = ssid.toLowerCase();

    // Check for government networks
    if (_isGovernmentNetwork(lowerSsid)) {
      return NetworkStatus.verified;
    }

    // Check for known commercial networks
    if (_isCommercialNetwork(lowerSsid)) {
      return NetworkStatus.verified;
    }

    // Check for suspicious patterns
    if (_isSuspiciousNetwork(lowerSsid)) {
      return NetworkStatus.suspicious;
    }

    // Default to unknown for unrecognized networks
    return NetworkStatus.unknown;
  }

  /// Determine security type based on SSID patterns
  SecurityType _determineSecurityType(String ssid) {
    final lowerSsid = ssid.toLowerCase();

    // Open networks often have specific patterns
    if (lowerSsid.contains('free') || 
        lowerSsid.contains('guest') || 
        lowerSsid.contains('public')) {
      return SecurityType.open;
    }

    // Most modern networks use WPA2 or WPA3
    return SecurityType.wpa2;
  }

  /// Check if network is a government network
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
      'dict-calabarzon',
    ];
    
    return governmentPatterns.any((pattern) => ssid.contains(pattern));
  }

  /// Check if network is a commercial network
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
      'sky',
      'bayantel',
    ];
    
    return commercialPatterns.any((pattern) => ssid.contains(pattern));
  }

  /// Check if network exhibits suspicious characteristics
  bool _isSuspiciousNetwork(String ssid) {
    final suspiciousPatterns = [
      'free wifi',
      'free internet',
      'guest',
      'public wifi',
      'hotel wifi',
      'airport wifi',
      'dict-calabarzon-free', // Suspicious variant
      'sm_free_wifi',
      'starbucks_free',
      'mcdo_free',
      'globe_free',
      'smart_free',
    ];
    
    return suspiciousPatterns.any((pattern) => ssid.contains(pattern));
  }

  /// Listen to connectivity changes
  Stream<NetworkModel?> watchConnectionChanges() {
    return _connectivity.onConnectivityChanged.asyncMap((results) async {
      if (results.contains(ConnectivityResult.wifi)) {
        return await getCurrentConnection();
      } else {
        return null;
      }
    });
  }

  /// Check if device is connected to Wi-Fi
  Future<bool> isConnectedToWifi() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult.contains(ConnectivityResult.wifi);
    } catch (e) {
      developer.log('Error checking Wi-Fi connection: $e');
      return false;
    }
  }

  /// Get connection type as string
  Future<String> getConnectionTypeString() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      
      if (connectivityResults.contains(ConnectivityResult.wifi)) {
        return 'Wi-Fi';
      } else if (connectivityResults.contains(ConnectivityResult.mobile)) {
        return 'Mobile Data';
      } else if (connectivityResults.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      } else if (connectivityResults.contains(ConnectivityResult.vpn)) {
        return 'VPN';
      } else if (connectivityResults.contains(ConnectivityResult.bluetooth)) {
        return 'Bluetooth';
      } else if (connectivityResults.contains(ConnectivityResult.other)) {
        return 'Other';
      } else if (connectivityResults.contains(ConnectivityResult.none)) {
        return 'No Connection';
      } else {
        return 'Unknown';
      }
    } catch (e) {
      developer.log('Error getting connection type: $e');
      return 'Unknown';
    }
  }

  /// Refresh current connection information
  Future<void> refreshCurrentConnection() async {
    try {
      await _statusMonitor.refreshConnectionInfo();
      developer.log('Current connection refreshed');
    } catch (e) {
      developer.log('Error refreshing current connection: $e');
    }
  }

  /// Check if connected to a specific network
  bool isConnectedTo(String ssid) {
    return _statusMonitor.isConnectedTo(ssid);
  }

  /// Get the status monitor for real-time updates
  WiFiStatusMonitor get statusMonitor => _statusMonitor;

  /// Disconnect from current network
  Future<bool> disconnectFromCurrent() async {
    try {
      return await _statusMonitor.disconnectFromCurrent();
    } catch (e) {
      developer.log('Error disconnecting from current network: $e');
      return false;
    }
  }
}