import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/network_model.dart';

/// Service for tracking mobile app connections to whitelisted networks
/// This provides real-time activity data for the web admin dashboard
class NetworkActivityTracker {
  static final NetworkActivityTracker _instance = NetworkActivityTracker._internal();
  factory NetworkActivityTracker() => _instance;
  NetworkActivityTracker._internal();

  FirebaseFirestore? _firestore;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Uuid _uuid = const Uuid();
  
  String? _currentActivityDocId;
  Timer? _heartbeatTimer;
  String? _anonymousDeviceId;
  bool _trackingEnabled = true;
  
  // Offline queue for when network is unavailable
  final List<Map<String, dynamic>> _offlineQueue = [];

  /// Lazy getter for Firestore instance
  FirebaseFirestore get firestore {
    if (_firestore == null) {
      try {
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        developer.log('⚠️ Firebase not initialized yet, calls will be queued');
        rethrow;
      }
    }
    return _firestore!;
  }

  /// Initialize the activity tracker
  Future<void> initialize() async {
    try {
      // Initialize Firestore connection first
      _firestore = FirebaseFirestore.instance;
      
      await _initializeDeviceId();
      await _loadTrackingPreferences();
      await _processOfflineQueue();
      
      developer.log('📊 NetworkActivityTracker initialized successfully');
    } catch (e) {
      developer.log('❌ Failed to initialize NetworkActivityTracker: $e');
    }
  }

  /// Generate or retrieve anonymous device ID
  Future<void> _initializeDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _anonymousDeviceId = prefs.getString('anonymous_device_id');
    
