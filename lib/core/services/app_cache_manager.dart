import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized cache manager for app startup optimization
class AppCacheManager {
  static final AppCacheManager _instance = AppCacheManager._internal();
  factory AppCacheManager() => _instance;
  AppCacheManager._internal();
  
  SharedPreferences? _prefs;
  
  // Cache keys
  static const String _initializationStatusKey = 'app_init_status';
  static const String _lastFullInitKey = 'last_full_init';
  static const String _providerCachePrefix = 'provider_cache_';
  static const String _firebaseConnectionKey = 'firebase_connection_cache';
  static const String _permissionStatusKey = 'permission_status_cache';
  
  // Cache expiration durations
  static const Duration _initCacheExpiration = Duration(hours: 6);
  static const Duration _permissionCacheExpiration = Duration(minutes: 30);
  static const Duration _providerCacheExpiration = Duration(hours: 12);

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    developer.log('🗄️ AppCacheManager initialized');
  }

  /// Check if we can skip heavy initialization (warm start)
  Future<bool> canSkipFullInitialization() async {
    await initialize();
    
    final lastInit = _prefs!.getInt(_lastFullInitKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSinceInit = Duration(milliseconds: now - lastInit);
    
    final hasValidCache = timeSinceInit < _initCacheExpiration;
    final initStatus = _prefs!.getString(_initializationStatusKey);
    
    final canSkip = hasValidCache && initStatus == 'complete';
    developer.log('🚀 Can skip full initialization: $canSkip (last init: ${timeSinceInit.inMinutes}min ago)');
    
    return canSkip;
  }

  /// Mark initialization as complete
  Future<void> markInitializationComplete() async {
    await initialize();
    await _prefs!.setString(_initializationStatusKey, 'complete');
    await _prefs!.setInt(_lastFullInitKey, DateTime.now().millisecondsSinceEpoch);
    developer.log('✅ Initialization marked as complete and cached');
  }

  /// Cache provider initialization data
  Future<void> cacheProviderData(String providerName, Map<String, dynamic> data) async {
    await initialize();
    final key = '$_providerCachePrefix$providerName';
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _prefs!.setString(key, jsonEncode(cacheData));
    developer.log('💾 Cached data for $providerName');
  }

  /// Get cached provider data
  Future<Map<String, dynamic>?> getCachedProviderData(String providerName) async {
    await initialize();
    final key = '$_providerCachePrefix$providerName';
    final jsonStr = _prefs!.getString(key);
    
    if (jsonStr == null) return null;
    
    try {
      final cacheData = jsonDecode(jsonStr);
      final timestamp = cacheData['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      final age = Duration(milliseconds: now - timestamp);
      
      if (age > _providerCacheExpiration) {
        developer.log('⏰ Cached data for $providerName expired (${age.inHours}h old)');
        return null;
      }
      
      developer.log('📦 Using cached data for $providerName (${age.inMinutes}min old)');
      return Map<String, dynamic>.from(cacheData['data']);
    } catch (e) {
      developer.log('❌ Error reading cached data for $providerName: $e');
      return null;
    }
  }

  /// Cache Firebase connection status
  Future<void> cacheFirebaseStatus(bool isConnected, Map<String, dynamic>? metadata) async {
    await initialize();
    final data = {
      'connected': isConnected,
      'metadata': metadata,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _prefs!.setString(_firebaseConnectionKey, jsonEncode(data));
  }

  /// Get cached Firebase connection status
  Future<Map<String, dynamic>?> getCachedFirebaseStatus() async {
    await initialize();
    final jsonStr = _prefs!.getString(_firebaseConnectionKey);
    if (jsonStr == null) return null;
    
    try {
      final data = jsonDecode(jsonStr);
      final timestamp = data['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      final age = Duration(milliseconds: now - timestamp);
      
      // Firebase status cache expires faster
      if (age > const Duration(minutes: 15)) return null;
      
      return Map<String, dynamic>.from(data);
    } catch (e) {
      return null;
    }
  }

  /// Cache permission status
  Future<void> cachePermissionStatus(Map<String, bool> permissions) async {
    await initialize();
    final data = {
      'permissions': permissions,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _prefs!.setString(_permissionStatusKey, jsonEncode(data));
  }

  /// Get cached permission status
  Future<Map<String, bool>?> getCachedPermissionStatus() async {
    await initialize();
    final jsonStr = _prefs!.getString(_permissionStatusKey);
    if (jsonStr == null) return null;
    
    try {
      final data = jsonDecode(jsonStr);
      final timestamp = data['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      final age = Duration(milliseconds: now - timestamp);
      
      if (age > _permissionCacheExpiration) return null;
      
      return Map<String, bool>.from(data['permissions']);
    } catch (e) {
      return null;
    }
  }

  /// Warm up cache in background (call this when app goes to background)
  Future<void> warmUpCache() async {
    developer.log('🔥 Starting cache warm-up in background');
    
    // This would typically refresh commonly used data
    // We'll implement specific warm-up strategies per provider
  }

  /// Clear all cache (for debugging or major updates)
  Future<void> clearAllCache() async {
    await initialize();
    
    final keys = [
      _initializationStatusKey,
      _lastFullInitKey,
      _firebaseConnectionKey,
      _permissionStatusKey,
    ];
    
    // Clear provider caches
    final allKeys = _prefs!.getKeys();
    final providerKeys = allKeys.where((k) => k.startsWith(_providerCachePrefix));
    
    for (final key in [...keys, ...providerKeys]) {
      await _prefs!.remove(key);
    }
    
    developer.log('🗑️ All cache cleared');
  }

  /// Cache security patterns for threat detection
  Future<void> cacheSecurityPatterns(Map<String, dynamic> patterns) async {
    await initialize();
    await cacheProviderData('security_patterns', patterns);
    developer.log('🛡️ Security patterns cached');
  }

  /// Cache threat detection readiness status
  Future<void> cacheThreatDetectionReadiness(Map<String, dynamic> readiness) async {
    await initialize();
    await cacheProviderData('threat_detection_readiness', readiness);
    developer.log('🎯 Threat detection readiness cached');
  }

  /// Get cached network data
  Future<List<Map<String, dynamic>>?> getCachedNetworkData() async {
    await initialize();
    final data = await getCachedProviderData('network_data');
    if (data != null && data.containsKey('networks')) {
      return List<Map<String, dynamic>>.from(data['networks']);
    }
    return null;
  }

  /// Cache network data
  Future<void> cacheNetworkData(List<Map<String, dynamic>> networks) async {
    await initialize();
    await cacheProviderData('network_data', {'networks': networks});
    developer.log('📡 Network data cached: ${networks.length} networks');
  }

  /// Get cache statistics for debugging
  Future<Map<String, dynamic>> getCacheStats() async {
    await initialize();
    
    final allKeys = _prefs!.getKeys();
    final cacheKeys = allKeys.where((k) => 
      k.startsWith(_providerCachePrefix) || 
      k == _firebaseConnectionKey ||
      k == _permissionStatusKey ||
      k == _initializationStatusKey
    ).toList();
    
    final stats = <String, dynamic>{};
    
    for (final key in cacheKeys) {
      final value = _prefs!.getString(key);
      if (value != null) {
        try {
          final data = jsonDecode(value);
          if (data is Map && data.containsKey('timestamp')) {
            final timestamp = data['timestamp'] as int;
            final age = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - timestamp);
            stats[key] = {
              'age_minutes': age.inMinutes,
              'size_bytes': value.length,
            };
          }
        } catch (e) {
          stats[key] = {'error': e.toString()};
        }
      }
    }
    
    return stats;
  }
}