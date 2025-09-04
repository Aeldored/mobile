import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:convert';

class WhitelistEntry {
  final String id;
  final String ssid;
  final String? macAddress;
  final double latitude;
  final double longitude;
  final String? address;
  final String? venue;  // Added venue field
  final String region;
  final String province;
  final String city;
  final String? barangay;
  final String verifiedBy;
  final DateTime verifiedAt;
  final DateTime addedAt;
  final bool isActive;
  final String? notes;

  WhitelistEntry({
    required this.id,
    required this.ssid,
    this.macAddress,
    required this.latitude,
    required this.longitude,
    this.address,
    this.venue,  // Added venue parameter
    required this.region,
    required this.province,
    required this.city,
    this.barangay,
    required this.verifiedBy,
    required this.verifiedAt,
    required this.addedAt,
    this.isActive = true,
    this.notes,
  });

  factory WhitelistEntry.fromFirestore(String id, Map<String, dynamic> data) {
    // Enhanced location extraction - handle multiple possible structures
    final location = data['location'] as Map<String, dynamic>?;
    
    double lat = 0.0;
    double lng = 0.0;
    
    // Log raw location data for debugging
    developer.log('🔍 DEBUG: Processing entry $id');
    developer.log('🔍 DEBUG: Raw location field: $location');
    developer.log('🔍 DEBUG: Raw location type: ${location.runtimeType}');
    
    // Try different location field structures
    if (location != null) {
      developer.log('🔍 DEBUG: Location object keys: ${location.keys.toList()}');
      
      // First try the ACTUAL nested structure: location.coordinates.latitude
      dynamic latValue;
      dynamic lngValue;
      
      if (location['coordinates'] != null && location['coordinates'] is Map) {
        final coords = location['coordinates'] as Map<String, dynamic>;
        developer.log('🔍 DEBUG: Found coordinates object: $coords');
        latValue = coords['latitude'];
        lngValue = coords['longitude'];
        developer.log('🔍 DEBUG: Extracted from coordinates - lat: $latValue, lng: $lngValue');
      }
      
      // Fallback to other possible coordinate field names
      latValue ??= location['latitude'] ?? location['lat'] ?? location['y'] ?? location['_latitude'];
      lngValue ??= location['longitude'] ?? location['lng'] ?? location['lon'] ?? location['x'] ?? location['_longitude'];
      
      developer.log('🔍 DEBUG: Found lat value: $latValue (type: ${latValue.runtimeType})');
      developer.log('🔍 DEBUG: Found lng value: $lngValue (type: ${lngValue.runtimeType})');
      
      if (latValue != null) {
        try {
          lat = double.parse(latValue.toString());
          developer.log('🔍 DEBUG: Successfully parsed lat: $lat');
        } catch (e) {
          developer.log('🔍 DEBUG: Failed to parse lat value: $latValue, error: $e');
        }
      }
      
      if (lngValue != null) {
        try {
          lng = double.parse(lngValue.toString());
          developer.log('🔍 DEBUG: Successfully parsed lng: $lng');
        } catch (e) {
          developer.log('🔍 DEBUG: Failed to parse lng value: $lngValue, error: $e');
        }
      }
      
      developer.log('🔍 DEBUG: After location parsing - lat: $lat, lng: $lng');
    } else {
      developer.log('🔍 DEBUG: No location object found, trying direct fields');
    }
    
    // Fallback to direct fields if location object doesn't have coordinates
    if (lat == 0.0 && lng == 0.0) {
      developer.log('🔍 DEBUG: Trying direct coordinate fields...');
      final latValue = data['latitude'] ?? data['lat'] ?? data['y'] ?? data['_latitude'];
      final lngValue = data['longitude'] ?? data['lng'] ?? data['lon'] ?? data['x'] ?? data['_longitude'];
      
      developer.log('🔍 DEBUG: Direct lat value: $latValue (type: ${latValue.runtimeType})');
      developer.log('🔍 DEBUG: Direct lng value: $lngValue (type: ${lngValue.runtimeType})');
      
      if (latValue != null) {
        try {
          lat = double.parse(latValue.toString());
          developer.log('🔍 DEBUG: Successfully parsed direct lat: $lat');
        } catch (e) {
          developer.log('🔍 DEBUG: Failed to parse direct lat: $latValue, error: $e');
        }
      }
      
      if (lngValue != null) {
        try {
          lng = double.parse(lngValue.toString());
          developer.log('🔍 DEBUG: Successfully parsed direct lng: $lng');
        } catch (e) {
          developer.log('🔍 DEBUG: Failed to parse direct lng: $lngValue, error: $e');
        }
      }
      
      developer.log('🔍 DEBUG: After direct parsing - lat: $lat, lng: $lng');
    }
    
    // Try GeoPoint format (Firestore native geolocation)
    if (lat == 0.0 && lng == 0.0) {
      final geoPoint = data['coordinates'] ?? data['geopoint'] ?? data['position'];
      developer.log('🔍 DEBUG: Trying GeoPoint format: $geoPoint (type: ${geoPoint.runtimeType})');
      
      if (geoPoint != null) {
        // Handle Firestore GeoPoint
        if (geoPoint.runtimeType.toString().contains('GeoPoint')) {
          try {
            lat = double.parse(geoPoint.latitude.toString());
            lng = double.parse(geoPoint.longitude.toString());
            developer.log('🔍 DEBUG: GeoPoint coordinates - lat: $lat, lng: $lng');
          } catch (e) {
            developer.log('🔍 DEBUG: Error parsing GeoPoint: $e');
          }
        }
        // Handle coordinate array [lat, lng]
        else if (geoPoint is List && geoPoint.length >= 2) {
          try {
            lat = double.parse(geoPoint[0].toString());
            lng = double.parse(geoPoint[1].toString());
            developer.log('🔍 DEBUG: Array coordinates - lat: $lat, lng: $lng');
          } catch (e) {
            developer.log('🔍 DEBUG: Error parsing coordinate array: $e');
          }
        }
      }
    }
    
    developer.log('🔍 DEBUG: Final coordinates for $id - lat: $lat, lng: $lng');
    developer.log('🔍 DEBUG: hasValidLocation will be: ${lat != 0.0 && lng != 0.0}');
    
    return WhitelistEntry(
      id: id,
      ssid: data['ssid'] ?? data['networkName'] ?? data['name'] ?? 'Unknown Network',
      macAddress: data['macAddress'] ?? data['bssid'],
      latitude: lat,
      longitude: lng,
      address: data['address'] ?? location?['address'] ?? location?['formatted_address'],
      venue: data['venue'] ?? location?['venue'] ?? data['place'] ?? data['establishment'], // Added venue extraction
      region: data['region'] ?? location?['region'] ?? location?['administrative_area_level_1'] ?? 'CALABARZON',
      province: data['province'] ?? location?['province'] ?? location?['administrative_area_level_2'] ?? 'Unknown Province',
      city: data['city'] ?? location?['city'] ?? location?['locality'] ?? 'Unknown City',
      barangay: data['barangay'] ?? location?['barangay'] ?? location?['sublocality'],
      verifiedBy: data['verifiedBy'] ?? data['addedBy'] ?? data['detectedBy'] ?? 'DICT Admin',
      verifiedAt: _parseDate(data['verifiedAt'] ?? data['dateVerified'] ?? data['updatedAt']),
      addedAt: _parseDate(data['addedAt'] ?? data['createdAt'] ?? data['timestamp']),
      isActive: data['isActive'] ?? data['active'] ?? (data['status'] == 'active') ?? data['isWhitelisted'] ?? true,
      notes: data['notes'] ?? data['description'],
    );
  }