    if (_anonymousDeviceId == null) {
      _anonymousDeviceId = _uuid.v4();
      await prefs.setString('anonymous_device_id', _anonymousDeviceId!);
      developer.log('🆔 Generated new anonymous device ID: $_anonymousDeviceId');
    } else {
      developer.log('🆔 Using existing anonymous device ID: $_anonymousDeviceId');
    }
  }

  /// Load user preferences for activity tracking
  Future<void> _loadTrackingPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _trackingEnabled = prefs.getBool('activity_tracking_enabled') ?? true;
    
    developer.log('⚙️ Activity tracking enabled: $_trackingEnabled');
  }

  /// Enable or disable activity tracking
  Future<void> setTrackingEnabled(bool enabled) async {
    _trackingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('activity_tracking_enabled', enabled);
    
    if (!enabled && _currentActivityDocId != null) {
      // If tracking is disabled, disconnect current session
      await trackDisconnection();
    }
    
    developer.log('⚙️ Activity tracking ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Check if a network is whitelisted (only track whitelisted networks)
  Future<bool> _isNetworkWhitelisted(String ssid) async {
    try {
      final whitelistQuery = await firestore
          .collection('access_points')
          .where('ssid', isEqualTo: ssid)
          .limit(1)
          .get();
      
      final isWhitelisted = whitelistQuery.docs.isNotEmpty;
      developer.log('🔍 Network $ssid whitelist status: $isWhitelisted');
      return isWhitelisted;
    } catch (e) {
      developer.log('⚠️ Error checking whitelist for $ssid: $e');
      return false;
    }
  }

  /// Get network document ID by SSID
  Future<String?> _getNetworkIdBySSID(String ssid) async {
    try {
      final networkQuery = await firestore
          .collection('access_points')
          .where('ssid', isEqualTo: ssid)
          .limit(1)
          .get();
      
      if (networkQuery.docs.isNotEmpty) {
        return networkQuery.docs.first.id;
      }
      
      developer.log('⚠️ Network ID not found for SSID: $ssid');
      return null;
    } catch (e) {
      developer.log('❌ Error getting network ID for $ssid: $e');
      return null;
    }
  }

  /// Get approximate location (rounded for privacy)
  Future<Map<String, dynamic>?> _getApproximateLocation() async {
    try {
      // Check location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        developer.log('📍 Location permission denied, skipping location data');
        return null;
      }
      
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.reduced, // Lower accuracy for privacy
          timeLimit: Duration(seconds: 10),
        ),
      );
      
      // Round coordinates to nearest ~100m for privacy protection
      final roundedLat = (position.latitude * 1000).round() / 1000; // ~111m precision
      final roundedLng = (position.longitude * 1000).round() / 1000; // ~111m precision
      
      return {
        'latitude': roundedLat,
        'longitude': roundedLng,
        'accuracy': position.accuracy,
        'province': await _getProvinceFromCoordinates(roundedLat, roundedLng),
      };
    } catch (e) {
      developer.log('📍 Could not get location: $e');
      return null;
    }
  }

  /// Get province from coordinates (simplified mapping)
  Future<String> _getProvinceFromCoordinates(double lat, double lng) async {
    // Simplified province detection for CALABARZON region
    if (lat >= 13.8 && lat <= 14.8 && lng >= 120.8 && lng <= 121.8) {
      if (lat >= 14.0 && lat <= 14.5 && lng >= 121.0 && lng <= 121.5) {
        return 'Laguna';
      } else if (lat >= 14.1 && lat <= 14.8 && lng >= 120.9 && lng <= 121.4) {
        return 'Rizal';
      } else if (lat >= 14.0 && lat <= 14.4 && lng >= 120.8 && lng <= 121.2) {
        return 'Cavite';
      } else if (lat >= 13.8 && lat <= 14.2 && lng >= 121.0 && lng <= 121.6) {
        return 'Batangas';
      } else if (lat >= 14.2 && lat <= 14.8 && lng >= 121.2 && lng <= 122.0) {
        return 'Quezon';
      }
    }
    return 'CALABARZON'; // Default for region
  }

  /// Get device information for tracking
  Future<String> _getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.model}';
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return '1.0.0';
    }
  }

  /// Assess connection quality based on signal strength
  String _assessConnectionQuality(int? signalStrength) {
    if (signalStrength == null) return 'unknown';
    
    if (signalStrength >= -30) return 'excellent';
    if (signalStrength >= -50) return 'good';
    if (signalStrength >= -70) return 'fair';
    return 'poor';
  }

  /// Track connection to a whitelisted network
  Future<void> trackConnection(NetworkModel network) async {
    if (!_trackingEnabled) {
      developer.log('📊 Activity tracking disabled, skipping connection tracking');
      return;
    }

    try {
      developer.log('🔍 Checking if network ${network.ssid} is whitelisted...');
      
      // Only track whitelisted networks
      if (!await _isNetworkWhitelisted(network.ssid)) {
        developer.log('⚠️ Network ${network.ssid} not whitelisted, skipping tracking');
        return;
      }
      
      developer.log('✅ Network ${network.ssid} is whitelisted, starting activity tracking');
      
      // Get network document ID
      final networkId = await _getNetworkIdBySSID(network.ssid);
      if (networkId == null) {
        developer.log('❌ Could not get network ID for ${network.ssid}');
        return;
      }
      
      // Get device and location information
      final deviceModel = await _getDeviceModel();
      final appVersion = await _getAppVersion();
      final location = await _getApproximateLocation();
      
      // Check if device activity document already exists
      final existingDoc = await _findDeviceActivityDocument();
      
      if (existingDoc != null) {
        // Update existing document with new connection
        await _updateExistingConnection(existingDoc, networkId, network, location);
      } else {
        // Create new device activity document
        await _createDeviceActivityDocument(networkId, network, deviceModel, appVersion, location);
      }
      
      // Start periodic heartbeat to show active usage
      _startHeartbeat();
      
    } catch (e) {
      developer.log('❌ Failed to track connection: $e');
    }
  }

  /// Track disconnection from network
  Future<void> trackDisconnection() async {
    if (_currentActivityDocId == null) return;
    
    try {
      developer.log('📊 Tracking disconnection for device: $_currentActivityDocId');
      
      final disconnectionData = {
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      try {
        // Get current device document to update specific network status
        final docSnapshot = await firestore.collection('device_activity')
            .doc(_currentActivityDocId!)
            .get();
            
        if (docSnapshot.exists) {
          final data = docSnapshot.data() as Map<String, dynamic>;
          final currentNetworkId = data['currentNetworkId'] as String?;
          
          if (currentNetworkId != null) {
            // Mark current network as inactive in the networks map
            disconnectionData['networks.$currentNetworkId.isCurrentlyActive'] = false;
            disconnectionData['currentNetworkId'] = FieldValue.delete();
          }
        }
        
        await firestore.collection('device_activity')
            .doc(_currentActivityDocId!)
            .update(disconnectionData);
        
        developer.log('✅ Disconnection tracked successfully');
      } catch (e) {
        // Add disconnection to offline queue
        disconnectionData['_activityDocId'] = _currentActivityDocId as Object;
        disconnectionData['_isUpdate'] = true;
        await _addToOfflineQueue(disconnectionData);
        
        developer.log('⚠️ Failed to track disconnection online, queued for later: $e');
      }
      
      // Stop heartbeat and clear current session
      _stopHeartbeat();
      _currentActivityDocId = null;
      
    } catch (e) {
      developer.log('❌ Failed to track disconnection: $e');
    }
  }

  /// Find existing device activity document
  Future<DocumentSnapshot?> _findDeviceActivityDocument() async {
    try {
      final query = await firestore
          .collection('device_activity')
          .where('deviceId', isEqualTo: _anonymousDeviceId!)
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty ? query.docs.first : null;
    } catch (e) {
      developer.log('⚠️ Error finding device activity document: $e');
      return null;
    }
  }

  /// Update existing device document with new connection
  Future<void> _updateExistingConnection(
    DocumentSnapshot existingDoc,
    String networkId,
    NetworkModel network,
    Map<String, dynamic>? location,
  ) async {
    try {
      final currentTime = FieldValue.serverTimestamp();
      final connectionKey = 'networks.$networkId';
      
      // Prepare connection data for this specific network
      final connectionData = {
        'networkSSID': network.ssid,
        'networkBSSID': network.bssid,
        'lastConnectedAt': currentTime,
        'lastActivity': currentTime,
        'isCurrentlyActive': true,
        'signalStrength': network.signalStrength,
        'connectionQuality': _assessConnectionQuality(network.signalStrength),
        'totalConnections': FieldValue.increment(1),
        'location': location,
      };
      
      // Update the document
      final updateData = {
        connectionKey: connectionData,
        'lastActivity': currentTime,
        'updatedAt': currentTime,
        'currentNetworkId': networkId,
        'isActive': true,
      };
      
      await firestore
          .collection('device_activity')
          .doc(existingDoc.id)
          .update(updateData);
      
      _currentActivityDocId = existingDoc.id;
      developer.log('📊 Updated existing device activity for ${network.ssid}');
      
    } catch (e) {
      developer.log('⚠️ Failed to update existing connection: $e');
      // Add to offline queue
      await _addToOfflineQueue({
        'type': 'update_connection',
        'networkId': networkId,
        'network': {
          'ssid': network.ssid,
          'bssid': network.bssid,
          'signalStrength': network.signalStrength,
        },
        'location': location,
      });
    }
  }

  /// Create new device activity document
  Future<void> _createDeviceActivityDocument(
    String networkId,
    NetworkModel network,
    String deviceModel,
    String appVersion,
    Map<String, dynamic>? location,
  ) async {
    try {
      final currentTime = FieldValue.serverTimestamp();
      
      // Create initial network connection data
      final networkData = {
        networkId: {
          'networkSSID': network.ssid,
          'networkBSSID': network.bssid,
          'firstConnectedAt': currentTime,
          'lastConnectedAt': currentTime,
          'lastActivity': currentTime,
          'isCurrentlyActive': true,
          'signalStrength': network.signalStrength,
          'connectionQuality': _assessConnectionQuality(network.signalStrength),
          'totalConnections': 1,
          'location': location,
        }
      };
      
      // Create device activity document
      final deviceActivityData = {
        'deviceId': _anonymousDeviceId!,
        'deviceModel': deviceModel,
        'appVersion': appVersion,
        'networks': networkData,
        'currentNetworkId': networkId,
        'isActive': true,
        'firstSeenAt': currentTime,
        'lastActivity': currentTime,
        'createdAt': currentTime,
        'updatedAt': currentTime,
        'source': 'mobile_app'
      };
      
      final docRef = await firestore
          .collection('device_activity')
          .add(deviceActivityData);
      
      _currentActivityDocId = docRef.id;
      developer.log('📊 Created new device activity document for ${network.ssid}');
      developer.log('📄 Device activity document ID: ${docRef.id}');
      
    } catch (e) {
      developer.log('⚠️ Failed to create device activity document: $e');
      // Add to offline queue
      await _addToOfflineQueue({
        'type': 'create_device_activity',
        'networkId': networkId,
        'network': {
          'ssid': network.ssid,
          'bssid': network.bssid,
          'signalStrength': network.signalStrength,
        },
        'deviceModel': deviceModel,
        'appVersion': appVersion,
        'location': location,
      });
    }
  }

  /// Send periodic heartbeat to show continued activity
  void _startHeartbeat() {
    _stopHeartbeat(); // Clear any existing timer
    
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (_currentActivityDocId != null && _trackingEnabled) {
        try {
          await firestore.collection('device_activity')
              .doc(_currentActivityDocId!)
              .update({
            'lastActivity': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          developer.log('💓 Activity heartbeat sent');
        } catch (e) {
          developer.log('⚠️ Heartbeat failed: $e');
          // Don't add heartbeats to offline queue to avoid spam
        }
      }
    });
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Add activity data to offline queue
  Future<void> _addToOfflineQueue(Map<String, dynamic> activityData) async {
    _offlineQueue.add(activityData);
    
    // Save queue to persistent storage
    final prefs = await SharedPreferences.getInstance();
    final queueJson = _offlineQueue.map((item) => item.toString()).toList();
    await prefs.setStringList('offline_activity_queue', queueJson);
    
    developer.log('📦 Added activity to offline queue (${_offlineQueue.length} items)');
  }

  /// Process offline queue when network becomes available
  Future<void> _processOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    
    try {
      developer.log('🔄 Processing offline activity queue (${_offlineQueue.length} items)');
      
      final batch = firestore.batch();
      final toRemove = <Map<String, dynamic>>[];
      int processedCount = 0;
      
      for (final queuedData in _offlineQueue) {
        try {
          if (queuedData.containsKey('_isUpdate') && queuedData['_activityDocId'] != null) {
            // This is an update operation (disconnection)
            final docRef = firestore.collection('network_activity').doc(queuedData['_activityDocId']);
            final updateData = Map<String, dynamic>.from(queuedData);
            updateData.remove('_isUpdate');
            updateData.remove('_activityDocId');
            
            batch.update(docRef, updateData);
          } else {
            // This is a create operation (new connection)
            final docRef = firestore.collection('network_activity').doc();
            batch.set(docRef, queuedData);
          }
          
          toRemove.add(queuedData);
          processedCount++;
          
          // Process in smaller batches to avoid Firestore limits
          if (processedCount >= 400) break;
          
        } catch (e) {
          developer.log('⚠️ Failed to process queued item: $e');
          break; // Stop processing to avoid corrupting the batch
        }
      }
      
      if (toRemove.isNotEmpty) {
        await batch.commit();
        
        // Remove processed items from queue
        for (final item in toRemove) {
          _offlineQueue.remove(item);
        }
        
        // Update persistent storage
        final prefs = await SharedPreferences.getInstance();
        final queueJson = _offlineQueue.map((item) => item.toString()).toList();
        await prefs.setStringList('offline_activity_queue', queueJson);
        
        developer.log('✅ Processed $processedCount queued activity records');
      }
      
    } catch (e) {
      developer.log('❌ Failed to process offline queue: $e');
    }
  }

  /// Get current activity statistics for debugging
  Future<Map<String, dynamic>> getActivityStats() async {
    try {
      // Count total activities created by this device
      final myActivitiesQuery = await firestore
          .collection('network_activity')
          .where('deviceId', isEqualTo: _anonymousDeviceId)
          .get();
      
      final totalActivities = myActivitiesQuery.docs.length;
      
      // Count currently active sessions
      final activeActivitiesQuery = await firestore
          .collection('network_activity')
          .where('deviceId', isEqualTo: _anonymousDeviceId)
          .where('isActive', isEqualTo: true)
          .get();
      
      final activeActivities = activeActivitiesQuery.docs.length;
      
      return {
        'deviceId': _anonymousDeviceId,
        'trackingEnabled': _trackingEnabled,
        'totalActivities': totalActivities,
        'activeActivities': activeActivities,
        'currentSessionId': _currentActivityDocId,
        'queuedItems': _offlineQueue.length,
        'isHeartbeatActive': _heartbeatTimer?.isActive ?? false,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'deviceId': _anonymousDeviceId,
        'trackingEnabled': _trackingEnabled,
      };
    }
  }

  /// Cleanup method for app shutdown
  Future<void> cleanup() async {
    developer.log('🧹 Cleaning up NetworkActivityTracker...');
    
    // Track disconnection if currently connected
    if (_currentActivityDocId != null) {
      await trackDisconnection();
    }
    
    // Stop heartbeat
    _stopHeartbeat();
    
    // Process any remaining offline queue
    await _processOfflineQueue();
    
    developer.log('✅ NetworkActivityTracker cleanup completed');
  }

  /// Force sync offline data (useful for testing)
  Future<bool> forceSyncOfflineData() async {
    try {
      await _processOfflineQueue();
      return true;
    } catch (e) {
      developer.log('❌ Force sync failed: $e');
      return false;
    }
  }
}