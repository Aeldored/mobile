import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// Provider for managing persistent map state across app sessions and tab navigation
class MapStateProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  
  // Map state
  LatLng? _lastCameraPosition;
  double _lastZoomLevel = 9.0;
  LatLng? _lastKnownLocation;
  DateTime? _lastLocationUpdateTime;
  bool _hasCustomCameraPosition = false;
  
  // Default map center (CALABARZON region) - updated to match web dashboard
  static const LatLng _defaultCenter = LatLng(14.296990, 121.459040);
  static const double _defaultZoom = 9.0;
  
  // Cache duration for location (30 minutes)
  static const Duration _locationCacheDuration = Duration(minutes: 30);

  MapStateProvider(this._prefs) {
    _loadPersistedState();
  }

  // Getters
  LatLng get cameraPosition => _lastCameraPosition ?? _defaultCenter;
  double get zoomLevel => _lastZoomLevel;
  LatLng? get lastKnownLocation => _lastKnownLocation;
  bool get hasCustomCameraPosition => _hasCustomCameraPosition;
  bool get hasValidCachedLocation => _isLocationCacheValid();
  
  /// Load persisted map state from SharedPreferences
  void _loadPersistedState() {
    try {
      // Load camera position
      final lat = _prefs.getDouble('map_camera_lat');
      final lng = _prefs.getDouble('map_camera_lng');
      if (lat != null && lng != null) {
        _lastCameraPosition = LatLng(lat, lng);
        _hasCustomCameraPosition = true;
      }
      
      // Load zoom level
      _lastZoomLevel = _prefs.getDouble('map_zoom_level') ?? _defaultZoom;
      
      // Load last known location
      final locationLat = _prefs.getDouble('last_location_lat');
      final locationLng = _prefs.getDouble('last_location_lng');
      if (locationLat != null && locationLng != null) {
        _lastKnownLocation = LatLng(locationLat, locationLng);
      }
      
      // Load last location update time
      final lastUpdateMs = _prefs.getInt('last_location_update_ms');
      if (lastUpdateMs != null) {
        _lastLocationUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdateMs);
      }
      
      developer.log('MapStateProvider: Loaded persisted state - '
          'Camera: $_lastCameraPosition, Zoom: $_lastZoomLevel, '
          'Last location: $_lastKnownLocation');
          
    } catch (e) {
      developer.log('MapStateProvider: Error loading persisted state: $e');
    }
  }

  /// Update camera position and persist it
  Future<void> updateCameraPosition(LatLng position, double zoom) async {
    try {
      _lastCameraPosition = position;
      _lastZoomLevel = zoom;
      _hasCustomCameraPosition = true;
      
      // Persist to storage
      await _prefs.setDouble('map_camera_lat', position.latitude);
      await _prefs.setDouble('map_camera_lng', position.longitude);
      await _prefs.setDouble('map_zoom_level', zoom);
      
      notifyListeners();
      
      developer.log('MapStateProvider: Updated camera position: $position, zoom: $zoom');
    } catch (e) {
      developer.log('MapStateProvider: Error updating camera position: $e');
    }
  }

  /// Update last known location and persist it
  Future<void> updateLastKnownLocation(LatLng location) async {
    try {
      _lastKnownLocation = location;
      _lastLocationUpdateTime = DateTime.now();
      
      // Persist to storage
      await _prefs.setDouble('last_location_lat', location.latitude);
      await _prefs.setDouble('last_location_lng', location.longitude);
      await _prefs.setInt('last_location_update_ms', _lastLocationUpdateTime!.millisecondsSinceEpoch);
      
      notifyListeners();
      
      developer.log('MapStateProvider: Updated last known location: $location');
    } catch (e) {
      developer.log('MapStateProvider: Error updating last known location: $e');
    }
  }

  /// Reset map to default center (useful for "reset view" functionality)
  Future<void> resetToDefault() async {
    try {
      _lastCameraPosition = _defaultCenter;
      _lastZoomLevel = _defaultZoom;
      _hasCustomCameraPosition = false;
      
      // Clear persisted camera position
      await _prefs.remove('map_camera_lat');
      await _prefs.remove('map_camera_lng');
      await _prefs.setDouble('map_zoom_level', _defaultZoom);
      
      notifyListeners();
      
      developer.log('MapStateProvider: Reset to default center');
    } catch (e) {
      developer.log('MapStateProvider: Error resetting to default: $e');
    }
  }

  /// Clear last known location (when user wants to forget cached location)
  Future<void> clearLastKnownLocation() async {
    try {
      _lastKnownLocation = null;
      _lastLocationUpdateTime = null;
      
      // Remove from storage
      await _prefs.remove('last_location_lat');
      await _prefs.remove('last_location_lng');
      await _prefs.remove('last_location_update_ms');
      
      notifyListeners();
      
      developer.log('MapStateProvider: Cleared last known location');
    } catch (e) {
      developer.log('MapStateProvider: Error clearing last known location: $e');
    }
  }

  /// Check if cached location is still valid (within cache duration)
  bool _isLocationCacheValid() {
    if (_lastKnownLocation == null || _lastLocationUpdateTime == null) {
      return false;
    }
    
    final now = DateTime.now();
    final cacheAge = now.difference(_lastLocationUpdateTime!);
    return cacheAge <= _locationCacheDuration;
  }

  /// Get appropriate location for centering map based on settings and cache
  LatLng? getLocationForCentering(bool isLocationEnabled, bool hasPermission) {
    // If location is enabled and permission granted, return null to fetch live location
    if (isLocationEnabled && hasPermission) {
      return null; // Signal to fetch fresh location
    }
    
    // Otherwise, return cached location if available and valid
    if (hasValidCachedLocation) {
      return _lastKnownLocation;
    }
    
    // No valid cached location available
    return null;
  }

  /// Get location cache age in minutes (for UI display)
  int? getLocationCacheAgeMinutes() {
    if (_lastLocationUpdateTime == null) return null;
    
    final now = DateTime.now();
    final age = now.difference(_lastLocationUpdateTime!);
    return age.inMinutes;
  }

  /// Clear all persisted data
  Future<void> clearAllData() async {
    try {
      await _prefs.remove('map_camera_lat');
      await _prefs.remove('map_camera_lng');
      await _prefs.remove('map_zoom_level');
      await _prefs.remove('last_location_lat');
      await _prefs.remove('last_location_lng');
      await _prefs.remove('last_location_update_ms');
      
      // Reset to defaults
      _lastCameraPosition = null;
      _lastZoomLevel = _defaultZoom;
      _lastKnownLocation = null;
      _lastLocationUpdateTime = null;
      _hasCustomCameraPosition = false;
      
      notifyListeners();
      
      developer.log('MapStateProvider: Cleared all data');
    } catch (e) {
      developer.log('MapStateProvider: Error clearing all data: $e');
    }
  }
}