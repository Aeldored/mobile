import 'dart:developer' as developer;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_core/firebase_core.dart';
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
    developer.log('🔥 FIREBASE SERVICE: initialize() called, _initialized: $_initialized');
    if (_initialized) {
      developer.log('🔥 FIREBASE SERVICE: Already initialized, skipping');
      return;
    }
    
    try {
      // Ensure Firebase Core is initialized first
      if (Firebase.apps.isEmpty) {
        developer.log('🔥 FIREBASE SERVICE: Firebase Core not initialized, initializing...');
        await Firebase.initializeApp();
        developer.log('🔥 FIREBASE SERVICE: Firebase Core initialized');
      }
      
      developer.log('🔥 FIREBASE SERVICE: Getting Firestore instance...');
      _firestore = FirebaseFirestore.instance;
      developer.log('🔥 FIREBASE SERVICE: Getting Analytics instance...');
      _analytics = FirebaseAnalytics.instance;
      developer.log('🔥 FIREBASE SERVICE: Getting Performance instance...');
      _performance = FirebasePerformance.instance;
      
      developer.log('🔥 FIREBASE SERVICE: Configuring Firestore settings...');
      // Enable offline persistence
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      _initialized = true;
      developer.log('✅ FIREBASE SERVICE: Initialization completed successfully');
    } catch (e) {
      developer.log('❌ Firebase service initialization error: $e');
      developer.log('❌ Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  // Fetch current whitelist from Firebase
  Future<WhitelistData?> fetchCurrentWhitelist() async {
    // Ensure Firebase is initialized before using _firestore
    if (!_initialized) {
      developer.log('🔧 Firebase not initialized, initializing now...');
      await initialize();
    }
    
    final trace = _performance.newTrace('whitelist_fetch');
    await trace.start();
    
    try {
      developer.log('🔍 Attempting to fetch whitelist data from Firestore...');
      
      // Try to get whitelist metadata (optional)
      Map<String, dynamic>? metadata;
      try {
        final metadataDoc = await _firestore
            .collection('whitelists')
            .doc('current')
            .get();
        
        if (metadataDoc.exists) {
          metadata = metadataDoc.data()!;
          developer.log('✅ Found whitelist metadata');
        } else {
          developer.log('⚠️ No whitelist metadata found, using defaults');
        }
      } catch (e) {
        developer.log('⚠️ Failed to fetch whitelist metadata: $e');
      }
      
      // Fetch whitelist data directly from Firestore
      // Primary method: Get from access_points collection (user's actual data location)
      List<AccessPointData> accessPoints = [];
      
      try {
        developer.log('🔍 Step 1: Trying access_points collection...');
        
        // Try without filter first to see what's there
        final allDocsSnapshot = await _firestore
            .collection('access_points')
            .limit(5)
            .get();
        
        developer.log('📊 Total documents in access_points collection: ${allDocsSnapshot.docs.length}');
        if (allDocsSnapshot.docs.isNotEmpty) {
          final sampleDoc = allDocsSnapshot.docs.first;
          developer.log('📋 Sample document fields: ${sampleDoc.data().keys.toList()}');
        }
        
        // Load ALL access_points on startup - no filtering needed
        developer.log('🔄 Loading ALL access_points from collection...');
        final accessPointsSnapshot = await _firestore
            .collection('access_points')
            .limit(10000) // Large limit to get all documents
            .get();
        developer.log('✅ Loaded ${accessPointsSnapshot.docs.length} total access points from collection');
        
        developer.log('📊 Found ${accessPointsSnapshot.docs.length} documents in access_points collection');
        
        // Debug: Show sample document structure for troubleshooting
        if (accessPointsSnapshot.docs.isNotEmpty) {
          final sampleDoc = accessPointsSnapshot.docs.first;
          final sampleData = sampleDoc.data();
          developer.log('📋 Sample access point document structure:');
          developer.log('   Document ID: ${sampleDoc.id}');
          developer.log('   Available fields: ${sampleData.keys.toList()}');
          if (sampleData.containsKey('ssid')) developer.log('   SSID: ${sampleData['ssid']}');
          if (sampleData.containsKey('verified')) developer.log('   Verified: ${sampleData['verified']}');
          if (sampleData.containsKey('isActive')) developer.log('   IsActive: ${sampleData['isActive']}');
          if (sampleData.containsKey('status')) developer.log('   Status: ${sampleData['status']}');
          if (sampleData.containsKey('isWhitelisted')) developer.log('   IsWhitelisted: ${sampleData['isWhitelisted']}');
        }
        
        if (accessPointsSnapshot.docs.isNotEmpty) {
          accessPoints = accessPointsSnapshot.docs
              .map((doc) => AccessPointData.fromFirestore(doc.id, doc.data()))
              .toList();
          
          developer.log('✅ Successfully loaded ${accessPoints.length} access points from access_points collection');
          
          trace.setMetric('access_points_count', accessPoints.length);
          await trace.stop();
          
          return WhitelistData(
            version: metadata?['version'] ?? '1.0.0',
            lastUpdated: metadata != null ? (metadata['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now() : DateTime.now(),
            accessPoints: accessPoints,
            checksum: metadata?['checksum'] ?? '',
          );
        }
      } catch (e) {
        developer.log('❌ access_points collection failed: $e');
      }
      
      // Fallback method: Get from whitelist_data collection
      try {
        developer.log('🔍 Step 2: Fallback to whitelist_data collection...');
        final whitelistSnapshot = await _firestore
            .collection('whitelist_data')
            .orderBy('createdAt', descending: false)
            .limit(5000) // Process in chunks to stay within free tier limits
            .get();
        
        accessPoints = [];
        
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
          version: metadata?['version'] ?? '1.0.0',
          lastUpdated: metadata != null ? (metadata['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now() : DateTime.now(),
          accessPoints: accessPoints,
          checksum: metadata?['checksum'] ?? '',
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
          version: metadata?['version'] ?? '1.0.0',
          lastUpdated: metadata != null ? (metadata['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now() : DateTime.now(),
          accessPoints: accessPoints,
          checksum: metadata?['checksum'] ?? '',
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
    // Ensure Firebase is initialized before using _firestore
    if (!_initialized) {
      await initialize();
    }
    
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
    // Ensure Firebase is initialized before using _firestore
    if (!_initialized) {
      await initialize();
    }
    
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
  final String? venue;
  final String? barangay;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final Map<String, dynamic> signalStrength;
  final String type;
  final String status;
  final bool isVerified;

  AccessPointData({
    required this.id,
    required this.ssid,
    required this.macAddress,
    required this.latitude,
    required this.longitude,
    required this.region,
    required this.province,
    required this.city,
    this.venue,
    this.barangay,
    this.verifiedAt,
    this.verifiedBy,
    required this.signalStrength,
    required this.type,
    required this.status,
    required this.isVerified,
  });

  // Compatibility getter for cityName (returns city)
  String get cityName => city;

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
      venue: json['venue'],
      barangay: json['barangay'],
      verifiedAt: json['verifiedAt'] != null ? DateTime.tryParse(json['verifiedAt']) : null,
      verifiedBy: json['verifiedBy'],
      signalStrength: json['signalStrength'] ?? {},
      type: json['type'] ?? 'unknown',
      status: json['status'] ?? 'unknown',
      isVerified: json['verified'] ?? json['isVerified'] ?? false,
    );
  }

  static Map<String, dynamic> _parseSignalStrength(dynamic signalData) {
    if (signalData == null) return {};
    if (signalData is Map<String, dynamic>) return signalData;
    if (signalData is int) return {'dbm': signalData};
    if (signalData is double) return {'dbm': signalData.toInt()};
    return {};
  }

  static double _extractCoordinate(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value is num && value != 0) {
        return value.toDouble();
      }
    }
    return 0.0;
  }

  factory AccessPointData.fromFirestore(String id, Map<String, dynamic> data) {
    developer.log('🚀 FROMFIRESTORE CALLED FOR: $id');
    
    try {
      // Handle different location formats
      double latitude = 0;
      double longitude = 0;
    
    // Try multiple location parsing strategies
    final locationData = data['location'];
    
    // Strategy 1: GeoPoint format
    if (locationData is GeoPoint) {
      latitude = locationData.latitude;
      longitude = locationData.longitude;
      developer.log('   ✅ Parsed GeoPoint: lat=$latitude, lng=$longitude');
    }
    // Strategy 2: Map format with nested structure
    else if (locationData is Map<String, dynamic>) {
      // Try direct latitude/longitude in location object
      latitude = _extractCoordinate(locationData, ['latitude', 'lat', '_latitude']);
      longitude = _extractCoordinate(locationData, ['longitude', 'lng', '_longitude']);
      
      // CRITICAL FIX: Try coordinates object nested in location
      if (latitude == 0.0 && longitude == 0.0) {
        final coordinates = locationData['coordinates'];
        developer.log('   🔍 Checking coordinates object: $coordinates');
        if (coordinates is Map<String, dynamic>) {
          developer.log('   🔍 Coordinates keys: ${coordinates.keys.toList()}');
          developer.log('   🔍 Coordinates values: $coordinates');
          
          latitude = _extractCoordinate(coordinates, ['latitude', 'lat']);
          longitude = _extractCoordinate(coordinates, ['longitude', 'lng']);
          developer.log('   🎯 Found coordinates object: lat=$latitude, lng=$longitude');
          
          // DIRECT ACCESS - ALWAYS USE THIS METHOD
          developer.log('   🆘 DIRECT TEST: coordinates[latitude] = ${coordinates['latitude']}');
          developer.log('   🆘 DIRECT TEST: coordinates[longitude] = ${coordinates['longitude']}');
          
          try {
            final latValue = coordinates['latitude'];
            final lngValue = coordinates['longitude'];
            
            if (latValue != null && lngValue != null) {
              // Handle both num and String types
              if (latValue is num) {
                latitude = latValue.toDouble();
              } else if (latValue is String) {
                latitude = double.parse(latValue);
              }
              
              if (lngValue is num) {
                longitude = lngValue.toDouble();
              } else if (lngValue is String) {
                longitude = double.parse(lngValue);
              }
              
              developer.log('   ✅ DIRECT ACCESS SUCCESS: lat=$latitude, lng=$longitude');
            }
          } catch (e) {
            developer.log('   ❌ DIRECT ACCESS FAILED: $e');
          }
        }
      }
      
      // Try GeoPoint nested in location
      if (latitude == 0.0 && longitude == 0.0) {
        final geopoint = locationData['geopoint'];
        if (geopoint is GeoPoint) {
          latitude = geopoint.latitude;
          longitude = geopoint.longitude;
        } else if (geopoint is Map<String, dynamic>) {
          latitude = _extractCoordinate(geopoint, ['latitude', 'lat', '_latitude']);
          longitude = _extractCoordinate(geopoint, ['longitude', 'lng', '_longitude']);
        }
      }
      developer.log('   📍 Parsed from location map: lat=$latitude, lng=$longitude');
    }
    
    // Strategy 3: Direct document fields
    if (latitude == 0.0 && longitude == 0.0) {
      latitude = _extractCoordinate(data, ['latitude', 'lat']);
      longitude = _extractCoordinate(data, ['longitude', 'lng']);
      developer.log('   🎯 Parsed from direct fields: lat=$latitude, lng=$longitude');
    }
    
    // Strategy 4: Try any field that might contain coordinates
    if (latitude == 0.0 && longitude == 0.0) {
      // Look through all fields for anything that looks like coordinates
      for (final entry in data.entries) {
        final key = entry.key.toLowerCase();
        final value = entry.value;
        
        if (key.contains('lat') && value is num && value != 0) {
          latitude = value.toDouble();
        }
        if (key.contains('lng') || key.contains('lon') && value is num && value != 0) {
          longitude = value.toDouble();
        }
      }
      developer.log('   🔍 Parsed from field search: lat=$latitude, lng=$longitude');
    }
    
    // FINAL COORDINATE TEST
    developer.log('🎯 FINAL RESULT FOR $id: lat=$latitude, lng=$longitude (Valid: ${latitude != 0.0 && longitude != 0.0})');
    
    // Debug logging for conversion
    developer.log('🔄 Converting Firestore document to AccessPointData:');
    developer.log('   ID: $id');
    developer.log('   IMMEDIATE TEST - Raw location data: ${data['location']}');
    developer.log('   SSID: ${data['ssid']}');
    developer.log('   Status: ${data['status']}');
    developer.log('   isWhitelisted: ${data['isWhitelisted']}');
    developer.log('   verified: ${data['verified']}');
    developer.log('   isVerified: ${data['isVerified']}');
    developer.log('   Location type: ${locationData.runtimeType}');
    if (locationData is Map<String, dynamic>) {
      developer.log('   Location keys: ${locationData.keys.toList()}');
      developer.log('   Location values: $locationData');
    }
    developer.log('   SignalStrength type: ${data['signalStrength'].runtimeType}');
    developer.log('   Final coordinates: lat=$latitude, lng=$longitude');
    developer.log('   Valid location: ${latitude != 0.0 && longitude != 0.0}');
    
      // Extract venue and barangay from location object (reuse existing locationData variable)
      String? venue;
      String? barangay;
      String? locationProvince;
      String? locationCity;
      
      if (locationData is Map<String, dynamic>) {
        venue = locationData['venue'];
        barangay = locationData['barangay'];  
        locationProvince = locationData['province'];
        locationCity = locationData['city'];
      }
      
      // Extract verification date
      DateTime? verifiedAt;
      final verifiedAtData = data['verifiedAt'] ?? data['createdAt'] ?? data['timestamp'];
      if (verifiedAtData != null) {
        if (verifiedAtData is Timestamp) {
          verifiedAt = verifiedAtData.toDate();
        } else if (verifiedAtData is String) {
          verifiedAt = DateTime.tryParse(verifiedAtData);
        }
      }

      return AccessPointData(
        id: id,
        ssid: data['ssid'] ?? '',
        macAddress: data['bssid'] ?? data['macAddress'] ?? '', // Try bssid first, then macAddress
        latitude: latitude,
        longitude: longitude,
        region: data['region'] ?? locationProvince ?? '',
        province: locationProvince ?? data['province'] ?? '',
        city: locationCity ?? data['city'] ?? '',
        venue: venue,
        barangay: barangay,
        verifiedAt: verifiedAt,
        verifiedBy: data['verifiedBy'] ?? data['detectedBy'] ?? 'DICT CALABARZON',
        signalStrength: _parseSignalStrength(data['signalStrength']),
        type: data['networkType'] ?? data['type'] ?? 'unknown', // Try networkType first
        status: data['status'] ?? 'unknown',
        isVerified: data['isWhitelisted'] ?? data['verified'] ?? data['isVerified'] ?? true, // Try isWhitelisted first
      );
    } catch (e) {
      developer.log('❌ FROMFIRESTORE ERROR for $id: $e');
      // Return a fallback object with default coordinates
      return AccessPointData(
        id: id,
        ssid: data['ssid'] ?? 'Unknown',
        macAddress: data['bssid'] ?? data['macAddress'] ?? '',
        latitude: 0.0, // Default fallback coordinate
        longitude: 0.0, // Default fallback coordinate
        region: '',
        province: '',
        city: '',
        venue: null,
        barangay: null,
        verifiedAt: null,
        verifiedBy: 'DICT CALABARZON',
        signalStrength: {},
        type: 'unknown',
        status: 'unknown',
        isVerified: true,
      );
    }
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