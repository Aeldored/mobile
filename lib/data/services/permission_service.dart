import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wifi_scan/wifi_scan.dart';

/// Centralized permission management service for DisConX
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Check all required permissions for full app functionality
  Future<PermissionStatus> checkAllPermissions() async {
    try {
      final locationStatus = await checkLocationPermission();
      final wifiStatus = await checkWifiPermissions();
      
      if (locationStatus == PermissionStatus.granted && 
          wifiStatus == PermissionStatus.granted) {
        return PermissionStatus.granted;
      } else if (locationStatus == PermissionStatus.denied || 
                 wifiStatus == PermissionStatus.denied) {
        return PermissionStatus.denied;
      } else {
        return PermissionStatus.permanentlyDenied;
      }
    } catch (e) {
      developer.log('Error checking permissions: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check location permission status
  Future<PermissionStatus> checkLocationPermission() async {
    try {
      final geolocatorPermission = await Geolocator.checkPermission();
      
      switch (geolocatorPermission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return PermissionStatus.granted;
        case LocationPermission.denied:
          return PermissionStatus.denied;
        case LocationPermission.deniedForever:
          return PermissionStatus.permanentlyDenied;
        case LocationPermission.unableToDetermine:
          return PermissionStatus.denied;
      }
    } catch (e) {
      developer.log('Error checking location permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check Wi-Fi related permissions
  Future<PermissionStatus> checkWifiPermissions() async {
    try {
      // Check if device supports Wi-Fi scanning
      final canScan = await WiFiScan.instance.canGetScannedResults();
      if (canScan != CanGetScannedResults.yes) {
        developer.log('Wi-Fi scanning not supported: $canScan');
        return PermissionStatus.denied;
      }

      // Check nearby Wi-Fi devices permission (Android 13+)
      final nearbyWifiStatus = await Permission.nearbyWifiDevices.status;
      return nearbyWifiStatus;
    } catch (e) {
      developer.log('Error checking Wi-Fi permissions: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request all required permissions
  Future<Map<String, PermissionStatus>> requestAllPermissions() async {
    final results = <String, PermissionStatus>{};
    
    try {
      // Request location permission
      results['location'] = await requestLocationPermission();
      
      // Request Wi-Fi related permissions
      results['wifi'] = await requestWifiPermissions();
      
      developer.log('Permission request results: $results');
      return results;
    } catch (e) {
      developer.log('Error requesting permissions: $e');
      results['error'] = PermissionStatus.denied;
      return results;
    }
  }

  /// Request location permission with proper lifecycle handling
  Future<PermissionStatus> requestLocationPermission() async {
    try {
      final currentStatus = await Geolocator.checkPermission();
      developer.log('Current location permission status: $currentStatus');
      
      if (currentStatus == LocationPermission.denied) {
        developer.log('Requesting location permission...');
        final requestResult = await Geolocator.requestPermission();
        developer.log('Location permission request result: $requestResult');
        
        switch (requestResult) {
          case LocationPermission.always:
          case LocationPermission.whileInUse:
            developer.log('Location permission granted');
            return PermissionStatus.granted;
          case LocationPermission.denied:
            developer.log('Location permission denied by user');
            return PermissionStatus.denied;
          case LocationPermission.deniedForever:
            developer.log('Location permission permanently denied');
            return PermissionStatus.permanentlyDenied;
          case LocationPermission.unableToDetermine:
            developer.log('Location permission unable to determine');
            return PermissionStatus.denied;
        }
      } else if (currentStatus == LocationPermission.deniedForever) {
        developer.log('Location permission was permanently denied');
        return PermissionStatus.permanentlyDenied;
      } else {
        developer.log('Location permission already granted');
        return PermissionStatus.granted;
      }
    } catch (e) {
      developer.log('Error requesting location permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request Wi-Fi related permissions with proper lifecycle handling  
  Future<PermissionStatus> requestWifiPermissions() async {
    try {
      final currentStatus = await Permission.nearbyWifiDevices.status;
      developer.log('Current Wi-Fi permission status: $currentStatus');
      
      if (currentStatus.isDenied) {
        developer.log('Requesting Wi-Fi permissions...');
        final requestResult = await Permission.nearbyWifiDevices.request();
        developer.log('Wi-Fi permission request result: $requestResult');
        return requestResult;
      } else {
        developer.log('Wi-Fi permission already resolved: $currentStatus');
        return currentStatus;
      }
    } catch (e) {
      developer.log('Error requesting Wi-Fi permissions: $e');
      return PermissionStatus.denied;
    }
  }

  /// Show permission rationale dialog
  Future<bool> showPermissionRationale(
    BuildContext context, 
    String permissionType,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getPermissionIcon(permissionType),
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Permission Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getPermissionRationale(permissionType)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This permission is essential for DisConX to protect you from network threats.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Show settings dialog for permanently denied permissions
  Future<bool> showSettingsDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Settings Required'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DisConX needs location and Wi-Fi permissions to function properly. '
              'Please enable these permissions in your device settings.',
            ),
            SizedBox(height: 12),
            Text(
              'Go to: Settings > Apps > DisConX > Permissions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Get appropriate icon for permission type
  IconData _getPermissionIcon(String permissionType) {
    switch (permissionType.toLowerCase()) {
      case 'location':
        return Icons.location_on;
      case 'wifi':
        return Icons.wifi;
      default:
        return Icons.security;
    }
  }

  /// Get permission rationale text
  String _getPermissionRationale(String permissionType) {
    switch (permissionType.toLowerCase()) {
      case 'location':
        return 'DisConX needs location access to scan for nearby Wi-Fi networks and verify their authenticity against known safe locations.';
      case 'wifi':
        return 'DisConX needs Wi-Fi access to scan for available networks and detect potential security threats like evil twin attacks.';
      default:
        return 'This permission is required for DisConX to function properly and protect you from network security threats.';
    }
  }

  /// Check if permission should show rationale
  Future<bool> shouldShowRequestPermissionRationale(String permissionType) async {
    switch (permissionType.toLowerCase()) {
      case 'location':
        final status = await checkLocationPermission();
        return status == PermissionStatus.denied;
      case 'wifi':
        final status = await Permission.nearbyWifiDevices.status;
        return status == PermissionStatus.denied;
      default:
        return false;
    }
  }

  /// Get user-friendly permission status message
  String getPermissionStatusMessage(PermissionStatus status) {
    switch (status) {
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
      case PermissionStatus.provisional:
        return 'Provisional';
    }
  }
}