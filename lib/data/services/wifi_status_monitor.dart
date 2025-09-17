import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'native_wifi_controller.dart';
import 'wifi_connection_service.dart' show WiFiConnectionService;
import '../models/network_model.dart';
import '../models/security_assessment.dart';
import '../models/wifi_connection_result.dart';

/// Service that monitors Wi-Fi connection status and provides real-time updates
class WiFiStatusMonitor extends ChangeNotifier {
  static final WiFiStatusMonitor _instance = WiFiStatusMonitor._internal();
  factory WiFiStatusMonitor() => _instance;
  WiFiStatusMonitor._internal();

  final NativeWiFiController _nativeController = NativeWiFiController();
  final WiFiConnectionService _connectionService = WiFiConnectionService();
  
  // Current connection state
  WiFiConnectionInfo? _currentConnection;
  WiFiConnectionStatus _connectionStatus = WiFiConnectionStatus.disconnected;
  bool _isMonitoring = false;
  
  // Stream subscriptions
  StreamSubscription<WiFiConnectionStatus>? _statusSubscription;
  Timer? _periodicUpdate;

  // Getters
  WiFiConnectionInfo? get currentConnection => _currentConnection;
  WiFiConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus == WiFiConnectionStatus.connected && _currentConnection != null;
  bool get isMonitoring => _isMonitoring;

  /// Initialize the monitor
  Future<void> initialize() async {
    if (_isMonitoring) return;
    
    try {
      developer.log('Initializing WiFi Status Monitor');
      
      // Initialize native controller
      await _nativeController.initialize();
      await _connectionService.initialize();
      
      // Start monitoring
      await startMonitoring();
      
      developer.log('WiFi Status Monitor initialized successfully');
    } catch (e) {
      developer.log('Failed to initialize WiFi Status Monitor: $e');
    }
  }

  /// Start monitoring Wi-Fi status changes
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    
    try {
      developer.log('Starting Wi-Fi status monitoring');
      
      // Listen to native controller connection updates
      _statusSubscription = _nativeController.connectionStream.listen(
        (status) {
          _handleConnectionStatusChange(status);
        },
        onError: (error) {
          developer.log('Wi-Fi status stream error: $error');
        },
      );
      
      // Start periodic updates to get connection info
      _periodicUpdate = Timer.periodic(const Duration(seconds: 5), (timer) {
        _updateConnectionInfo();
      });
      
      // Get initial connection state
      await _updateConnectionInfo();
      
      _isMonitoring = true;
      notifyListeners();
      
      developer.log('Wi-Fi status monitoring started');
    } catch (e) {
      developer.log('Failed to start Wi-Fi monitoring: $e');
    }
  }

  /// Stop monitoring Wi-Fi status changes
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    developer.log('Stopping Wi-Fi status monitoring');
    
    _statusSubscription?.cancel();
    _statusSubscription = null;
    
    _periodicUpdate?.cancel();
    _periodicUpdate = null;
    
    _isMonitoring = false;
    notifyListeners();
    
    developer.log('Wi-Fi status monitoring stopped');
  }

  /// Handle connection status changes from native controller
  void _handleConnectionStatusChange(WiFiConnectionStatus newStatus) {
    if (_connectionStatus != newStatus) {
      developer.log('Wi-Fi status changed: $_connectionStatus -> $newStatus');
      
      _connectionStatus = newStatus;
      
      // Update connection info immediately on status change
      _updateConnectionInfo();
      
      notifyListeners();
    }
  }

  /// Update current connection information
  Future<void> _updateConnectionInfo() async {
    try {
      final connectionInfo = await _nativeController.getCurrentConnectionInfo();
      
      if (connectionInfo != _currentConnection) {
        final previousSSID = _currentConnection?.ssid;
        final currentSSID = connectionInfo?.ssid;
        
        if (previousSSID != currentSSID) {
          developer.log('Wi-Fi connection changed: $previousSSID -> $currentSSID');
        }
        
        _currentConnection = connectionInfo;
        
        // Update status based on connection info
        if (connectionInfo != null) {
          _connectionStatus = WiFiConnectionStatus.connected;
        } else {
          _connectionStatus = WiFiConnectionStatus.disconnected;
        }
        
        notifyListeners();
      }
    } catch (e) {
      developer.log('Failed to update connection info: $e');
    }
  }

  /// Force refresh of connection information
  Future<void> refreshConnectionInfo() async {
    developer.log('Force refreshing Wi-Fi connection info');
    await _updateConnectionInfo();
  }

  /// Connect to a network and monitor the result
  Future<WiFiConnectionResult> connectToNetwork({
    required String ssid,
    required String password,
    required SecurityType securityType,
  }) async {
    try {
      developer.log('Connecting to network: $ssid');
      
      // Update status to connecting
      _connectionStatus = WiFiConnectionStatus.connecting;
      notifyListeners();
      
      // Attempt connection
      final result = await _nativeController.connectToNetwork(
        ssid: ssid,
        password: password,
        securityType: securityType,
        joinOnce: true,
      );
      
      // Update connection info after connection attempt
      await Future.delayed(const Duration(seconds: 2));
      await _updateConnectionInfo();
      
      developer.log('Connection result for $ssid: $result');
      return result;
      
    } catch (e) {
      developer.log('Connection error for $ssid: $e');
      _connectionStatus = WiFiConnectionStatus.failed;
      notifyListeners();
      return WiFiConnectionResult.error;
    }
  }

  /// Disconnect from current network and monitor the result
  Future<bool> disconnectFromCurrent() async {
    try {
      developer.log('Disconnecting from current network');
      
      // Update status to disconnecting
      _connectionStatus = WiFiConnectionStatus.disconnected;
      notifyListeners();
      
      // Attempt disconnection
      final result = await _nativeController.disconnectFromCurrent();
      
      // Update connection info after disconnection attempt
      await Future.delayed(const Duration(seconds: 1));
      await _updateConnectionInfo();
      
      developer.log('Disconnection result: $result');
      return result;
      
    } catch (e) {
      developer.log('Disconnection error: $e');
      return false;
    }
  }

  /// Check if connected to a specific network
  bool isConnectedTo(String ssid) {
    return _currentConnection?.ssid == ssid && isConnected;
  }

  /// Get network model for current connection
  NetworkModel? getCurrentNetworkModel() {
    if (_currentConnection == null) return null;
    
    return NetworkModel(
      id: _currentConnection!.ssid.hashCode.toString(),
      name: _currentConnection!.ssid,
      macAddress: _currentConnection!.bssid ?? 'Unknown',
      signalStrength: 100, // Would need actual signal strength from native
      securityType: SecurityType.wpa2, // Would need actual security type
      status: NetworkStatus.unknown, // Would need actual verification status
      latitude: 0.0,
      longitude: 0.0,
      isConnected: true,
      isSaved: false,
      lastSeen: DateTime.now(),
    );
  }

  @override
  void dispose() {
    stopMonitoring();
    _nativeController.dispose();
    super.dispose();
  }
}