  static DateTime _parseDate(dynamic date) {
    if (date is Timestamp) {
      return date.toDate();
    } else if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  bool get hasValidLocation => latitude != 0.0 && longitude != 0.0;
  
  /// Convert WhitelistEntry to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ssid': ssid,
      'macAddress': macAddress,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'venue': venue,  // Added venue to JSON
      'region': region,
      'province': province,
      'city': city,
      'barangay': barangay,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt.toIso8601String(),
      'addedAt': addedAt.toIso8601String(),
      'isActive': isActive,
      'notes': notes,
    };
  }
  
  /// Create WhitelistEntry from JSON for local storage
  factory WhitelistEntry.fromJson(Map<String, dynamic> json) {
    return WhitelistEntry(
      id: json['id'] ?? '',
      ssid: json['ssid'] ?? 'Unknown Network',
      macAddress: json['macAddress'],
      latitude: double.parse((json['latitude'] ?? 0.0).toString()),
      longitude: double.parse((json['longitude'] ?? 0.0).toString()),
      address: json['address'],
      venue: json['venue'],  // Added venue from JSON
      region: json['region'] ?? 'Unknown Region',
      province: json['province'] ?? 'Unknown Province',
      city: json['city'] ?? 'Unknown City',
      barangay: json['barangay'],
      verifiedBy: json['verifiedBy'] ?? 'DICT Admin',
      verifiedAt: DateTime.parse(json['verifiedAt'] ?? DateTime.now().toIso8601String()),
      addedAt: DateTime.parse(json['addedAt'] ?? DateTime.now().toIso8601String()),
      isActive: json['isActive'] ?? true,
      notes: json['notes'],
    );
  }
}

