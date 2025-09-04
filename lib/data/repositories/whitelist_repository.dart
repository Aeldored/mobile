import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';

class WhitelistRepository {
  final FirebaseService _firebaseService;
  final SharedPreferences _prefs;
  
  static const String _whitelistCacheKey = 'whitelist_cache';
  static const String _lastSyncKey = 'whitelist_last_sync';
  static const Duration _cacheExpiration = Duration(hours: 24);

  WhitelistRepository({
    required FirebaseService firebaseService,
    required SharedPreferences prefs,
  })  : _firebaseService = firebaseService,
        _prefs = prefs;

  // Get whitelist with caching
  Future<WhitelistData?> getWhitelist({bool forceRefresh = false}) async {
    developer.log('🔄 WHITELIST REPOSITORY DEBUG: getWhitelist called');
    developer.log('   - forceRefresh: $forceRefresh');
    developer.log('   - _isCacheValid(): ${!forceRefresh ? _isCacheValid() : 'N/A (force refresh)'}');
    
    // Check cache validity
    if (!forceRefresh && _isCacheValid()) {
      final cached = _getCachedWhitelist();
      if (cached != null) {
        developer.log('Using cached whitelist');
        return cached;
      }
    }

    // Fetch from Firebase
    developer.log('Fetching whitelist from Firebase');
    try {
      final whitelist = await _firebaseService.fetchCurrentWhitelist();
      developer.log('🔄 WHITELIST REPOSITORY: Firebase service returned ${whitelist != null ? "${whitelist.accessPoints.length} access points" : "null"}');
      
      if (whitelist != null) {
        await _cacheWhitelist(whitelist);
      }
      
      return whitelist;
    } catch (e) {
      developer.log('❌ WHITELIST REPOSITORY: Error calling Firebase service: $e');
      return null;
    }
  }

  // Stream for real-time updates
  Stream<WhitelistMetadata> whitelistUpdates() {
    return _firebaseService.whitelistUpdates();
  }

  // Check if cache is valid
  bool _isCacheValid() {
    final lastSync = _prefs.getInt(_lastSyncKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastSync) < _cacheExpiration.inMilliseconds;
  }

  // Get cached whitelist
  WhitelistData? _getCachedWhitelist() {
    final jsonStr = _prefs.getString(_whitelistCacheKey);
    if (jsonStr == null) return null;

    try {
      final json = jsonDecode(jsonStr);
      final accessPoints = (json['accessPoints'] as List)
          .map((ap) => AccessPointData(
                id: ap['id'],
                ssid: ap['ssid'],
                macAddress: ap['macAddress'],
                latitude: ap['latitude'],
                longitude: ap['longitude'],
                region: ap['region'],
                province: ap['province'],
                city: ap['city'],
                signalStrength: Map<String, dynamic>.from(ap['signalStrength']),
                type: ap['type'],
                status: ap['status'],
                isVerified: ap['isVerified'] ?? true,
              ))
          .toList();
      
      return WhitelistData(
        version: json['version'],
        lastUpdated: DateTime.parse(json['lastUpdated']),
        accessPoints: accessPoints,
        checksum: json['checksum'],
      );
    } catch (e) {
      developer.log('Error parsing cached whitelist: $e');
      return null;
    }
  }

  // Cache whitelist
  Future<void> _cacheWhitelist(WhitelistData whitelist) async {
    final json = {
      'version': whitelist.version,
      'lastUpdated': whitelist.lastUpdated.toIso8601String(),
      'checksum': whitelist.checksum,
      'accessPoints': whitelist.accessPoints.map((ap) => {
        'id': ap.id,
        'ssid': ap.ssid,
        'macAddress': ap.macAddress,
        'latitude': ap.latitude,
        'longitude': ap.longitude,
        'region': ap.region,
        'province': ap.province,
        'city': ap.city,
        'signalStrength': ap.signalStrength,
        'type': ap.type,
        'status': ap.status,
      }).toList(),
    };

    await _prefs.setString(_whitelistCacheKey, jsonEncode(json));
    await _prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Clear cache
  Future<void> clearCache() async {
    await _prefs.remove(_whitelistCacheKey);
    await _prefs.remove(_lastSyncKey);
  }

  // Get nearby access points
  Future<List<AccessPointData>> getNearbyAccessPoints(
    double latitude,
    double longitude, {
    double radiusKm = 10.0,
  }) async {
    return await _firebaseService.fetchNearbyAccessPoints(
      latitude,
      longitude,
      radiusKm,
    );
  }

  // Check if network is whitelisted
  bool isNetworkWhitelisted(String macAddress, WhitelistData? whitelist) {
    if (whitelist == null) return false;
    return whitelist.accessPoints.any((ap) => 
      ap.macAddress.toLowerCase() == macAddress.toLowerCase() && 
      ap.status == 'active'
    );
  }

  // Get whitelist statistics
  Map<String, dynamic> getWhitelistStats(WhitelistData? whitelist) {
    if (whitelist == null) {
      return {
        'totalAccessPoints': 0,
        'regionCount': 0,
        'typeBreakdown': <String, int>{},
        'lastUpdated': null,
      };
    }

    final typeBreakdown = <String, int>{};
    final regions = <String>{};

    for (final ap in whitelist.accessPoints) {
      if (ap.status == 'active') {
        typeBreakdown[ap.type] = (typeBreakdown[ap.type] ?? 0) + 1;
        regions.add(ap.region);
      }
    }

    return {
      'totalAccessPoints': whitelist.accessPoints.where((ap) => ap.status == 'active').length,
      'regionCount': regions.length,
      'typeBreakdown': typeBreakdown,
      'lastUpdated': whitelist.lastUpdated,
      'version': whitelist.version,
    };
  }
}