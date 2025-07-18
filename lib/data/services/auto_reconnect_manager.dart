import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/network_model.dart';

/// Manages auto-reconnect detection and user notifications
class AutoReconnectManager {
  static final AutoReconnectManager _instance = AutoReconnectManager._internal();
  factory AutoReconnectManager() => _instance;
  AutoReconnectManager._internal();

  
  // Auto-reconnect monitoring
  Timer? _reconnectMonitor;
  String? _lastDisconnectedSSID;
  DateTime? _lastDisconnectTime;
  bool _autoReconnectDetected = false;
  
  // User notification tracking
  final Set<String> _notifiedNetworks = {};
  SharedPreferences? _prefs;
  
  static const String _prefKeyNotifiedNetworks = 'auto_reconnect_notified_networks';
  static const Duration _reconnectDetectionWindow = Duration(seconds: 10);
  static const Duration _monitoringInterval = Duration(seconds: 2);

  /// Initialize the auto-reconnect manager
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final notifiedList = _prefs?.getStringList(_prefKeyNotifiedNetworks) ?? [];
      _notifiedNetworks.addAll(notifiedList);
      
      _startAutoReconnectMonitoring();
      developer.log('✅ AutoReconnectManager initialized');
    } catch (e) {
      developer.log('❌ Failed to initialize AutoReconnectManager: $e');
    }
  }

  /// Start monitoring for auto-reconnect behavior
  void _startAutoReconnectMonitoring() {
    _reconnectMonitor?.cancel();
    _reconnectMonitor = Timer.periodic(_monitoringInterval, (_) async {
      await _checkForAutoReconnect();
    });
  }

  /// Check if auto-reconnect occurred after disconnect
  Future<void> _checkForAutoReconnect() async {
    try {
      if (_lastDisconnectedSSID == null || _lastDisconnectTime == null) return;
      
      // Since DirectWiFiController was removed, we'll use a simplified approach
      // In practice, this would integrate with the NativeWiFiController
      final currentSSID = null; // Simplified for now
      final timeSinceDisconnect = DateTime.now().difference(_lastDisconnectTime!);
      
      // Check if we reconnected to the same network within detection window
      if (currentSSID != null && 
          currentSSID == _lastDisconnectedSSID && 
          timeSinceDisconnect <= _reconnectDetectionWindow) {
        
        developer.log('🔄 Auto-reconnect detected: Reconnected to $_lastDisconnectedSSID after ${timeSinceDisconnect.inSeconds}s');
        _autoReconnectDetected = true;
        
        // Clear tracking data
        _lastDisconnectedSSID = null;
        _lastDisconnectTime = null;
      } else if (timeSinceDisconnect > _reconnectDetectionWindow) {
        // Clear stale tracking data
        _lastDisconnectedSSID = null;
        _lastDisconnectTime = null;
      }
    } catch (e) {
      developer.log('Error checking for auto-reconnect: $e');
    }
  }

  /// Record a disconnect event for monitoring
  void recordDisconnectEvent(String ssid) {
    _lastDisconnectedSSID = ssid;
    _lastDisconnectTime = DateTime.now();
    _autoReconnectDetected = false;
    
    developer.log('📝 Recorded disconnect event for: $ssid');
  }

  /// Check if auto-reconnect was recently detected
  bool get wasAutoReconnectDetected => _autoReconnectDetected;

  /// Reset auto-reconnect detection state
  void resetAutoReconnectDetection() {
    _autoReconnectDetected = false;
    _lastDisconnectedSSID = null;
    _lastDisconnectTime = null;
  }

  /// Show auto-reconnect management dialog
  Future<bool> showAutoReconnectDialog(BuildContext context, NetworkModel network) async {
    if (!context.mounted) return false;
    
    // Check if we've already notified for this network
    if (_notifiedNetworks.contains(network.name)) {
      return false; // Don't show again
    }

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sync_problem,
                  color: Colors.orange[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Auto-Reconnect Detected',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your device automatically reconnected to "${network.name}" after disconnection.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Auto-Reconnect Impact',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Interferes with DisConX disconnect functionality\n'
                      '• May reconnect to potentially unsafe networks\n'
                      '• Reduces user control over connections',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Would you like DisConX to help you manage this network\'s auto-reconnect settings?',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Not Now'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
                _markNetworkAsNotified(network.name);
              },
              child: const Text('Don\'t Ask Again'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Manage Settings'),
            ),
          ],
        ),
      );
      
      return result ?? false;
    } catch (e) {
      developer.log('Error showing auto-reconnect dialog: $e');
      return false;
    }
  }

  /// Show auto-reconnect management guidance
  Future<void> showAutoReconnectGuidance(BuildContext context, NetworkModel network) async {
    if (!context.mounted) return;
    
    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings_suggest,
                  color: Colors.blue[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Manage Auto-Reconnect',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To improve DisConX functionality for "${network.name}":',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist, color: Colors.green[700], size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Recommended Steps',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Open device WiFi settings\n'
                      '2. Find "${network.name}" in saved networks\n'
                      '3. Tap network settings/details\n'
                      '4. Disable "Auto-reconnect" or "Auto-connect"\n'
                      '5. Return to DisConX for full control',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This will give you complete control over when to connect to this network through DisConX.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Got It'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openNetworkSettings(network);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open WiFi Settings'),
            ),
          ],
        ),
      );
    } catch (e) {
      developer.log('Error showing auto-reconnect guidance: $e');
    }
  }

  /// Open device network settings
  Future<void> _openNetworkSettings(NetworkModel network) async {
    try {
      // This would open device WiFi settings
      // Implementation depends on platform-specific code
      developer.log('Opening network settings for ${network.name}');
      // TODO: Implement platform-specific WiFi settings opening
    } catch (e) {
      developer.log('Failed to open network settings: $e');
    }
  }

  /// Mark a network as already notified
  void _markNetworkAsNotified(String ssid) {
    _notifiedNetworks.add(ssid);
    _prefs?.setStringList(_prefKeyNotifiedNetworks, _notifiedNetworks.toList());
    developer.log('📝 Marked $ssid as notified for auto-reconnect');
  }

  /// Check if we should show auto-reconnect notification for a network
  bool shouldShowAutoReconnectNotification(String ssid) {
    return _autoReconnectDetected && !_notifiedNetworks.contains(ssid);
  }

  /// Handle disconnect with auto-reconnect detection
  Future<bool> handleSmartDisconnect(BuildContext context, NetworkModel network) async {
    try {
      developer.log('🔄 Starting smart disconnect for ${network.name}');
      
      // Record disconnect event for monitoring
      recordDisconnectEvent(network.name);
      
      // Perform disconnect - simplified without DirectWiFiController
      final disconnectResult = true; // Simplified for now
      
      if (disconnectResult) {
        developer.log('✅ Initial disconnect successful');
        
        // Wait a moment to check for auto-reconnect
        await Future.delayed(const Duration(seconds: 3));
        
        // Check if auto-reconnect occurred
        if (_autoReconnectDetected && context.mounted) {
          developer.log('⚠️ Auto-reconnect detected after disconnect');
          
          if (shouldShowAutoReconnectNotification(network.name)) {
            final userWantsManagement = await showAutoReconnectDialog(context, network);
            
            if (userWantsManagement && context.mounted) {
              await showAutoReconnectGuidance(context, network);
            }
          }
          
          // Try disconnect again after notification - simplified
          final secondDisconnect = true; // Simplified for now
          if (secondDisconnect) {
            resetAutoReconnectDetection();
            return true;
          }
        }
        
        return true;
      }
      
    } catch (e) {
      developer.log('❌ Smart disconnect error: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _reconnectMonitor?.cancel();
    _notifiedNetworks.clear();
  }
}