class WhitelistService {
  static final WhitelistService _instance = WhitelistService._internal();
  factory WhitelistService() => _instance;
  WhitelistService._internal();

  FirebaseFirestore? _firestore;
  List<WhitelistEntry> _cachedWhitelist = [];
  DateTime? _lastFetched;

  /// Check if Firebase is initialized
  bool get _isFirebaseInitialized {
    try {
      final hasApps = Firebase.apps.isNotEmpty;
      developer.log('🔍 Firebase initialization check: hasApps=$hasApps, apps=${Firebase.apps.map((app) => app.name).toList()}');
      return hasApps;
    } catch (e) {
      developer.log('❌ Firebase initialization check failed: $e');
      return false;
    }
  }

  /// Test if Firestore is actually accessible
  Future<bool> _testFirestoreConnection() async {
    try {
      if (!_isFirebaseInitialized) {
        developer.log('🔍 Firestore test: Firebase not initialized');
        return false;
      }
      
      final firestore = FirebaseFirestore.instance;
      developer.log('🔍 Testing Firestore connection to ${firestore.app.options.projectId}...');
      
      // Try to access a collection (this will fail if Firestore isn't ready)
      await firestore.collection('access_points').limit(1).get();
      developer.log('✅ Firestore connection test successful');
      return true;
    } catch (e) {
      developer.log('❌ Firestore connection test failed: $e');
      return false;
    }
  }

  /// Lazy getter for Firestore instance
  FirebaseFirestore get firestore {
    if (_firestore == null) {
      if (!_isFirebaseInitialized) {
        throw Exception('Firebase not initialized yet');
      }
      try {
        _firestore = FirebaseFirestore.instance;
        developer.log('🔗 Firestore instance created for project: ${_firestore!.app.options.projectId}');
      } catch (e) {
        developer.log('⚠️ Firebase not initialized yet for whitelist service');
        rethrow;
      }
    }
    return _firestore!;
  }
  
  // Cache for 2 minutes (lightweight, fresher data)
  static const Duration _cacheTimeout = Duration(minutes: 2);
  
  // Local storage keys
  static const String _whitelistKey = 'cached_access_points';
  static const String _lastSyncKey = 'access_points_last_sync';

