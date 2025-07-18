import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:wifi_iot/wifi_iot.dart';
import '../models/network_model.dart';
import '../models/wifi_connection_result.dart';

/// Native Wi-Fi controller that provides actual device-level Wi-Fi management
class NativeWiFiController {
  static final NativeWiFiController _instance = NativeWiFiController._internal();
  factory NativeWiFiController() => _instance;
  NativeWiFiController._internal();

  // Platform channel for advanced Wi-Fi operations
  static const MethodChannel _channel = MethodChannel('com.dict.disconx/wifi');
  
  // Connection state stream
  final StreamController<WiFiConnectionStatus> _connectionStream = 
      StreamController<WiFiConnectionStatus>.broadcast();
  
  Stream<WiFiConnectionStatus> get connectionStream => _connectionStream.stream;
  
  Timer? _connectionMonitor;
  String? _lastConnectedSSID;

  /// Initialize the Wi-Fi controller
  Future<void> initialize() async {
    try {
      developer.log('Initializing Native Wi-Fi Controller');
      
      // Check if Wi-Fi is enabled
      final isEnabled = await WiFiForIoTPlugin.isEnabled();
      developer.log('Wi-Fi enabled: $isEnabled');
      
      // Start monitoring connection changes
      _startConnectionMonitoring();
      
      developer.log('Native Wi-Fi Controller initialized successfully');
    } catch (e) {
      developer.log('Failed to initialize Native Wi-Fi Controller: $e');
    }
  }

