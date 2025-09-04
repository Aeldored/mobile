import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/network_model.dart';
import 'wifi_connection_service.dart';
import 'saved_networks_service.dart';
import '../models/wifi_connection_result.dart';
import 'auto_reconnect_manager.dart';
import '../../presentation/dialogs/wifi_connection_dialog.dart';

/// Enhanced Wi-Fi connection manager with robust error handling
class WiFiConnectionManager {
  static final WiFiConnectionManager _instance = WiFiConnectionManager._internal();
  factory WiFiConnectionManager() => _instance;
  WiFiConnectionManager._internal();

  final WiFiConnectionService _connectionService = WiFiConnectionService();
  final SavedNetworksService _savedNetworksService = SavedNetworksService();
  final AutoReconnectManager _autoReconnectManager = AutoReconnectManager();
  
  bool _initialized = false;
  
  // Connection state tracking
  final Map<String, WiFiConnectionState> _connectionStates = <String, WiFiConnectionState>{};
  final StreamController<ConnectionUpdate> _connectionUpdates = StreamController<ConnectionUpdate>.broadcast();

  /// Stream of connection updates
  Stream<ConnectionUpdate> get connectionUpdates => _connectionUpdates.stream;

  /// Get current connection state for a network
  WiFiConnectionState getConnectionState(String networkId) {
    return _connectionStates[networkId] ?? WiFiConnectionState.disconnected;
  }

  /// Connect to a Wi-Fi network with comprehensive error handling
  Future<WiFiConnectionResult> connectToNetwork({
    required BuildContext context,
    required NetworkModel network,
    bool showDialog = true,
    String? presetPassword,
  }) async {
    if (!context.mounted) {
      developer.log('Context not mounted, cannot connect to network');
      return WiFiConnectionResult.error;
    }

    final networkId = network.id;
    developer.log('Starting connection to network: ${network.name} ($networkId)');

    try {
      // Update connection state
      _updateConnectionState(networkId, WiFiConnectionState.connecting);

      // Check if already connected
      if (await _connectionService.isConnectedToNetwork(network.name)) {
        developer.log('Already connected to ${network.name}');
        _updateConnectionState(networkId, WiFiConnectionState.connected);
        return WiFiConnectionResult.success;
      }

      // Check permissions first  
      final hasPermissions = await _checkConnectionPermissions();
      if (!hasPermissions) {
        developer.log('Insufficient permissions for connection');
        _updateConnectionState(networkId, WiFiConnectionState.failed);
        return WiFiConnectionResult.permissionDenied;
      }

      // Check for security warnings
      if (network.status == NetworkStatus.suspicious || network.status == NetworkStatus.blocked) {
        if (!context.mounted) {
          _updateConnectionState(networkId, WiFiConnectionState.failed);
          return WiFiConnectionResult.userCancelled;
        }

        final shouldConnect = await _showSecurityWarning(context, network);
        if (!context.mounted) {
          _updateConnectionState(networkId, WiFiConnectionState.failed);
          return WiFiConnectionResult.error;
        }
        if (!shouldConnect) {
          developer.log('User declined connection due to security warning');
          _updateConnectionState(networkId, WiFiConnectionState.disconnected);
          return WiFiConnectionResult.userCancelled;
        }
      }

      // Check if network is open or if we should try auto-connection
      if (network.securityType == SecurityType.open) {
        // For open networks, still guide to settings for security
        if (showDialog) {
          if (!context.mounted) {
            _updateConnectionState(networkId, WiFiConnectionState.failed);
            return WiFiConnectionResult.error;
          }
          final userConfirmed = await WiFiConnectionDialog.show(context, network);
          if (!context.mounted) {
            _updateConnectionState(networkId, WiFiConnectionState.failed);
            return WiFiConnectionResult.error;
          }
          if (!userConfirmed) {
            developer.log('User cancelled connection dialog for open network');
            _updateConnectionState(networkId, WiFiConnectionState.disconnected);
            return WiFiConnectionResult.userCancelled;
          }
        }
        developer.log('✅ User guided to system settings for open network ${network.name}');
        _updateConnectionState(networkId, WiFiConnectionState.disconnected);
        return WiFiConnectionResult.redirectedToSettings;
      }

      // For secured networks, check if it's saved first
      final autoConnected = await _tryAutoConnection(network);
      if (autoConnected) {
        developer.log('Auto-connection successful for ${network.name}');
        _updateConnectionState(networkId, WiFiConnectionState.connected);
        await _savedNetworksService.saveConnectedNetwork(network);
        return WiFiConnectionResult.success;
      }

      // For secured networks that aren't saved, guide to settings
      if (network.securityType != SecurityType.open) {
        if (!context.mounted) {
          _updateConnectionState(networkId, WiFiConnectionState.failed);
          return WiFiConnectionResult.error;
        }

        if (showDialog) {
          final userConfirmed = await WiFiConnectionDialog.show(context, network);
          if (!context.mounted) {
            _updateConnectionState(networkId, WiFiConnectionState.failed);
            return WiFiConnectionResult.error;
          }
          if (!userConfirmed) {
            developer.log('User cancelled connection dialog');
            _updateConnectionState(networkId, WiFiConnectionState.disconnected);
            return WiFiConnectionResult.userCancelled;
          }
          // For system settings flow, we consider this successful guidance
          _updateConnectionState(networkId, WiFiConnectionState.disconnected);
          return WiFiConnectionResult.redirectedToSettings;
        } else {
          developer.log('User interaction required but dialog disabled');
          _updateConnectionState(networkId, WiFiConnectionState.failed);
          return WiFiConnectionResult.userCancelled;
        }
      }

      // Since we've guided the user to system settings, 
      // the connection process is now handled by the system
      developer.log('✅ User guided to system settings for ${network.name}');
      return WiFiConnectionResult.redirectedToSettings;

    } catch (e) {
      developer.log('Exception during connection to ${network.name}: $e');
      _updateConnectionState(networkId, WiFiConnectionState.failed);
      return WiFiConnectionResult.error;
    }
  }

