import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/network_model.dart';
import '../models/wifi_connection_result.dart';
import 'saved_networks_service.dart';
import 'native_wifi_controller.dart' show NativeWiFiController, WiFiConnectionInfo;
import 'connection_validation_service.dart';
import 'network_activity_tracker.dart';

class WiFiConnectionService {
  static final WiFiConnectionService _instance = WiFiConnectionService._internal();
  factory WiFiConnectionService() => _instance;
  WiFiConnectionService._internal();
  
  final SavedNetworksService _savedNetworksService = SavedNetworksService();
  final NativeWiFiController _nativeController = NativeWiFiController();
  final ConnectionValidationService _validationService = ConnectionValidationService();
  final NetworkActivityTracker _activityTracker = NetworkActivityTracker();
  
  bool _initialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Initialize native controller
      await _nativeController.initialize();
      
      // Initialize activity tracker
      await _activityTracker.initialize();
      
      _initialized = true;
      
      // Android specific initialization logging
      developer.log('📱 WiFiConnectionService initialized on Android device');
      developer.log('🎯 Platform: ${Platform.operatingSystemVersion}');
      developer.log('🔧 Native controller initialized for Android 13+ compatibility');
      developer.log('🚀 Native controller initialized for system settings integration');
      developer.log('📊 Activity tracker initialized for network monitoring');
    } catch (e) {
      developer.log('❌ Failed to initialize WiFiConnectionService: $e');
    }
  }

  /// CRITICAL FIX: Connect to a Wi-Fi network without system settings redirection
  Future<WiFiConnectionResult> connectToNetwork(
    BuildContext context,
    NetworkModel network, {
    String? password,
    bool autoConnect = false,
  }) async {
    try {
      // Ensure service is initialized
      await initialize();
      
      // Check if we have necessary permissions
      final hasPermissions = await _checkConnectionPermissions();
      if (!hasPermissions) {
        developer.log('Connection cancelled: insufficient permissions');
        return WiFiConnectionResult.permissionDenied;
      }

      // ENHANCED: Check if network is saved in device settings first
      final savedNetworkInfo = await _nativeController.checkSavedNetwork(network.name);
      if (savedNetworkInfo != null && savedNetworkInfo['isSaved'] == true) {
        developer.log('Network ${network.name} is saved in device settings - attempting auto-connection');
        
        // Try direct connection without password prompt for saved networks
        final result = await _nativeController.connectToNetwork(
          ssid: network.name,
          password: '', // Empty password - let system handle saved credentials
          securityType: network.securityType,
          joinOnce: false, // Use persistent connection for saved networks
        );
        
        if (result == WiFiConnectionResult.success) {
          // Verify connection was actually established
          await Future.delayed(const Duration(seconds: 2));
          final isActuallyConnected = await _nativeController.isActuallyConnectedTo(network.name);
          if (isActuallyConnected) {
            developer.log('✅ Successfully auto-connected to saved network: ${network.name}');
            return WiFiConnectionResult.success;
          }
        }
        
        developer.log('Auto-connection to saved network failed, proceeding with manual connection');
      }

      // Try auto-connection from local saved networks if enabled
      if (autoConnect) {
        final autoConnected = await _savedNetworksService.autoConnectToNetwork(network);
        if (autoConnected) {
          developer.log('Auto-connected to locally saved network: ${network.name}');
          return WiFiConnectionResult.success;
        }
      }

      // Check if network is saved locally and we have credentials
      String? finalPassword = password;
      if (finalPassword == null && _requiresPassword(network)) {
        final savedPassword = await _savedNetworksService.getSavedCredentials(network.name);
        if (savedPassword != null) {
          finalPassword = savedPassword;
          developer.log('Using locally saved credentials for ${network.name}');
        } else {
          // Only require password if network is not saved in device settings
          if (savedNetworkInfo == null || savedNetworkInfo['isSaved'] != true) {
            return WiFiConnectionResult.passwordRequired;
          }
        }
      }

      // Check for security warnings
      if (network.status == NetworkStatus.suspicious || network.status == NetworkStatus.blocked) {
        if (!context.mounted) return WiFiConnectionResult.userCancelled;
        final shouldConnect = await _showSecurityWarning(context, network);
        if (!context.mounted) return WiFiConnectionResult.userCancelled;
        if (!shouldConnect) {
          return WiFiConnectionResult.userCancelled;
        }
      }

      // Use system settings approach for reliable connections
      developer.log('🔧 Using system settings for reliable connection to ${network.name}');
      
      final result = await _nativeController.connectToNetworkWithFallback(
        ssid: network.name,
        password: finalPassword ?? '',
        securityType: network.securityType,
        joinOnce: true,
      );

      // Validate successful connections
      if (result == WiFiConnectionResult.success) {
        developer.log('🔍 Connection successful, performing validation...');
        
        // Wait for connection to stabilize
        await Future.delayed(const Duration(seconds: 3));
        
        // Verify we're actually connected to the target network
        final currentSSID = await _nativeController.getCurrentConnectedSSID();
        if (currentSSID?.toLowerCase() != network.name.toLowerCase()) {
          developer.log('❌ SSID mismatch after connection - Expected: ${network.name}, Got: $currentSSID');
          await disconnectFromCurrent();
          return WiFiConnectionResult.failed;
        }
        
        // Perform comprehensive connection validation
        final validationResult = await _validationService.validateConnection(
          networkName: network.name,
          checkInternet: true,
          timeout: const Duration(seconds: 15),
        );
        
        if (validationResult.isValid) {
          // Save network credentials only after full validation
          await _savedNetworksService.saveConnectedNetwork(network);
          if (finalPassword != null && finalPassword.isNotEmpty) {
            await _savedNetworksService.saveNetworkCredentials(network.name, finalPassword);
          }
          
          // 📊 ACTIVITY TRACKING: Start tracking this connection
          try {
            await _activityTracker.trackConnection(network);
            developer.log('📊 Activity tracking started for ${network.name}');
          } catch (e) {
            developer.log('⚠️ Activity tracking failed (connection still successful): $e');
          }
          
          developer.log('✅ DIRECT connection validation passed for ${network.name}');
          developer.log('✅ NO SYSTEM SETTINGS REDIRECTION - Connection handled in-app');
          developer.log('Validation details: ${validationResult.validationSteps.map((s) => s.toString()).join(", ")}');
          return WiFiConnectionResult.success;
        } else {
          developer.log('❌ DIRECT connection validation failed for ${network.name}');
          developer.log('Failure reason: ${validationResult.failureReason}');
          developer.log('Failed steps: ${validationResult.validationSteps.where((s) => !s.passed).map((s) => s.name).join(", ")}');
          
          // Disconnect using direct controller
          await disconnectFromCurrent();
          return WiFiConnectionResult.failed;
        }
      } else {
        developer.log('❌ DIRECT connection failed for ${network.name}: $result');
      }

      return result;
    } catch (e) {
      developer.log('Wi-Fi connection error: $e');
      return WiFiConnectionResult.error;
    }
  }

  /// Check if network requires a password
  bool _requiresPassword(NetworkModel network) {
    return network.securityType != SecurityType.open;
  }

  /// Check if we have the necessary permissions for Wi-Fi connection
  Future<bool> _checkConnectionPermissions() async {
    try {
      // Check location permission first
      final locationStatus = await Permission.location.status;
      if (locationStatus.isPermanentlyDenied) {
        developer.log('Location permission permanently denied');
        return false;
      }
      
      if (locationStatus.isDenied) {
        developer.log('Location permission denied - cannot proceed with connection');
        return false;
      }
      
      // Check Wi-Fi permission for Android 13+
      final wifiStatus = await Permission.nearbyWifiDevices.status;
        if (wifiStatus.isPermanentlyDenied) {
          developer.log('Wi-Fi permission permanently denied');
          return false;
        }
        
        if (wifiStatus.isDenied) {
          developer.log('Wi-Fi permission denied - cannot proceed with connection');
          return false;
        }
        
      return locationStatus.isGranted && wifiStatus.isGranted;
    } catch (e) {
      developer.log('Permission check failed: $e');
      return false;
    }
  }

  /// Show security warning for suspicious networks
  Future<bool> _showSecurityWarning(BuildContext context, NetworkModel network) async {
    if (!context.mounted) return false;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.warning,
              color: Colors.orange,
              size: 24,
            ),
            SizedBox(width: 8),
            Text('Security Warning'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (network.status == NetworkStatus.suspicious) ...[
              const Text(
                'This network has been flagged as potentially suspicious.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'It may be an "evil twin" attack attempting to steal your data. '
                'Connecting could compromise your personal information.',
              ),
            ] else if (network.status == NetworkStatus.blocked) ...[
              const Text(
                'This network has been blocked.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'You previously marked this network as unsafe. '
                'Are you sure you want to connect?',
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.red[700], size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'DICT recommends avoiding this connection',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.of(context).pop(false);
              }
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Connect Anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }




  /// Show password input dialog (deprecated - use WiFiPasswordDialog.show instead)
  @Deprecated('Use WiFiPasswordDialog.show for better error handling')
  Future<String?> showPasswordDialog(BuildContext context, NetworkModel network) async {
    // This method is kept for compatibility but redirects to the new dialog
    return null;
  }

  /// Disconnect from current Wi-Fi network using native controller
  Future<bool> disconnectFromCurrent() async {
    try {
      await initialize();
      
      // 📊 ACTIVITY TRACKING: Track disconnection before actually disconnecting
      try {
        await _activityTracker.trackDisconnection();
        developer.log('📊 Activity tracking: Disconnection recorded');
      } catch (e) {
        developer.log('⚠️ Activity tracking disconnect failed (proceeding with disconnect): $e');
      }
      
      developer.log('🔌 Using native controller for disconnect');
      
      final result = await _nativeController.disconnectFromCurrent();
      if (result) {
        developer.log('✅ Successfully disconnected via native controller');
      } else {
        developer.log('❌ Disconnect failed');
      }
      
      return result;
    } catch (e) {
      developer.log('❌ Disconnect error: $e');
      return false;
    }
  }

  /// Check current connection status using native controller
  Future<bool> isConnectedToNetwork(String networkName) async {
    try {
      await initialize();
      
      return await _nativeController.isConnectedTo(networkName);
    } catch (e) {
      developer.log('Failed to check connection status: $e');
      return false;
    }
  }

  /// Get current connected network information
  Future<WiFiConnectionInfo?> getCurrentConnectionInfo() async {
    try {
      await initialize();
      return await _nativeController.getCurrentConnectionInfo();
    } catch (e) {
      developer.log('Failed to get current connection info: $e');
      return null;
    }
  }

  /// Check if a network is saved/known
  Future<bool> isNetworkSaved(String ssid) async {
    return await _savedNetworksService.isNetworkSaved(ssid);
  }

  /// Get list of saved networks
  Future<List<SavedNetwork>> getSavedNetworks() async {
    return await _savedNetworksService.getSavedNetworks();
  }

  /// Remove saved network
  Future<void> removeSavedNetwork(String ssid) async {
    await _savedNetworksService.removeSavedNetwork(ssid);
  }

  /// Auto-connect to saved networks during scan
  Future<List<NetworkModel>> checkForAutoConnect(List<NetworkModel> networks) async {
    final List<NetworkModel> updatedNetworks = <NetworkModel>[];
    
    for (final network in networks) {
      final isSaved = await isNetworkSaved(network.name);
      final updatedNetwork = NetworkModel(
        id: network.id,
        name: network.name,
        macAddress: network.macAddress,
        signalStrength: network.signalStrength,
        securityType: network.securityType,
        status: network.status,
        latitude: network.latitude,
        longitude: network.longitude,
        description: network.description,
        isConnected: network.isConnected,
        isSaved: isSaved, // Mark if network is saved
        lastSeen: network.lastSeen,
      );
      updatedNetworks.add(updatedNetwork);
    }
    
    return updatedNetworks;
  }
}

// WiFiConnectionResult enum is now defined in native_wifi_controller.dart