  /// Get all whitelisted networks from Firestore with offline support
  Future<List<WhitelistEntry>> getWhitelistedNetworks({bool forceRefresh = false}) async {
    try {
      // Return memory cached data if still valid
      if (!forceRefresh && 
          _cachedWhitelist.isNotEmpty && 
          _lastFetched != null && 
          DateTime.now().difference(_lastFetched!) < _cacheTimeout) {
        developer.log('📋 Returning memory cached whitelist (${_cachedWhitelist.length} entries)');
        return _cachedWhitelist;
      }

      // Check if Firebase is initialized before attempting to fetch
      if (!_isFirebaseInitialized) {
        developer.log('⚠️ Firebase not initialized yet for whitelist service');
        
        // If this is a forced refresh, wait a bit for Firebase to initialize
        if (forceRefresh) {
          developer.log('🔄 Forced refresh requested - waiting for Firebase initialization...');
          
          // Wait up to 10 seconds for Firebase to initialize and Firestore to be accessible
          for (int i = 0; i < 20; i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (_isFirebaseInitialized && await _testFirestoreConnection()) {
              developer.log('✅ Firebase and Firestore ready after ${(i + 1) * 500}ms wait');
              break;
            }
            if (i == 19) {
              developer.log('⏰ Timeout waiting for Firebase/Firestore initialization');
            }
          }
        }
        
        // Check again after waiting
        if (!_isFirebaseInitialized || !(await _testFirestoreConnection())) {
          developer.log('❌ Firebase/Firestore still not ready after waiting');
          
          // Try to return cached data from SharedPreferences if available
          final cachedData = await _loadFromLocalStorage();
          if (cachedData.isNotEmpty) {
            developer.log('📦 Returning locally cached whitelist (${cachedData.length} entries)');
            _cachedWhitelist = cachedData;
            return cachedData;
          }
          
          // Return empty list if no cached data available
          developer.log('❌ No cached data available, returning empty list');
          return [];
        }
      }

      developer.log('🔍 Attempting to fetch whitelist from Firestore...');
      developer.log('🔗 Firestore app: ${firestore.app.name}');
      developer.log('🏗️ Firestore project: ${firestore.app.options.projectId}');
      
      // Variables for tracking online fetch
      List<WhitelistEntry> onlineWhitelist = [];
      bool networkSuccess = false;
      
      try {
        // Try the main whitelist collection first
        QuerySnapshot snapshot;
        // Use the correct collection name: access_points
        try {
          developer.log('🔍 Step 1: Trying access_points collection (the correct one!)...');
          snapshot = await firestore
              .collection('access_points')
              .get();
          developer.log('📊 Step 1 Result: ${snapshot.docs.length} docs found in access_points (expected 17)');
          
          if (snapshot.docs.length == 17) {
            developer.log('🎉 SUCCESS! Found exactly 17 access points as expected');
          } else {
            developer.log('⚠️ Expected 17, got ${snapshot.docs.length}');
          }
          
          // If we found documents, analyze their structure
          if (snapshot.docs.isNotEmpty) {
            developer.log('🔍 Analyzing access_points document structure...');
            for (int i = 0; i < snapshot.docs.length && i < 3; i++) {
              final doc = snapshot.docs[i];
              final data = doc.data() as Map<String, dynamic>;
              developer.log('📄 Doc ${i + 1} (${doc.id}): ${data.keys.toList()}');
              developer.log('  - isActive: ${data['isActive']}');
              developer.log('  - active: ${data['active']}');
              developer.log('  - status: ${data['status']}');
              developer.log('  - enabled: ${data['enabled']}');
              developer.log('  - ssid: ${data['ssid'] ?? data['networkName'] ?? data['name']}');
              developer.log('  - location field: ${data['location']}');
              developer.log('  - latitude: ${data['latitude'] ?? data['lat'] ?? data['location']?['latitude'] ?? data['location']?['lat']}');
              developer.log('  - longitude: ${data['longitude'] ?? data['lng'] ?? data['lon'] ?? data['location']?['longitude'] ?? data['location']?['lng'] ?? data['location']?['lon']}');
            }
            
            // Skip isActive filter to show all access points
            developer.log('🔍 Step 2: SKIPPING isActive filter to show all 17 access points');
            developer.log('✅ Using ALL documents (${snapshot.docs.length} entries) - no filtering applied');
          } else {
            developer.log('❌ access_points collection is empty!');
          }
        } catch (e) {
          developer.log('❌ access_points collection query failed: $e');
          rethrow;
        }

        developer.log('📊 Found ${snapshot.docs.length} whitelist documents from database');
        
        // Log which collection was used
        if (snapshot.docs.isNotEmpty) {
          developer.log('✅ Successfully loaded from collection: ${snapshot.docs.first.reference.parent.id}');
        }

        int processedCount = 0;
        int validCoordCount = 0;
        int invalidCoordCount = 0;
        
        developer.log('🔄 PROCESSING ALL ${snapshot.docs.length} DOCUMENTS:');
        developer.log('=' * 60);
        
        for (var doc in snapshot.docs) {
          try {
            processedCount++;
            final data = doc.data() as Map<String, dynamic>;
            
            developer.log('📄 ENTRY $processedCount/17: ${doc.id}');
            developer.log('─' * 40);
            developer.log('📋 All fields: ${data.keys.toList()}');
            developer.log('📶 SSID: ${data['ssid'] ?? data['networkName'] ?? 'Unknown'}');
            
            // Show the complete location structure
            if (data['location'] != null) {
              developer.log('📍 LOCATION OBJECT: ${data['location']}');
              final loc = data['location'] as Map<String, dynamic>;
              developer.log('📍 Location keys: ${loc.keys.toList()}');
              
              // Check if coordinates object exists
              if (loc['coordinates'] != null) {
                developer.log('📍 COORDINATES OBJECT: ${loc['coordinates']}');
                if (loc['coordinates'] is Map) {
                  final coords = loc['coordinates'] as Map<String, dynamic>;
                  developer.log('📍 Coordinates keys: ${coords.keys.toList()}');
                  developer.log('📍 Latitude value: ${coords['latitude']} (type: ${coords['latitude'].runtimeType})');
                  developer.log('📍 Longitude value: ${coords['longitude']} (type: ${coords['longitude'].runtimeType})');
                }
              } else {
                developer.log('📍 NO coordinates object found in location');
              }
            } else {
              developer.log('📍 NO location field found');
            }
            
            // Create the entry
            final entry = WhitelistEntry.fromFirestore(doc.id, data);
            
            developer.log('🔍 FINAL RESULT:');
            developer.log('   - Parsed lat: ${entry.latitude}');
            developer.log('   - Parsed lng: ${entry.longitude}');
            developer.log('   - hasValidLocation: ${entry.hasValidLocation}');
            
            if (entry.hasValidLocation) {
              onlineWhitelist.add(entry);
              validCoordCount++;
              developer.log('✅ SUCCESS: Added to map - ${entry.ssid} at (${entry.latitude}, ${entry.longitude})');
            } else {
              invalidCoordCount++;
              developer.log('❌ FAILED: Entry will NOT appear on map - ${entry.ssid}');
              developer.log('❌ Reason: lat=${entry.latitude}, lng=${entry.longitude} (both must be non-zero)');
            }
            
            developer.log(''); // Empty line for readability
            
          } catch (e) {
            developer.log('❌ ERROR processing doc ${doc.id}: $e');
            invalidCoordCount++;
          }
        }
        
        developer.log('📊 PROCESSING SUMMARY:');
        developer.log('=' * 60);
        developer.log('📄 Total documents processed: $processedCount/17');
        developer.log('✅ Valid coordinates found: $validCoordCount');
        developer.log('❌ Invalid coordinates: $invalidCoordCount');
        developer.log('🗺️ Entries that will show on map: ${onlineWhitelist.length}');
        
        if (onlineWhitelist.length < 17) {
          developer.log('⚠️ ISSUE: Only ${onlineWhitelist.length}/17 entries will show on map!');
          developer.log('⚠️ ${17 - onlineWhitelist.length} entries have invalid coordinates');
        }
        
        networkSuccess = true;
        developer.log('✅ Successfully fetched ${onlineWhitelist.length} entries from Firestore');
        
        // Save to local storage for offline use
        await _saveToLocalStorage(onlineWhitelist);
        
        // Update memory cache
        _cachedWhitelist = onlineWhitelist;
        _lastFetched = DateTime.now();
        
        return onlineWhitelist;
        
      } catch (networkError) {
        developer.log('❌ Network error fetching from Firestore: $networkError');
        networkSuccess = false;
      }
      
      // If network failed, try to load from local storage
      if (!networkSuccess) {
        developer.log('📱 Network unavailable, loading from local storage...');
        final localWhitelist = await _loadFromLocalStorage();
        
        if (localWhitelist.isNotEmpty) {
          // Update memory cache with local data
          _cachedWhitelist = localWhitelist;
          _lastFetched = DateTime.now();
          
          developer.log('✅ Loaded ${localWhitelist.length} entries from offline storage');
          return localWhitelist;
        } else {
          developer.log('⚠️ No offline data available');
        }
      }
      
      // If we reach here, no data was found anywhere
      developer.log('❌ NO ACCESS POINTS DATA FOUND - Expected 17 from access_points collection!');
      developer.log('❌ Check Firestore rules and access_points collection structure');
      return [];
      
    } catch (error) {
      developer.log('❌ Critical error in getWhitelistedNetworks: $error');
      developer.log('❌ Error type: ${error.runtimeType}');
      
      // Last resort: try local storage
      try {
        final localWhitelist = await _loadFromLocalStorage();
        if (localWhitelist.isNotEmpty) {
          developer.log('🆘 Emergency fallback to local storage successful');
          return localWhitelist;
        }
      } catch (localError) {
        developer.log('❌ Local storage fallback failed: $localError');
      }
      
      return [];
    }
  }

