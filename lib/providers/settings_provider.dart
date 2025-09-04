import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../data/services/permission_service.dart';
import '../data/models/network_model.dart';
import 'network_provider.dart';
import 'alert_provider.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final PermissionService _permissionService = PermissionService();
  
  // Provider dependencies
  NetworkProvider? _networkProvider;
  AlertProvider? _alertProvider;
  
  // Settings state
  bool _locationEnabled = true;
  bool _autoBlockSuspicious = false; // CRITICAL FIX: Default to disabled as required
  bool _notificationsEnabled = true;
  int _networkHistoryDays = 30;
  bool _showVerifiedNetworks = false; // Hide verified networks by default
  
  // Permission status tracking
  PermissionStatus _locationPermissionStatus = PermissionStatus.denied;
  PermissionStatus _notificationPermissionStatus = PermissionStatus.denied;
  
  // Permission request management
  bool _isRequestingLocationPermission = false;
  bool _isRequestingNotificationPermission = false;
  
  // Storage tracking
  double _storageUsedMB = 0.0;
  final double _maxStorageMB = 100.0;

  // Getters
  bool get locationEnabled => _locationEnabled;
  bool get autoBlockSuspicious => _autoBlockSuspicious;
  bool get notificationsEnabled => _notificationsEnabled;
  int get networkHistoryDays => _networkHistoryDays;
  bool get showVerifiedNetworks => _showVerifiedNetworks;
  
  // Permission status getters
  PermissionStatus get locationPermissionStatus => _locationPermissionStatus;
  PermissionStatus get notificationPermissionStatus => _notificationPermissionStatus;
  
  // Permission request state getters
  bool get isRequestingLocationPermission => _isRequestingLocationPermission;
  bool get isRequestingNotificationPermission => _isRequestingNotificationPermission;
  
  // Storage getters
  double get storageUsedMB => _storageUsedMB;
  double get maxStorageMB => _maxStorageMB;
  double get storageUsagePercentage => _storageUsedMB / _maxStorageMB;
  String get storageUsedText => '${_storageUsedMB.toStringAsFixed(1)} MB';
  
  // Computed getters
  bool get isLocationActuallyAvailable => 
      _locationEnabled && _locationPermissionStatus == PermissionStatus.granted;
  
  String get locationStatusText {
    if (!_locationEnabled) return 'Disabled';
    switch (_locationPermissionStatus) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      default:
        return 'Unknown';
    }
  }
  
  String get notificationStatusText {
    if (!_notificationsEnabled) return 'Disabled';
    switch (_notificationPermissionStatus) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      default:
        return 'Unknown';
    }
  }

  SettingsProvider(this._prefs) {
    _loadSettings();
    _syncPermissionStatus();
    _calculateStorageUsage();
  }
  
  /// Set provider dependencies for cross-provider communication
  void setProviderDependencies(NetworkProvider? networkProvider, AlertProvider? alertProvider) {
    _networkProvider = networkProvider;
    _alertProvider = alertProvider;
    developer.log('SettingsProvider: Dependencies set');
  }

  void _loadSettings() {
    _locationEnabled = _prefs.getBool('locationEnabled') ?? true;
    _autoBlockSuspicious = _prefs.getBool('autoBlockSuspicious') ?? false; // CRITICAL FIX: Default to disabled
    _notificationsEnabled = _prefs.getBool('notificationsEnabled') ?? true;
    _networkHistoryDays = _prefs.getInt('networkHistoryDays') ?? 30;
    _showVerifiedNetworks = _prefs.getBool('showVerifiedNetworks') ?? false; // Default to false (hidden)
    
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    await _prefs.setBool('locationEnabled', _locationEnabled);
    await _prefs.setBool('autoBlockSuspicious', _autoBlockSuspicious);
    await _prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await _prefs.setInt('networkHistoryDays', _networkHistoryDays);
    await _prefs.setBool('showVerifiedNetworks', _showVerifiedNetworks);
  }


  Future<void> toggleLocation() async {
    developer.log('Toggling location: current state = $_locationEnabled');
    
    // Prevent multiple simultaneous permission requests
    if (_isRequestingLocationPermission) {
      developer.log('Location permission request already in progress');
      return;
    }
    
    if (!_locationEnabled) {
      // If currently disabled, try to enable by requesting permission
      _isRequestingLocationPermission = true;
      notifyListeners(); // Update UI to show loading state
      
      try {
        final permissionGranted = await _permissionService.requestLocationPermission();
        _locationPermissionStatus = permissionGranted;
        
        if (permissionGranted == PermissionStatus.granted) {
          _locationEnabled = true;
          developer.log('Location enabled successfully');
          
          // Notify NetworkProvider that location is now available
          if (_networkProvider != null) {
            await _networkProvider!.refreshPermissionStatus();
          }
        } else {
          // Permission denied, keep location disabled
          _locationEnabled = false;
          developer.log('Location permission denied');
        }
      } catch (e) {
        developer.log('Error requesting location permission: $e');
        _locationEnabled = false;
      } finally {
        _isRequestingLocationPermission = false;
      }
    } else {
      // If currently enabled, just disable (we can't revoke permissions programmatically)
      _locationEnabled = false;
      developer.log('Location disabled by user');
    }
    
    await _saveSettings();
    notifyListeners();
  }

  Future<void> toggleAutoBlock() async {
    _autoBlockSuspicious = !_autoBlockSuspicious;
    developer.log('🔧 SETTINGS: Auto-block suspicious networks toggled to: $_autoBlockSuspicious');
    
    // Apply auto-block setting to NetworkProvider if available
    if (_networkProvider != null && _autoBlockSuspicious) {
      // Auto-block any currently detected suspicious networks
      final suspiciousNetworks = _networkProvider!.networks
          .where((n) => n.status == NetworkStatus.suspicious)
          .toList();
      
      for (final network in suspiciousNetworks) {
        await _networkProvider!.blockNetwork(network.id);
      }
      
      if (suspiciousNetworks.isNotEmpty) {
        developer.log('Auto-blocked ${suspiciousNetworks.length} suspicious networks');
      }
    }
    
    await _saveSettings();
    notifyListeners();
  }

  Future<void> toggleShowVerifiedNetworks() async {
    _showVerifiedNetworks = !_showVerifiedNetworks;
    developer.log('Show verified networks: $_showVerifiedNetworks');
    
    await _saveSettings();
    notifyListeners();
  }

  Future<void> toggleNotifications() async {
    // Prevent multiple simultaneous permission requests
    if (_isRequestingNotificationPermission) {
      developer.log('Notification permission request already in progress');
      return;
    }
    
    if (!_notificationsEnabled) {
      // If currently disabled, try to enable by requesting permission
      _isRequestingNotificationPermission = true;
      notifyListeners(); // Update UI to show loading state
      
      try {
        // Check current status first to avoid unnecessary requests
        final currentStatus = await Permission.notification.status;
        
        PermissionStatus status;
        if (currentStatus == PermissionStatus.granted) {
          // Already granted, no need to request
          status = currentStatus;
        } else {
          // Request permission
          status = await Permission.notification.request();
        }
        
        _notificationPermissionStatus = status;
        
        if (status == PermissionStatus.granted) {
          _notificationsEnabled = true;
          developer.log('Notifications enabled successfully');
        } else {
          _notificationsEnabled = false;
          developer.log('Notification permission denied: $status');
        }
      } catch (e) {
        developer.log('Error requesting notification permission: $e');
        _notificationsEnabled = false;
        // Fallback: just check the current status without requesting
        try {
          _notificationPermissionStatus = await Permission.notification.status;
        } catch (statusError) {
          developer.log('Error checking notification status: $statusError');
          _notificationPermissionStatus = PermissionStatus.denied;
        }
      } finally {
        _isRequestingNotificationPermission = false;
      }
    } else {
      _notificationsEnabled = false;
      developer.log('Notifications disabled by user');
    }
    
    // Update AlertProvider notification settings
    if (_alertProvider != null) {
      _alertProvider!.setNotificationsEnabled(_notificationsEnabled);
    }
    
    await _saveSettings();
    notifyListeners();
  }


  void setNetworkHistoryDays(int days) {
    _networkHistoryDays = days;
    _saveSettings();
    notifyListeners();
  }

  /// Sync settings with actual system permissions
  Future<void> _syncPermissionStatus() async {
    // Don't sync if we're currently requesting permissions
    if (_isRequestingLocationPermission || _isRequestingNotificationPermission) {
      developer.log('Skipping permission sync - requests in progress');
      return;
    }
    
    try {
      // Check location permission
      _locationPermissionStatus = await _permissionService.checkLocationPermission();
      
      // Check notification permission
      _notificationPermissionStatus = await Permission.notification.status;
      
      bool needsSave = false;
      
      // Sync location setting with actual permission
      if (_locationEnabled && _locationPermissionStatus != PermissionStatus.granted) {
        developer.log('Location setting enabled but permission denied - updating setting');
        _locationEnabled = false;
        needsSave = true;
      }
      
      // Sync notification setting with actual permission
      if (_notificationsEnabled && _notificationPermissionStatus != PermissionStatus.granted) {
        developer.log('Notification setting enabled but permission denied - updating setting');
        _notificationsEnabled = false;
        needsSave = true;
      }
      
      if (needsSave) {
        await _saveSettings();
      }
      
      notifyListeners();
    } catch (e) {
      developer.log('Error syncing permission status: $e');
    }
  }
  
  /// Manually refresh permission status (called from other parts of app)
  Future<void> refreshPermissionStatus() async {
    await _syncPermissionStatus();
  }

  /// Get current permission status for location
  Future<PermissionStatus> getLocationPermissionStatus() async {
    return await _permissionService.checkLocationPermission();
  }

  /// Check if location services are actually available
  Future<bool> isLocationActuallyEnabled() async {
    final status = await getLocationPermissionStatus();
    return status == PermissionStatus.granted && _locationEnabled;
  }

  Future<void> clearAllData() async {
    await _prefs.clear();
    
    // Reset to defaults
    _locationEnabled = true;
    _autoBlockSuspicious = false; // CRITICAL FIX: Default to disabled
    _notificationsEnabled = true;
    _networkHistoryDays = 30;
    _showVerifiedNetworks = false;
    _storageUsedMB = 0.0;
    
    await _calculateStorageUsage();
    notifyListeners();
  }
  
  /// Calculate storage usage from app data
  Future<void> _calculateStorageUsage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final size = await _calculateDirectorySize(directory);
      _storageUsedMB = size / (1024 * 1024); // Convert bytes to MB
      developer.log('Storage usage calculated: ${_storageUsedMB.toStringAsFixed(1)} MB');
      notifyListeners();
    } catch (e) {
      developer.log('Error calculating storage usage: $e');
      _storageUsedMB = 0.0;
    }
  }
  
  /// Calculate size of directory recursively
  Future<int> _calculateDirectorySize(Directory directory) async {
    int totalSize = 0;
    try {
      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) {
            try {
              final size = await entity.length();
              totalSize += size;
            } catch (e) {
              developer.log('Error getting file size for ${entity.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      developer.log('Error calculating directory size: $e');
    }
    return totalSize;
  }
  
  /// Refresh storage usage calculation
  Future<void> refreshStorageUsage() async {
    await _calculateStorageUsage();
  }
  
  
  /// Apply auto-block setting to new networks
  Future<void> applyAutoBlockToNetwork(NetworkModel network) async {
    developer.log('🔍 AUTO-BLOCK CHECK: Setting enabled: $_autoBlockSuspicious, Network: ${network.name}, Status: ${network.status.name}');
    
    if (_autoBlockSuspicious && 
        network.status == NetworkStatus.suspicious && 
        _networkProvider != null) {
      await _networkProvider!.blockNetwork(network.id);
      developer.log('🚫 AUTO-BLOCKED suspicious network: ${network.name} (MAC: ${network.macAddress})');
      
      // Generate special alert for auto-blocked network
      if (_alertProvider != null) {
        _alertProvider!.generateAutoBlockAlert(network, scanSessionId: _networkProvider?.currentScanSessionId);
        developer.log('🚨 Auto-block alert generated for: ${network.name}');
      } else {
        developer.log('⚠️ AlertProvider not available for auto-block alert generation');
      }
    } else if (!_autoBlockSuspicious) {
      developer.log('ℹ️ Auto-block disabled - skipping network: ${network.name}');
    }
  }
}