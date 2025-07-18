import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/network_model.dart';
import 'firebase_service.dart';

class AccessPointService {
  static final AccessPointService _instance = AccessPointService._internal();
  factory AccessPointService() => _instance;
  AccessPointService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  SharedPreferences? _prefs;

  // Storage keys
  static const String _blockedApsKey = 'blocked_access_points';
  static const String _trustedApsKey = 'trusted_access_points';
  static const String _flaggedApsKey = 'flagged_access_points';

  /// Initialize the service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Block an access point
  Future<void> blockAccessPoint(NetworkModel network) async {
    await _updateAccessPointStatus(network, NetworkStatus.blocked, _blockedApsKey);
    
    // Log to Firebase Analytics
    try {
      await _firebaseService.logEvent(
        name: 'access_point_blocked',
        parameters: {
          'ssid': network.name,
          'mac_address': network.macAddress,
          'city': network.cityName ?? 'unknown',
        },
      );
    } catch (e) {
      developer.log('Failed to log block event: $e');
    }
  }

  /// Trust an access point
  Future<void> trustAccessPoint(NetworkModel network) async {
    await _updateAccessPointStatus(network, NetworkStatus.trusted, _trustedApsKey);
    
    // Log to Firebase Analytics
    try {
      await _firebaseService.logEvent(
        name: 'access_point_trusted',
        parameters: {
          'ssid': network.name,
          'mac_address': network.macAddress,
          'city': network.cityName ?? 'unknown',
        },
      );
    } catch (e) {
      developer.log('Failed to log trust event: $e');
    }
  }

  /// Flag an access point as suspicious
  Future<void> flagAccessPoint(NetworkModel network, {String? reason}) async {
    await _updateAccessPointStatus(network, NetworkStatus.flagged, _flaggedApsKey);
    
    // Submit threat report to Firebase
    try {
      await _firebaseService.submitThreatReport(
        network: network,
        latitude: network.latitude ?? 14.0,
        longitude: network.longitude ?? 121.0,
        deviceId: 'user_device', // Should get actual device ID
        additionalInfo: reason ?? 'User flagged as suspicious',
      );
    } catch (e) {
      developer.log('Failed to submit threat report: $e');
    }
  }

  /// Remove access point from blocked list
  Future<void> unblockAccessPoint(NetworkModel network) async {
    await _removeAccessPointFromList(network, _blockedApsKey);
  }

  /// Remove access point from trusted list
  Future<void> untrustAccessPoint(NetworkModel network) async {
    await _removeAccessPointFromList(network, _trustedApsKey);
  }

  /// Remove access point from flagged list
  Future<void> unflagAccessPoint(NetworkModel network) async {
    await _removeAccessPointFromList(network, _flaggedApsKey);
  }

  /// Get all blocked access points
  Future<List<NetworkModel>> getBlockedAccessPoints() async {
    return await _getAccessPointsList(_blockedApsKey);
  }

  /// Get all trusted access points
  Future<List<NetworkModel>> getTrustedAccessPoints() async {
    return await _getAccessPointsList(_trustedApsKey);
  }

  /// Get all flagged access points
  Future<List<NetworkModel>> getFlaggedAccessPoints() async {
    return await _getAccessPointsList(_flaggedApsKey);
  }

  /// Check if an access point is blocked
  Future<bool> isAccessPointBlocked(String macAddress) async {
    final blockedAps = await getBlockedAccessPoints();
    return blockedAps.any((ap) => ap.macAddress == macAddress);
  }

  /// Check if an access point is trusted
  Future<bool> isAccessPointTrusted(String macAddress) async {
    final trustedAps = await getTrustedAccessPoints();
    return trustedAps.any((ap) => ap.macAddress == macAddress);
  }

  /// Check if an access point is flagged
  Future<bool> isAccessPointFlagged(String macAddress) async {
    final flaggedAps = await getFlaggedAccessPoints();
    return flaggedAps.any((ap) => ap.macAddress == macAddress);
  }

  /// Get access point status
  Future<NetworkStatus?> getAccessPointStatus(String macAddress) async {
    if (await isAccessPointBlocked(macAddress)) return NetworkStatus.blocked;
    if (await isAccessPointTrusted(macAddress)) return NetworkStatus.trusted;
    if (await isAccessPointFlagged(macAddress)) return NetworkStatus.flagged;
    return null;
  }