  /// Check connection permissions with real validation and Android 13 optimization
  Future<bool> _checkConnectionPermissions() async {
    try {
      developer.log('🔐 Checking Wi-Fi connection permissions for Android 13...');
      
      // Android 13+ requires NEARBY_WIFI_DEVICES permission for Wi-Fi scanning
      final wifiPermissionStatus = await Permission.nearbyWifiDevices.status;
        developer.log('📱 Android 13 - NEARBY_WIFI_DEVICES status: $wifiPermissionStatus');
        
        // Request Wi-Fi permission if not granted
        if (wifiPermissionStatus.isDenied) {
          developer.log('🔑 Requesting NEARBY_WIFI_DEVICES permission...');
          final wifiResult = await Permission.nearbyWifiDevices.request();
          
          if (wifiResult.isDenied || wifiResult.isPermanentlyDenied) {
            developer.log('❌ NEARBY_WIFI_DEVICES permission denied - cannot scan or connect to Wi-Fi');
            return false;
          }
          
          developer.log('✅ NEARBY_WIFI_DEVICES permission granted');
        }
        
        // For Android 13+, location permission is still needed for certain Wi-Fi operations
        final locationStatus = await Permission.location.status;
        developer.log('📍 Location permission status: $locationStatus');
        
        if (locationStatus.isDenied) {
          developer.log('🔑 Requesting location permission...');
          final locationResult = await Permission.location.request();
          
          if (locationResult.isDenied || locationResult.isPermanentlyDenied) {
            developer.log('⚠️ Location permission denied - some Wi-Fi features may be limited');
            // On Android 13+, we can still proceed with NEARBY_WIFI_DEVICES permission alone
            final finalWifiStatus = await Permission.nearbyWifiDevices.status;
            return finalWifiStatus.isGranted;
          }
          
          developer.log('✅ Location permission granted');
        }
        
        // Check final permission status
        final finalWifiStatus = await Permission.nearbyWifiDevices.status;
        final finalLocationStatus = await Permission.location.status;
        
        final canProceed = finalWifiStatus.isGranted;
        developer.log('🎯 Android 13 final permission check:');
        developer.log('   - NEARBY_WIFI_DEVICES: ${finalWifiStatus.isGranted}');
        developer.log('   - Location: ${finalLocationStatus.isGranted}');
        developer.log('   - Can proceed: $canProceed');
        
        return canProceed;
      
    } catch (e) {
      developer.log('❌ Permission check failed: $e');
      return false;
    }
  }

