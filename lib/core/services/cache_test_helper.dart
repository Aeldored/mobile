import 'dart:developer' as developer;
import 'app_cache_manager.dart';

/// Helper class for testing and debugging the cache system
class CacheTestHelper {
  static final AppCacheManager _cacheManager = AppCacheManager();

  /// Test the cache performance with sample data
  static Future<void> runCachePerformanceTest() async {
    developer.log('🧪 Starting cache performance test...');
    
    final stopwatch = Stopwatch();
    
    // Test cache write performance
    stopwatch.start();
    await _testCacheWrites();
    stopwatch.stop();
    final writeTime = stopwatch.elapsedMilliseconds;
    
    // Test cache read performance
    stopwatch.reset();
    stopwatch.start();
    await _testCacheReads();
    stopwatch.stop();
    final readTime = stopwatch.elapsedMilliseconds;
    
    // Test cache validation
    stopwatch.reset();
    stopwatch.start();
    final canSkip = await _cacheManager.canSkipFullInitialization();
    stopwatch.stop();
    final validationTime = stopwatch.elapsedMilliseconds;
    
    developer.log('📊 Cache Performance Results:');
    developer.log('   💾 Write Time: ${writeTime}ms');
    developer.log('   📖 Read Time: ${readTime}ms');
    developer.log('   ✅ Validation Time: ${validationTime}ms');
    developer.log('   🚀 Can Skip Init: $canSkip');
    
    // Log cache statistics
    final stats = await _cacheManager.getCacheStats();
    developer.log('📈 Cache Statistics:');
    stats.forEach((key, value) {
      developer.log('   $key: $value');
    });
  }

  static Future<void> _testCacheWrites() async {
    // Simulate typical cache writes during initialization
    await _cacheManager.cacheProviderData('test_alert_provider', {
      'initialized': true,
      'alert_count': 5,
      'last_update': DateTime.now().toIso8601String(),
    });
    
    await _cacheManager.cacheProviderData('test_network_provider', {
      'firebase_connected': true,
      'whitelist_loaded': true,
      'access_points': 150,
    });
    
    await _cacheManager.cacheFirebaseStatus(true, {
      'connection_time': DateTime.now().toIso8601String(),
      'performance_metrics': {'latency': 120, 'reliability': 0.98}
    });
    
    await _cacheManager.cachePermissionStatus({
      'location': true,
      'wifi': true,
      'storage': true,
    });
    
    await _cacheManager.markInitializationComplete();
  }

  static Future<void> _testCacheReads() async {
    // Simulate typical cache reads during warm start
    await _cacheManager.getCachedProviderData('test_alert_provider');
    await _cacheManager.getCachedProviderData('test_network_provider');
    await _cacheManager.getCachedFirebaseStatus();
    await _cacheManager.getCachedPermissionStatus();
    await _cacheManager.canSkipFullInitialization();
  }

  /// Simulate cache aging for testing expiration
  static Future<void> simulateCacheAging() async {
    developer.log('⏰ Simulating cache aging...');
    
    // This would typically involve manipulating timestamps in SharedPreferences
    // For testing, we can just clear and recreate with old timestamps
    await _cacheManager.clearAllCache();
    
    // Note: In a real test, we would mock the timestamps to be older
    developer.log('✅ Cache aging simulation complete');
  }

  /// Test cache behavior under different scenarios
  static Future<void> testCacheScenarios() async {
    developer.log('🎭 Testing different cache scenarios...');
    
    // Scenario 1: Fresh cache (should enable warm start)
    await _cacheManager.clearAllCache();
    await _testCacheWrites();
    final canWarmStart1 = await _cacheManager.canSkipFullInitialization();
    developer.log('📝 Scenario 1 - Fresh cache: Can warm start = $canWarmStart1');
    
    // Scenario 2: No cache (should require cold start)
    await _cacheManager.clearAllCache();
    final canWarmStart2 = await _cacheManager.canSkipFullInitialization();
    developer.log('📝 Scenario 2 - No cache: Can warm start = $canWarmStart2');
    
    // Scenario 3: Partial cache (should fallback to cold start)
    await _cacheManager.cacheProviderData('partial_provider', {'test': true});
    final canWarmStart3 = await _cacheManager.canSkipFullInitialization();
    developer.log('📝 Scenario 3 - Partial cache: Can warm start = $canWarmStart3');
    
    developer.log('✅ Cache scenario testing complete');
  }

  /// Estimate memory usage of cached data
  static Future<void> analyzeCacheMemoryUsage() async {
    developer.log('💾 Analyzing cache memory usage...');
    
    final stats = await _cacheManager.getCacheStats();
    var totalBytes = 0;
    
    for (final entry in stats.entries) {
      final data = entry.value;
      if (data is Map && data.containsKey('size_bytes')) {
        totalBytes += (data['size_bytes'] as int);
      }
    }
    
    final totalKB = totalBytes / 1024;
    final totalMB = totalKB / 1024;
    
    developer.log('📊 Cache Memory Analysis:');
    developer.log('   📦 Total Entries: ${stats.length}');
    developer.log('   💾 Total Size: $totalBytes bytes (${totalKB.toStringAsFixed(2)} KB)');
    
    if (totalMB > 1) {
      developer.log('   ⚠️ Cache size is ${totalMB.toStringAsFixed(2)} MB - consider cleanup');
    } else {
      developer.log('   ✅ Cache size is optimal');
    }
  }

  /// Clear all test data
  static Future<void> cleanup() async {
    await _cacheManager.clearAllCache();
    developer.log('🧹 Cache test cleanup complete');
  }
}