import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../../data/services/network_activity_tracker.dart';
import '../services/app_cache_manager.dart';

/// App lifecycle observer to handle activity tracking and cache warming during app state changes
class AppLifecycleObserver extends WidgetsBindingObserver {
  final NetworkActivityTracker _activityTracker = NetworkActivityTracker();
  final AppCacheManager _cacheManager = AppCacheManager();
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    developer.log('📱 App lifecycle state changed: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground
        developer.log('🔄 App resumed - activity tracking continues');
        _handleAppResumed();
        break;
        
      case AppLifecycleState.inactive:
        // App is transitioning (brief state)
        developer.log('⏸️ App inactive - maintaining activity tracking');
        break;
        
      case AppLifecycleState.paused:
        // App moved to background (but still running)
        developer.log('⏸️ App paused - starting background cache warming');
        _handleAppPaused();
        break;
        
      case AppLifecycleState.detached:
        // App is about to be terminated
        developer.log('🛑 App detached - tracking disconnection');
        _handleAppTermination();
        break;
        
      case AppLifecycleState.hidden:
        // App is hidden (iOS specific)
        developer.log('👁️ App hidden - maintaining activity tracking');
        break;
    }
  }
  
  /// Handle app termination by tracking disconnection
  void _handleAppTermination() {
    // Use a synchronous approach for app termination
    _activityTracker.trackDisconnection().catchError((e) {
      developer.log('⚠️ Failed to track disconnection during app termination: $e');
    });
  }
  
  /// Initialize the lifecycle observer
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    developer.log('👀 App lifecycle observer initialized');
  }
  
  /// Cleanup the lifecycle observer
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    developer.log('🧹 App lifecycle observer disposed');
  }

  /// Handle app being paused - start background cache warming
  void _handleAppPaused() {
    // Don't await this - let it run in background
    _performBackgroundCacheWarming().catchError((e) {
      developer.log('⚠️ Background cache warming failed: $e');
    });
  }

  /// Handle app being resumed - check if cache needs refresh
  void _handleAppResumed() {
    // Quick check if cache is still valid
    _checkCacheValidityOnResume().catchError((e) {
      developer.log('⚠️ Cache validity check failed: $e');
    });
  }

  /// Perform background cache warming while app is paused
  Future<void> _performBackgroundCacheWarming() async {
    developer.log('🔥 Starting background cache warming...');
    
    try {
      // Warm up the general cache
      await _cacheManager.warmUpCache();
      
      // Pre-emptively refresh data that might be stale by next app launch
      await _refreshStaleData();
      
      developer.log('✅ Background cache warming completed');
    } catch (e) {
      developer.log('❌ Background cache warming error: $e');
    }
  }

  /// Refresh data that might become stale before next app launch
  Future<void> _refreshStaleData() async {
    // This would typically involve:
    // - Refreshing Firebase data if connection is available
    // - Pre-loading commonly accessed data
    // - Updating cache timestamps
    
    developer.log('🔄 Refreshing potentially stale data...');
    
    // Add a small delay to avoid competing with other background tasks
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Note: In a real implementation, we would:
    // 1. Check network connectivity
    // 2. Refresh Firebase whitelist data
    // 3. Update permission status cache
    // 4. Pre-load critical app data
  }

  /// Check cache validity when app resumes
  Future<void> _checkCacheValidityOnResume() async {
    developer.log('🔍 Checking cache validity on app resume...');
    
    try {
      // Get cache statistics
      final cacheStats = await _cacheManager.getCacheStats();
      
      // Check if any critical cache entries are expired or missing
      var hasExpiredEntries = false;
      
      for (final entry in cacheStats.entries) {
        final data = entry.value;
        if (data is Map && data.containsKey('age_minutes')) {
          final ageMinutes = data['age_minutes'] as int;
          
          // Flag as expired if older than 30 minutes
          if (ageMinutes > 30) {
            hasExpiredEntries = true;
            developer.log('⏰ Cache entry ${entry.key} is ${ageMinutes}min old');
          }
        }
      }
      
      if (hasExpiredEntries) {
        developer.log('🔄 Some cache entries expired, will use cold start on next launch');
        // We could optionally trigger a background refresh here
      } else {
        developer.log('✅ Cache is fresh, warm start will be available');
      }
      
    } catch (e) {
      developer.log('❌ Cache validity check error: $e');
    }
  }
}