  /// Connect to a Wi-Fi network with actual device control
  Future<WiFiConnectionResult> connectToNetwork({
    required String ssid,
    required String password,
    required SecurityType securityType,
    bool joinOnce = false,
  }) async {
    try {
      developer.log('Attempting native connection to: $ssid');
      
      // Ensure Wi-Fi is enabled
      final isEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isEnabled) {
        developer.log('Wi-Fi is disabled, attempting to enable...');
        final enabled = await WiFiForIoTPlugin.setEnabled(true);
        if (!enabled) {
          developer.log('Failed to enable Wi-Fi');
          return WiFiConnectionResult.failed;
        }
        // Wait for Wi-Fi to stabilize
        await Future.delayed(const Duration(seconds: 2));
      }

      // Disconnect from current network first
      await _disconnectCurrent();

      // Android connection method based on version and security type
      return await _connectAndroid(ssid, password, securityType, joinOnce);
      
    } catch (e) {
      developer.log('Native connection failed: $e');
      return WiFiConnectionResult.error;
    }
  }

  /// Android-specific connection implementation
  Future<WiFiConnectionResult> _connectAndroid(
    String ssid, 
    String password, 
    SecurityType securityType, 
    bool joinOnce
  ) async {
    try {
      developer.log('Using Android native connection for: $ssid');
      
      // For Android 10+ (API 29+), use newer connection methods
      final androidVersion = await _getAndroidApiLevel();
      
      if (androidVersion >= 29) {
        // Android 10+ - Use network suggestions or connection requests
        return await _connectAndroid10Plus(ssid, password, securityType);
      } else {
        // Android 9 and below - Use legacy WifiManager
        return await _connectAndroidLegacy(ssid, password, securityType);
      }
      
    } catch (e) {
      developer.log('Android connection failed: $e');
      return WiFiConnectionResult.error;
    }
  }

  /// Android 10+ connection using network suggestions
  Future<WiFiConnectionResult> _connectAndroid10Plus(
    String ssid, 
    String password, 
    SecurityType securityType
  ) async {
    try {
      developer.log('Using Android 10+ connection method');
      
      // Use wifi_iot plugin with proper configuration
      NetworkSecurity security;
      switch (securityType) {
        case SecurityType.open:
          security = NetworkSecurity.NONE;
          break;
        case SecurityType.wep:
          security = NetworkSecurity.WEP;
          break;
        case SecurityType.wpa2:
          security = NetworkSecurity.WPA;
          break;
        case SecurityType.wpa3:
          security = NetworkSecurity.WPA; // WPA3 falls back to WPA
          break;
      }

      // Connect using wifi_iot plugin with enhanced error handling
      bool connected = false;
      
      developer.log('Attempting connection to $ssid with security: $security');
      
      try {
        if (securityType == SecurityType.open) {
          developer.log('Connecting to open network: $ssid');
          connected = await WiFiForIoTPlugin.connect(
            ssid,
            security: security,
            joinOnce: false, // Use persistent connection
            timeoutInSeconds: 15,
          );
        } else {
          developer.log('Connecting to secured network: $ssid with password');
          connected = await WiFiForIoTPlugin.connect(
            ssid,
            password: password,
            security: security,
            joinOnce: false, // Use persistent connection
            timeoutInSeconds: 15,
          );
        }

        developer.log('wifi_iot connect returned: $connected');

        if (connected) {
          developer.log('wifi_iot reports successful connection, verifying...');
          
          // Wait for connection to stabilize
          await Future.delayed(const Duration(seconds: 3));
          
          // Verify connection multiple ways
          final currentSSID = await getCurrentConnectedSSID();
          final isEnabled = await WiFiForIoTPlugin.isEnabled();
          final isConnected = await WiFiForIoTPlugin.isConnected();
          
          developer.log('Verification: currentSSID=$currentSSID, isEnabled=$isEnabled, isConnected=$isConnected');
          
          if (isConnected && currentSSID != null && currentSSID.toLowerCase() == ssid.toLowerCase()) {
            developer.log('✅ Connection verified successfully to $ssid');
            _lastConnectedSSID = ssid;
            _connectionStream.add(WiFiConnectionStatus.connected);
            return WiFiConnectionResult.success;
          } else {
            developer.log('⚠️ Connection reported successful but verification failed');
          }
        } else {
          developer.log('❌ wifi_iot connect returned false');
        }
      } catch (e) {
        developer.log('❌ wifi_iot connection threw exception: $e');
        connected = false;
      }

      // Try alternative connection methods
      developer.log('Primary connection failed, trying alternative approaches...');
      
      // Alternative 1: Try forceConnectToNetwork with different parameters
      try {
        developer.log('Trying forceConnectToNetwork...');
        final altConnected = await WiFiForIoTPlugin.forceWifiUsage(true);
        if (altConnected) {
          await Future.delayed(const Duration(seconds: 1));
          
          bool finalConnected = false;
          if (securityType == SecurityType.open) {
            finalConnected = await WiFiForIoTPlugin.connect(ssid, security: security);
          } else {
            finalConnected = await WiFiForIoTPlugin.connect(ssid, password: password, security: security);
          }
          
          if (finalConnected) {
            await Future.delayed(const Duration(seconds: 2));
            final verifySSID = await getCurrentConnectedSSID();
            if (verifySSID != null && verifySSID.toLowerCase() == ssid.toLowerCase()) {
              developer.log('✅ Alternative connection successful');
              _lastConnectedSSID = ssid;
              _connectionStream.add(WiFiConnectionStatus.connected);
              return WiFiConnectionResult.success;
            }
          }
        }
      } catch (e) {
        developer.log('Alternative connection failed: $e');
      }
      
      // Enhanced fallback to platform channel or system settings
      try {
        final result = await _channel.invokeMethod('connectWithFallback', {
          'ssid': ssid,
          'password': password,
          'securityType': securityType.toString(),
        });
        
        if (result is Map) {
          final success = result['success'] as bool? ?? false;
          final fallback = result['fallback'] as bool? ?? false;
          
          if (success) {
            developer.log('Platform channel connection successful');
            _lastConnectedSSID = ssid;
            _connectionStream.add(WiFiConnectionStatus.connected);
            return WiFiConnectionResult.success;
          } else if (fallback) {
            developer.log('🚫 Platform channel failed - returning settings redirection');
            return WiFiConnectionResult.redirectedToSettings;
          }
        } else if (result == true) {
          developer.log('Platform channel connection successful (legacy response)');
          _lastConnectedSSID = ssid;
          _connectionStream.add(WiFiConnectionStatus.connected);
          return WiFiConnectionResult.success;
        }
      } catch (e) {
        developer.log('Platform channel connection failed: $e');
        // Continue to final fallback
      }

      // All native methods failed - redirect to system settings
      developer.log('🚫 All native methods failed - returning settings redirection');
      return WiFiConnectionResult.redirectedToSettings;
      
    } catch (e) {
      developer.log('Android 10+ connection error: $e');
      return WiFiConnectionResult.error;
    }
  }

  /// Android 9 and below connection using legacy methods
  Future<WiFiConnectionResult> _connectAndroidLegacy(
    String ssid, 
    String password, 
    SecurityType securityType
  ) async {
    try {
      developer.log('Using legacy Android connection method');
      
      // Use wifi_iot plugin which works better on older Android versions
      NetworkSecurity security;
      switch (securityType) {
        case SecurityType.open:
          security = NetworkSecurity.NONE;
          break;
        case SecurityType.wep:
          security = NetworkSecurity.WEP;
          break;
        case SecurityType.wpa2:
          security = NetworkSecurity.WPA;
          break;
        case SecurityType.wpa3:
          security = NetworkSecurity.WPA;
          break;
      }

      bool connected = false;
      if (securityType == SecurityType.open) {
        connected = await WiFiForIoTPlugin.connect(ssid, security: security);
      } else {
        connected = await WiFiForIoTPlugin.connect(
          ssid, 
          password: password, 
          security: security
        );
      }

      if (connected) {
        developer.log('Legacy connection successful to $ssid');
        
        // Wait for connection to establish
        await Future.delayed(const Duration(seconds: 3));
        
        // Verify connection
        final currentSSID = await getCurrentConnectedSSID();
        if (currentSSID != null && currentSSID.toLowerCase() == ssid.toLowerCase()) {
          _lastConnectedSSID = ssid;
          _connectionStream.add(WiFiConnectionStatus.connected);
          return WiFiConnectionResult.success;
        } else {
          developer.log('Legacy connection verification failed');
        }
      } else {
        developer.log('Legacy connection failed');
      }

      // Legacy connection failed - redirect to system settings
      developer.log('🚫 Legacy connection failed - returning settings redirection');
      return WiFiConnectionResult.redirectedToSettings;
      
    } catch (e) {
      developer.log('Legacy Android connection error: $e');
      return WiFiConnectionResult.error;
    }
  }


  /// Disconnect from current Wi-Fi network
  Future<bool> disconnectFromCurrent() async {
    try {
      developer.log('Disconnecting from current network');
      
      final result = await _disconnectCurrent();
      if (result) {
        _lastConnectedSSID = null;
        _connectionStream.add(WiFiConnectionStatus.disconnected);
      }
      
      return result;
    } catch (e) {
      developer.log('Disconnect failed: $e');
      return false;
    }
  }

  /// Enhanced disconnect method with aggressive verification for Android 13
  Future<bool> _disconnectCurrent() async {
    try {
      developer.log('🔌 Starting enhanced native disconnection for Android 13...');
      
      // Get current SSID before disconnect attempt
      final currentSSIDBeforeDisconnect = await getCurrentConnectedSSID();
      developer.log('Current SSID before disconnect: $currentSSIDBeforeDisconnect');
      
      if (currentSSIDBeforeDisconnect == null || currentSSIDBeforeDisconnect.isEmpty) {
        developer.log('No active connection to disconnect from');
        return true; // Already disconnected
      }
      
      // Step 1: Try WiFiForIoTPlugin disconnect
      bool disconnectAttempted = false;
      try {
        await WiFiForIoTPlugin.disconnect();
        developer.log('✅ WiFiForIoTPlugin.disconnect() called');
        disconnectAttempted = true;
      } catch (e) {
        developer.log('❌ WiFiForIoTPlugin disconnect failed: $e');
      }
      
      // Step 2: Try platform channel disconnect
      try {
        final result = await _channel.invokeMethod('disconnect');
        developer.log('✅ Platform channel disconnect result: $result');
        disconnectAttempted = true;
      } catch (e) {
        developer.log('❌ Platform channel disconnect failed: $e');
      }
      
      if (!disconnectAttempted) {
        developer.log('❌ No disconnect methods succeeded');
        return false;
      }
      
      // Step 3: Enhanced verification with longer timeout for Android 13
      developer.log('🔍 Starting enhanced verification (Android 13 may take longer)...');
      
      for (int round = 1; round <= 2; round++) {
        developer.log('🔄 Verification round $round of 2');
        
        // Wait longer between rounds for Android 13
        await Future.delayed(Duration(seconds: round == 1 ? 3 : 5));
        
        for (int attempt = 1; attempt <= 5; attempt++) {
          await Future.delayed(const Duration(seconds: 2));
          
          final currentSSID = await getCurrentConnectedSSID();
          developer.log('🔍 Round $round - Attempt $attempt: current SSID = $currentSSID');
          
          // Success conditions
          if (currentSSID == null || currentSSID.isEmpty || currentSSID == '<unknown ssid>') {
            developer.log('✅ Disconnect verification successful - no active connection detected');
            return true;
          }
          
          if (currentSSID != currentSSIDBeforeDisconnect) {
            developer.log('✅ Disconnect verification successful - connected to different network: $currentSSID');
            return true;
          }
          
          // For Android 13, try additional force disconnect on persistent connections
          if (round == 2 && attempt == 3) {
            developer.log('🔄 Android 13: Attempting force disconnect for persistent connection');
            try {
              // Try to disable and re-enable WiFi (more aggressive)
              await WiFiForIoTPlugin.setEnabled(false);
              await Future.delayed(const Duration(seconds: 1));
              await WiFiForIoTPlugin.setEnabled(true);
              developer.log('🔄 Android 13: WiFi toggled for force disconnect');
            } catch (e) {
              developer.log('❌ Force disconnect failed: $e');
            }
          }
        }
      }
      
      // Final check after all attempts
      final finalSSID = await getCurrentConnectedSSID();
      if (finalSSID == currentSSIDBeforeDisconnect) {
        developer.log('❌ Enhanced disconnect verification failed - still connected to $finalSSID');
        developer.log('💡 Device may have automatic reconnection enabled for this network');
        return false;
      }
      
      developer.log('✅ Enhanced disconnect appears successful after extended verification');
      return true;
      
    } catch (e) {
      developer.log('❌ Enhanced disconnect error: $e');
      return false;
    }
  }

  /// Get current connected SSID
  Future<String?> getCurrentConnectedSSID() async {
    try {
      final ssid = await WiFiForIoTPlugin.getSSID();
      return ssid;
    } catch (e) {
      developer.log('Failed to get current SSID: $e');
      return null;
    }
  }

  /// Check if connected to a specific network
  Future<bool> isConnectedTo(String ssid) async {
    try {
      final currentSSID = await getCurrentConnectedSSID();
      return currentSSID == ssid;
    } catch (e) {
      developer.log('Failed to check connection to $ssid: $e');
      return false;
    }
  }

  /// Get current connection info
  Future<WiFiConnectionInfo?> getCurrentConnectionInfo() async {
    try {
      final ssid = await WiFiForIoTPlugin.getSSID();
      if (ssid == null || ssid.isEmpty) return null;
      
      final bssid = await WiFiForIoTPlugin.getBSSID();
      final frequency = await WiFiForIoTPlugin.getFrequency();
      final ip = await WiFiForIoTPlugin.getIP();
      
      return WiFiConnectionInfo(
        ssid: ssid,
        bssid: bssid,
        frequency: frequency,
        ipAddress: ip,
      );
      
    } catch (e) {
      developer.log('Failed to get connection info: $e');
      return null;
    }
  }

  /// Start monitoring connection changes
  void _startConnectionMonitoring() {
    _connectionMonitor?.cancel();
    
    _connectionMonitor = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final currentSSID = await getCurrentConnectedSSID();
        
        if (currentSSID != _lastConnectedSSID) {
          developer.log('Connection change detected: $_lastConnectedSSID -> $currentSSID');
          
          if (currentSSID != null && currentSSID.isNotEmpty) {
            _connectionStream.add(WiFiConnectionStatus.connected);
          } else {
            _connectionStream.add(WiFiConnectionStatus.disconnected);
          }
          
          _lastConnectedSSID = currentSSID;
        }
      } catch (e) {
        developer.log('Connection monitoring error: $e');
      }
    });
  }

  /// Get system-saved networks
  Future<List<Map<String, dynamic>>> getSystemSavedNetworks() async {
    try {
      final result = await _channel.invokeMethod('getSavedNetworks');
      if (result is List) {
        return List<Map<String, dynamic>>.from(result);
      }
      return [];
    } catch (e) {
      developer.log('Failed to get system saved networks: $e');
      return [];
    }
  }

  /// Get real-time current connection info from system
  Future<Map<String, dynamic>?> getSystemCurrentConnection() async {
    try {
      final result = await _channel.invokeMethod('getCurrentConnection');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      developer.log('Failed to get system current connection: $e');
      return null;
    }
  }

  /// Check if device is actually connected to specific network
  Future<bool> isActuallyConnectedTo(String ssid) async {
    try {
      final result = await _channel.invokeMethod('isConnectedToNetwork', {'ssid': ssid});
      return result == true;
    } catch (e) {
      developer.log('Failed to check actual connection: $e');
      return false;
    }
  }

  /// Check if network is saved in device settings
  Future<Map<String, dynamic>?> checkSavedNetwork(String ssid) async {
    try {
      final result = await _channel.invokeMethod('checkSavedNetwork', {'ssid': ssid});
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      developer.log('Failed to check saved network: $e');
      return null;
    }
  }
  
  /// Get security analysis for a network
  Future<Map<String, dynamic>?> getSecurityAnalysis(String ssid, SecurityType securityType) async {
    try {
      final result = await _channel.invokeMethod('getSecurityAnalysis', {
        'ssid': ssid,
        'securityType': securityType.toString(),
      });
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      developer.log('Failed to get security analysis: $e');
      return null;
    }
  }
  
  /// Check if device has enhanced permissions for system-level WiFi control
  Future<bool> hasEnhancedPermissions() async {
    try {
      final result = await _channel.invokeMethod('hasEnhancedPermissions');
      return result == true;
    } catch (e) {
      developer.log('Failed to check enhanced permissions: $e');
      return false;
    }
  }
  
  /// Connect to network with enhanced fallback mechanism
  Future<WiFiConnectionResult> connectToNetworkWithFallback({
    required String ssid,
    required String password,
    required SecurityType securityType,
    bool joinOnce = false,
  }) async {
    try {
      developer.log('🎯 Enhanced connection with fallback for: $ssid');
      
      // Ensure Wi-Fi is enabled
      final isEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isEnabled) {
        developer.log('Wi-Fi is disabled, attempting to enable...');
        final enabled = await WiFiForIoTPlugin.setEnabled(true);
        if (!enabled) {
          developer.log('Failed to enable Wi-Fi');
          return WiFiConnectionResult.failed;
        }
        // Wait for Wi-Fi to stabilize
        await Future.delayed(const Duration(seconds: 2));
      }

      // Disconnect from current network first
      await _disconnectCurrent();

      // Use enhanced platform channel with fallback
      try {
        final result = await _channel.invokeMethod('connectWithFallback', {
          'ssid': ssid,
          'password': password,
          'securityType': securityType.toString(),
        });
        
        if (result is Map) {
          final success = result['success'] as bool? ?? false;
          final fallback = result['fallback'] as bool? ?? false;
          
          if (success) {
            developer.log('✅ Enhanced connection successful for $ssid');
            _lastConnectedSSID = ssid;
            _connectionStream.add(WiFiConnectionStatus.connected);
            return WiFiConnectionResult.success;
          } else if (fallback) {
            developer.log('🚫 Enhanced connection failed - returning settings redirection');
            developer.log('Fallback message: ${result['message']}');
            return WiFiConnectionResult.redirectedToSettings;
          }
        } else if (result == true) {
          developer.log('✅ Enhanced connection successful (legacy response)');
          _lastConnectedSSID = ssid;
          _connectionStream.add(WiFiConnectionStatus.connected);
          return WiFiConnectionResult.success;
        }
        
        return WiFiConnectionResult.failed;
        
      } catch (e) {
        developer.log('Enhanced platform connection error: $e');
        return WiFiConnectionResult.error;
      }
      
    } catch (e) {
      developer.log('Enhanced connection with fallback failed: $e');
      return WiFiConnectionResult.error;
    }
  }

  /// Get Android API level
  Future<int> _getAndroidApiLevel() async {
    try {
      // Android API level detection
      
      final apiLevel = await _channel.invokeMethod('getApiLevel');
      return apiLevel ?? 29; // Default to API 29 if unknown
    } catch (e) {
      developer.log('Failed to get Android API level: $e');
      return 29; // Safe default
    }
  }

  /// Stop connection monitoring
  void stopMonitoring() {
    _connectionMonitor?.cancel();
    _connectionMonitor = null;
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _connectionStream.close();
  }
}