  /// Check if a network is whitelisted by SSID
  Future<bool> isNetworkWhitelisted(String ssid) async {
    try {
      final whitelist = await getWhitelistedNetworks();
      return whitelist.any((entry) => 
        entry.ssid.toLowerCase() == ssid.toLowerCase() ||
        entry.ssid.contains(ssid) ||
        ssid.contains(entry.ssid)
      );
    } catch (e) {
      developer.log('❌ Error checking if network is whitelisted: $e');
      return false;
    }
  }

  /// Check if a network is whitelisted by SSID and MAC address
  Future<bool> isNetworkWhitelistedByMac(String ssid, String macAddress) async {
    try {
      final whitelist = await getWhitelistedNetworks();
      return whitelist.any((entry) => 
        (entry.ssid.toLowerCase() == ssid.toLowerCase() || 
         entry.ssid.contains(ssid) || 
         ssid.contains(entry.ssid)) &&
        (entry.macAddress != null && 
         entry.macAddress!.toLowerCase() == macAddress.toLowerCase())
      );
    } catch (e) {
      developer.log('❌ Error checking network by MAC: $e');
      return false;
    }
  }

  /// Get whitelisted networks within a specific radius (in kilometers)
  List<WhitelistEntry> getWhitelistNearLocation(
    double userLat, 
    double userLng, 
    double radiusKm
  ) {
    return _cachedWhitelist.where((entry) {
      final distance = _calculateDistance(userLat, userLng, entry.latitude, entry.longitude);
      return distance <= radiusKm;
    }).toList();
  }