  /// Clear all user-managed access points
  Future<void> clearAllManagedAccessPoints() async {
    await _prefs?.remove(_blockedApsKey);
    await _prefs?.remove(_trustedApsKey);
    await _prefs?.remove(_flaggedApsKey);
  }

  /// Export access point data (for backup/sync)
  Future<Map<String, dynamic>> exportAccessPointData() async {
    return {
      'blocked': (await getBlockedAccessPoints()).map((ap) => ap.toJson()).toList(),
      'trusted': (await getTrustedAccessPoints()).map((ap) => ap.toJson()).toList(),
      'flagged': (await getFlaggedAccessPoints()).map((ap) => ap.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  /// Import access point data (for restore/sync)
  Future<void> importAccessPointData(Map<String, dynamic> data) async {
    try {
      // Import blocked APs
      if (data['blocked'] != null) {
        final blocked = (data['blocked'] as List)
            .map((json) => NetworkModel.fromJson(json))
            .toList();
        await _saveAccessPointsList(blocked, _blockedApsKey);
      }

      // Import trusted APs
      if (data['trusted'] != null) {
        final trusted = (data['trusted'] as List)
            .map((json) => NetworkModel.fromJson(json))
            .toList();
        await _saveAccessPointsList(trusted, _trustedApsKey);
      }

      // Import flagged APs
      if (data['flagged'] != null) {
        final flagged = (data['flagged'] as List)
            .map((json) => NetworkModel.fromJson(json))
            .toList();
        await _saveAccessPointsList(flagged, _flaggedApsKey);
      }
    } catch (e) {
      developer.log('Error importing access point data: $e');
      rethrow;
    }
  }

  /// Get access point management statistics
  Future<Map<String, int>> getAccessPointStats() async {
    final blocked = await getBlockedAccessPoints();
    final trusted = await getTrustedAccessPoints();
    final flagged = await getFlaggedAccessPoints();

    return {
      'blocked': blocked.length,
      'trusted': trusted.length,
      'flagged': flagged.length,
      'total': blocked.length + trusted.length + flagged.length,
    };
  }

  // Private helper methods

  Future<void> _updateAccessPointStatus(
    NetworkModel network,
    NetworkStatus status,
    String storageKey,
  ) async {
    await initialize();
    
    final updatedNetwork = network.copyWith(
      status: status,
      isUserManaged: true,
      lastActionDate: DateTime.now(),
    );

    final currentList = await _getAccessPointsList(storageKey);
    
    // Remove existing entry if present
    currentList.removeWhere((ap) => ap.macAddress == network.macAddress);
    
    // Add updated entry
    currentList.add(updatedNetwork);

    await _saveAccessPointsList(currentList, storageKey);

    // Also remove from other lists to avoid conflicts
    if (storageKey != _blockedApsKey) {
      await _removeAccessPointFromList(network, _blockedApsKey);
    }
    if (storageKey != _trustedApsKey) {
      await _removeAccessPointFromList(network, _trustedApsKey);
    }
    if (storageKey != _flaggedApsKey) {
      await _removeAccessPointFromList(network, _flaggedApsKey);
    }
  }

  Future<void> _removeAccessPointFromList(NetworkModel network, String storageKey) async {
    await initialize();
    
    final currentList = await _getAccessPointsList(storageKey);
    currentList.removeWhere((ap) => ap.macAddress == network.macAddress);
    await _saveAccessPointsList(currentList, storageKey);
  }

  Future<List<NetworkModel>> _getAccessPointsList(String storageKey) async {
    await initialize();
    
    final jsonString = _prefs?.getString(storageKey);
    if (jsonString == null) return [];

    try {
      final jsonList = json.decode(jsonString) as List;
      return jsonList.map((json) => NetworkModel.fromJson(json)).toList();
    } catch (e) {
      developer.log('Error decoding access points from $storageKey: $e');
      return [];
    }
  }

  Future<void> _saveAccessPointsList(List<NetworkModel> accessPoints, String storageKey) async {
    await initialize();
    
    try {
      final jsonList = accessPoints.map((ap) => ap.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _prefs?.setString(storageKey, jsonString);
    } catch (e) {
      developer.log('Error saving access points to $storageKey: $e');
      rethrow;
    }
  }
}