extension WiFiConnectionResultExtension on WiFiConnectionResult {
  /// Get user-friendly message for the connection result
  String get message {
    switch (this) {
      case WiFiConnectionResult.success:
        return 'Connected successfully';
      case WiFiConnectionResult.failed:
        return 'Connection failed';
      case WiFiConnectionResult.passwordRequired:
        return 'Password required';
      case WiFiConnectionResult.permissionDenied:
        return 'Permission denied';
      case WiFiConnectionResult.userCancelled:
        return 'Connection cancelled by user';
      case WiFiConnectionResult.redirectedToSettings:
        return 'Redirected to WiFi settings for manual connection';
      case WiFiConnectionResult.notSupported:
        return 'Connection not supported on this platform';
      case WiFiConnectionResult.error:
        return 'Connection error occurred';
    }
  }
  
  /// Check if the result indicates a successful connection
  bool get isSuccess => this == WiFiConnectionResult.success;
  
  /// Check if the result indicates user should manually connect
  bool get requiresManualConnection => this == WiFiConnectionResult.redirectedToSettings;
}

/// Wi-Fi connection status for monitoring
enum WiFiConnectionStatus {
  disconnected,
  connecting,
  connected,
  failed,
}

/// Wi-Fi connection info model
class WiFiConnectionInfo {
  final String ssid;
  final String? bssid;
  final int? frequency;
  final String? ipAddress;

  WiFiConnectionInfo({
    required this.ssid,
    this.bssid,
    this.frequency,
    this.ipAddress,
  });

  @override
  String toString() => 'WiFiConnectionInfo(ssid: $ssid, bssid: $bssid, frequency: $frequency, ip: $ipAddress)';
}