  /// Calculate distance between two coordinates in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Save whitelist data to local storage
  Future<void> _saveToLocalStorage(List<WhitelistEntry> whitelist) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = whitelist.map((entry) => entry.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      await prefs.setString(_whitelistKey, jsonString);
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      
      developer.log('💾 Saved ${whitelist.length} whitelist entries to local storage');
    } catch (e) {
      developer.log('❌ Error saving whitelist to local storage: $e');
    }
  }
  
  /// Load whitelist data from local storage
  Future<List<WhitelistEntry>> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_whitelistKey);
      
      if (jsonString != null && jsonString.isNotEmpty) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        final whitelist = jsonList
            .map((json) => WhitelistEntry.fromJson(json as Map<String, dynamic>))
            .toList();
        
        final lastSync = prefs.getString(_lastSyncKey);
        developer.log('📱 Loaded ${whitelist.length} whitelist entries from local storage');
        developer.log('📅 Last sync: ${lastSync ?? 'Never'}');
        
        return whitelist;
      }
    } catch (e) {
      developer.log('❌ Error loading whitelist from local storage: $e');
    }
    
    return [];
  }
  
  /// Clear local storage cache
  Future<void> _clearLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_whitelistKey);
      await prefs.remove(_lastSyncKey);
      developer.log('🗑️ Cleared whitelist from local storage');
    } catch (e) {
      developer.log('❌ Error clearing local storage: $e');
    }
  }
  
  /// Clear cache to force refresh (keeps offline data)
  void clearCache() {
    _cachedWhitelist.clear();
    _lastFetched = null;
    developer.log('🗑️ Whitelist memory cache cleared');
  }
  
  /// Clear all data including offline storage
  Future<void> clearAllData() async {
    _cachedWhitelist.clear();
    _lastFetched = null;
    await _clearLocalStorage();
    developer.log('🗑️ All whitelist data cleared (memory + offline storage)');
  }
  
  /// Force sync with remote database and update local storage
  Future<List<WhitelistEntry>> syncWhitelistData() async {
    developer.log('🔄 Force syncing whitelist data...');
    
    // Don't clear cache immediately - keep it as fallback
    final originalCache = List<WhitelistEntry>.from(_cachedWhitelist);
    final originalFetched = _lastFetched;
    
    try {
      // Clear memory cache to force fresh fetch
      clearCache();
      final result = await getWhitelistedNetworks(forceRefresh: true);
      
      if (result.isEmpty && originalCache.isNotEmpty) {
        developer.log('⚠️ Sync returned empty but had cached data - restoring cache');
        _cachedWhitelist = originalCache;
        _lastFetched = originalFetched;
        return originalCache;
      }
      
      return result;
    } catch (e) {
      developer.log('❌ Sync failed: $e - restoring original cache');
      _cachedWhitelist = originalCache;
      _lastFetched = originalFetched;
      return originalCache;
    }
  }
}