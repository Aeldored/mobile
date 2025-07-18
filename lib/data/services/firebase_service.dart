import 'dart:developer' as developer;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import '../models/network_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  late FirebaseFirestore _firestore;
  late FirebaseAnalytics _analytics;
  late FirebasePerformance _performance;
  
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _firestore = FirebaseFirestore.instance;
      _analytics = FirebaseAnalytics.instance;
      _performance = FirebasePerformance.instance;
      
      // Enable offline persistence
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      _initialized = true;
    } catch (e) {
      developer.log('Firebase service initialization error: $e');
      rethrow;
    }
  }

  // Fetch current whitelist from Firebase
  Future<WhitelistData?> fetchCurrentWhitelist() async {
    final trace = _performance.newTrace('whitelist_fetch');
    await trace.start();
    
    try {
      // Get whitelist metadata
      final metadataDoc = await _firestore
          .collection('whitelists')
          .doc('current')
          .get();
      
      if (!metadataDoc.exists) {
        developer.log('No whitelist metadata found');
        await trace.stop();
        return null;
      }
      
      final metadata = metadataDoc.data()!;
      
      // Fetch whitelist data directly from Firestore
      // Primary method: Get from whitelist_data collection (optimized for large datasets)
      try {
        final whitelistSnapshot = await _firestore
            .collection('whitelist_data')
            .orderBy('createdAt', descending: false)
            .limit(5000) // Process in chunks to stay within free tier limits
            .get();
        
        final accessPoints = <AccessPointData>[];
        
        for (final doc in whitelistSnapshot.docs) {
          final data = doc.data();
          
          // Each document can contain multiple access points to optimize reads
          final apList = data['accessPoints'] as List? ?? [];
          for (final apData in apList) {
            accessPoints.add(AccessPointData.fromJson(apData));
          }
        }
        
        trace.setMetric('access_points_count', accessPoints.length);
        await trace.stop();
        
        return WhitelistData(
          version: metadata['version'] ?? '1.0.0',
          lastUpdated: (metadata['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
          accessPoints: accessPoints,
          checksum: metadata['checksum'] ?? '',
        );
      } catch (e) {
        // Fallback to individual access_points collection
        developer.log('Whitelist data fetch failed, falling back to individual documents: $e');
        
        final apSnapshot = await _firestore
            .collection('access_points')
            .where('status', isEqualTo: 'active')
            .limit(1000)
            .get();
        
        final accessPoints = apSnapshot.docs
            .map((doc) => AccessPointData.fromFirestore(doc.id, doc.data()))
            .toList();
        
        trace.setMetric('access_points_count', accessPoints.length);
        await trace.stop();
        
        return WhitelistData(
          version: metadata['version'] ?? '1.0.0',
          lastUpdated: (metadata['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
          accessPoints: accessPoints,
          checksum: metadata['checksum'] ?? '',
        );
      }
    } catch (e) {
      await trace.stop();
      developer.log('Error fetching whitelist: $e');
      
      // Log error to analytics
      await _analytics.logEvent(
        name: 'whitelist_fetch_error',
        parameters: {'error': e.toString()},
      );
      
      return null;
    }
  }

  // Real-time whitelist updates
  Stream<WhitelistMetadata> whitelistUpdates() {
    return _firestore
        .collection('whitelists')
        .doc('current')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return WhitelistMetadata(
              version: 'unknown',
              lastUpdated: DateTime.now(),
              status: 'error',
              totalAccessPoints: 0,
            );
          }
          
          final data = snapshot.data()!;
          return WhitelistMetadata(
            version: data['version'] ?? 'unknown',
            lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
            status: data['status'] ?? 'unknown',
            totalAccessPoints: data['metadata']?['totalAccessPoints'] ?? 0,
          );
        });
  }

  // Get access points near location
  Future<List<AccessPointData>> fetchNearbyAccessPoints(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    try {
      // For simplicity, fetch all active APs and filter by distance
      // In production, use GeoFirestore for efficient geo queries
      final snapshot = await _firestore
          .collection('access_points')
          .where('status', isEqualTo: 'active')
          .get();
      
      final accessPoints = <AccessPointData>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final geoPoint = data['location'] as GeoPoint?;
        
        if (geoPoint != null) {
          final distance = _calculateDistance(
            latitude, longitude,
            geoPoint.latitude, geoPoint.longitude,
          );
          
          if (distance <= radiusKm) {
            accessPoints.add(AccessPointData.fromFirestore(doc.id, data));
          }
        }
      }
      
      // Sort by distance
      accessPoints.sort((a, b) {
        final distA = _calculateDistance(latitude, longitude, a.latitude, a.longitude);
        final distB = _calculateDistance(latitude, longitude, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });
      
      return accessPoints;
    } catch (e) {
      developer.log('Error fetching nearby access points: $e');
      return [];
    }
  }

  // Submit threat report
  Future<void> submitThreatReport({
    required NetworkModel network,
    required double latitude,
    required double longitude,
    required String deviceId,
    String? additionalInfo,
  }) async {
    try {
      await _firestore.collection('threat_reports').add({
        'network': {
          'ssid': network.name,
          'macAddress': network.macAddress,
          'signalStrength': network.signalStrength,
          'securityType': network.securityType,
        },
        'location': GeoPoint(latitude, longitude),
        'deviceId': deviceId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'additionalInfo': additionalInfo,
      });
      
      // Log analytics event
      await _analytics.logEvent(
        name: 'threat_reported',
        parameters: {
          'network_type': network.isSuspicious ? 'suspicious' : 'unknown',
          'signal_strength': network.signalStrength,
        },
      );
    } catch (e) {
      developer.log('Error submitting threat report: $e');
      rethrow;
    }
  }

  // Upload whitelist data (Admin only - for DICT backend use)
  Future<void> uploadWhitelistData({
    required List<AccessPointData> accessPoints,
    required String version,
    required String checksum,
  }) async {
    try {
      // Update metadata
      await _firestore.collection('whitelists').doc('current').set({
        'version': version,
        'lastUpdated': FieldValue.serverTimestamp(),
        'checksum': checksum,
        'status': 'active',
        'metadata': {
          'totalAccessPoints': accessPoints.length,
          'uploadMethod': 'firestore_direct',
        },
      });

      // Clear existing whitelist data
      final existingDocs = await _firestore
          .collection('whitelist_data')
          .get();
      
      final batch = _firestore.batch();
      for (final doc in existingDocs.docs) {
        batch.delete(doc.reference);
      }
      
      // Upload in chunks to optimize Firestore operations
      const chunkSize = 100; // Access points per document
      final chunks = <List<AccessPointData>>[];
      
      for (int i = 0; i < accessPoints.length; i += chunkSize) {
        final end = (i + chunkSize < accessPoints.length) 
            ? i + chunkSize 
            : accessPoints.length;
        chunks.add(accessPoints.sublist(i, end));
      }
      
      // Upload each chunk as a separate document
      for (int i = 0; i < chunks.length; i++) {
        final chunkData = chunks[i].map((ap) => {
          'id': ap.id,
          'ssid': ap.ssid,
          'macAddress': ap.macAddress,
          'location': {
            'latitude': ap.latitude,
            'longitude': ap.longitude,
          },
          'region': ap.region,
          'province': ap.province,
          'city': ap.city,
          'signalStrength': ap.signalStrength,
          'type': ap.type,
          'status': ap.status,
        }).toList();
        
        batch.set(
          _firestore.collection('whitelist_data').doc('chunk_$i'),
          {
            'accessPoints': chunkData,
            'chunkIndex': i,
            'totalChunks': chunks.length,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }
      
      await batch.commit();
      
      // Log successful upload
      await _analytics.logEvent(
        name: 'whitelist_uploaded',
        parameters: {
          'access_points_count': accessPoints.length,
          'chunks_count': chunks.length,
          'version': version,
        },
      );
      
      developer.log('Whitelist uploaded successfully: ${accessPoints.length} access points in ${chunks.length} chunks');
    } catch (e) {
      developer.log('Error uploading whitelist: $e');
      rethrow;
    }
  }

  // Get app configuration
  Future<AppConfig> fetchAppConfig() async {
    try {
      final doc = await _firestore
          .collection('app_config')
          .doc('settings')
          .get();
      
      if (!doc.exists) {
        return AppConfig.defaults();
      }
      
      return AppConfig.fromMap(doc.data()!);
    } catch (e) {
      developer.log('Error fetching app config: $e');
      return AppConfig.defaults();
    }
  }

  // Log general event
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      developer.log('Error logging event: $e');
    }
  }

  // Log scan event
  Future<void> logScan({
    required int networksFound,
    required int threatsDetected,
    required String scanType,
  }) async {
    await _analytics.logEvent(
      name: 'network_scan_completed',
      parameters: {
        'networks_found': networksFound,
        'threats_detected': threatsDetected,
        'scan_type': scanType,
      },
    );
    
    // Update daily stats
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    try {
      await _firestore
          .collection('analytics')
          .doc('daily_stats')
          .collection(dateKey)
          .doc('summary')
          .set({
        'totalScans': FieldValue.increment(1),
        'threatsDetected': FieldValue.increment(threatsDetected),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log('Error updating daily stats: $e');
    }
  }

  // Helper: Calculate distance between coordinates
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;
}

// Data Models
class WhitelistData {
  final String version;
  final DateTime lastUpdated;
  final List<AccessPointData> accessPoints;
  final String checksum;

  WhitelistData({
    required this.version,
    required this.lastUpdated,
    required this.accessPoints,
    required this.checksum,
  });
}

class WhitelistMetadata {
  final String version;
  final DateTime lastUpdated;
  final String status;
  final int totalAccessPoints;

  WhitelistMetadata({
    required this.version,
    required this.lastUpdated,
    required this.status,
    required this.totalAccessPoints,
  });
}

class AccessPointData {
  final String id;
  final String ssid;
  final String macAddress;
  final double latitude;
  final double longitude;
  final String region;
  final String province;
  final String city;
  final Map<String, dynamic> signalStrength;
  final String type;
  final String status;

  AccessPointData({
    required this.id,
    required this.ssid,
    required this.macAddress,
    required this.latitude,
    required this.longitude,
    required this.region,
    required this.province,
    required this.city,
    required this.signalStrength,
    required this.type,
    required this.status,
  });

  factory AccessPointData.fromJson(Map<String, dynamic> json) {
    return AccessPointData(
      id: json['macAddress'] ?? '',
      ssid: json['ssid'] ?? '',
      macAddress: json['macAddress'] ?? '',
      latitude: (json['location']?['latitude'] ?? 0).toDouble(),
      longitude: (json['location']?['longitude'] ?? 0).toDouble(),
      region: json['region'] ?? '',
      province: json['province'] ?? '',
      city: json['city'] ?? '',
      signalStrength: json['signalStrength'] ?? {},
      type: json['type'] ?? 'unknown',
      status: json['status'] ?? 'unknown',
    );
  }

  factory AccessPointData.fromFirestore(String id, Map<String, dynamic> data) {
    final location = data['location'] as GeoPoint?;
    return AccessPointData(
      id: id,
      ssid: data['ssid'] ?? '',
      macAddress: data['macAddress'] ?? '',
      latitude: location?.latitude ?? 0,
      longitude: location?.longitude ?? 0,
      region: data['region'] ?? '',
      province: data['province'] ?? '',
      city: data['city'] ?? '',
      signalStrength: data['signalStrength'] ?? {},
      type: data['type'] ?? 'unknown',
      status: data['status'] ?? 'unknown',
    );
  }
}

class AppConfig {
  final String minAppVersion;
  final bool forceUpdate;
  final bool maintenanceMode;
  final int syncInterval;
  final Map<String, bool> features;

  AppConfig({
    required this.minAppVersion,
    required this.forceUpdate,
    required this.maintenanceMode,
    required this.syncInterval,
    required this.features,
  });

  factory AppConfig.fromMap(Map<String, dynamic> data) {
    return AppConfig(
      minAppVersion: data['minAppVersion'] ?? '1.0.0',
      forceUpdate: data['forceUpdate'] ?? false,
      maintenanceMode: data['maintenanceMode'] ?? false,
      syncInterval: data['syncInterval'] ?? 3600,
      features: Map<String, bool>.from(data['features'] ?? {
        'scanEnabled': true,
        'reportingEnabled': true,
        'educationEnabled': true,
      }),
    );
  }

  factory AppConfig.defaults() {
    return AppConfig(
      minAppVersion: '1.0.0',
      forceUpdate: false,
      maintenanceMode: false,
      syncInterval: 3600,
      features: {
        'scanEnabled': true,
        'reportingEnabled': true,
        'educationEnabled': true,
      },
    );
  }
}