  /// Try auto-connection to saved network
  Future<bool> _tryAutoConnection(NetworkModel network) async {
    try {
      final isSaved = await _savedNetworksService.isNetworkSaved(network.name);
      if (!isSaved) return false;

      return await _savedNetworksService.autoConnectToNetwork(network);
    } catch (e) {
      developer.log('Auto-connection failed: $e');
      return false;
    }
  }

  /// Show security warning dialog
  Future<bool> _showSecurityWarning(BuildContext context, NetworkModel network) async {
    if (!context.mounted) return false;

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    } catch (e) {
      developer.log('Error showing security warning: $e');
      return false;
    }
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(String networkId, WiFiConnectionState state) {
    _connectionStates[networkId] = state;
    _connectionUpdates.add(ConnectionUpdate(networkId: networkId, state: state));
  }

  /// CRITICAL FIX: Smart disconnect with auto-reconnect detection
  Future<bool> disconnectFromNetwork(String networkId) async {
    try {
      developer.log('🔌 CRITICAL FIX: Starting SMART disconnection for network: $networkId');
      _updateConnectionState(networkId, WiFiConnectionState.disconnecting);
      
      // Initialize auto-reconnect manager if needed
      if (!_initialized) {
        await _autoReconnectManager.initialize();
        _initialized = true;
      }
      
      // Find the network model for context
      // For now, create a basic network model from networkId
      final network = NetworkModel(
        id: networkId,
        name: networkId, // Using networkId as name - could be enhanced
        macAddress: '',
        signalStrength: 0,
        securityType: SecurityType.open,
        status: NetworkStatus.unknown,
        lastSeen: DateTime.now(),
      );
      
      // For now, use direct disconnect and monitor for auto-reconnect
      _autoReconnectManager.recordDisconnectEvent(network.name);
      final result = await _connectionService.disconnectFromCurrent();
      
      if (result) {
        developer.log('✅ SMART disconnect successful for network: $networkId (AUTO-RECONNECT MANAGED)');
        _updateConnectionState(networkId, WiFiConnectionState.disconnected);
      } else {
        developer.log('❌ SMART disconnect failed for network: $networkId');
        _updateConnectionState(networkId, WiFiConnectionState.failed);
      }
      
      return result;
    } catch (e) {
      developer.log('❌ Exception during SMART disconnection: $e');
      _updateConnectionState(networkId, WiFiConnectionState.failed);
      return false;
    }
  }

  /// Clear all connection states
  void clearConnectionStates() {
    _connectionStates.clear();
  }

  


  /// Dispose resources
  void dispose() {
    _connectionUpdates.close();
    _connectionStates.clear();
    _autoReconnectManager.dispose();
  }
}

/// Wi-Fi connection state enum
enum WiFiConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  failed,
}

/// Connection update model
class ConnectionUpdate {
  final String networkId;
  final WiFiConnectionState state;

  const ConnectionUpdate({
    required this.networkId,
    required this.state,
  });

  @override
  String toString() => 'ConnectionUpdate(networkId: $networkId, state: $state)';
}