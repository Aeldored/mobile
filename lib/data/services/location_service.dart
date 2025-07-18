import 'dart:async';
import 'dart:developer' as developer;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_constants.dart';

class LocationService {
  StreamController<Position>? _locationStreamController;
  StreamSubscription<Position>? _locationSubscription;
  Position? _currentPosition;
  
  Position? get currentPosition => _currentPosition;
  Stream<Position>? get locationStream => _locationStreamController?.stream;

  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Request location permission
  Future<bool> requestLocationPermission() async {
    final permission = await Permission.location.request();
    
    if (permission == PermissionStatus.granted) {
      return true;
    } else if (permission == PermissionStatus.permanentlyDenied) {
      // Open app settings
      await openAppSettings();
      return false;
    }
    
    return false;
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationServiceDisabledException();
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw PermissionDeniedException('Location permissions are denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw PermissionDeniedException(
          'Location permissions are permanently denied, we cannot request permissions.'
        );
      }

      // Get location
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      
      return _currentPosition;
    } catch (e) {
      developer.log('Location error: $e');
      
      // Return default location if error
      return Position(
        latitude: AppConstants.defaultLatitude,
        longitude: AppConstants.defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
  }

  // Start location updates
  Future<void> startLocationUpdates({
    Duration interval = const Duration(seconds: 5),
    double distanceFilter = 10,
  }) async {
    try {
      // Check permissions first
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return;

      // Initialize stream controller if needed
      _locationStreamController ??= StreamController<Position>.broadcast();

      // Configure location settings
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // meters
      );

      // Start listening to location updates
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _currentPosition = position;
          _locationStreamController?.add(position);
        },
        onError: (error) {
          developer.log('Location stream error: $error');
          _locationStreamController?.addError(error);
        },
      );
    } catch (e) {
      developer.log('Start location updates error: $e');
    }
  }

  // Stop location updates
  void stopLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationStreamController?.close();
    _locationStreamController = null;
  }

  // Calculate distance between two points
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // Get distance from current location
  Future<double?> getDistanceFromCurrentLocation(
    double latitude,
    double longitude,
  ) async {
    final current = await getCurrentLocation();
    if (current == null) return null;

    return calculateDistance(
      current.latitude,
      current.longitude,
      latitude,
      longitude,
    );
  }

  // Check if location is within radius
  Future<bool> isWithinRadius(
    double latitude,
    double longitude,
    double radiusMeters,
  ) async {
    final distance = await getDistanceFromCurrentLocation(latitude, longitude);
    if (distance == null) return false;
    
    return distance <= radiusMeters;
  }

  // Get location accuracy string
  String getAccuracyString(double accuracy) {
    if (accuracy <= 5) return 'Excellent';
    if (accuracy <= 10) return 'Good';
    if (accuracy <= 25) return 'Fair';
    if (accuracy <= 50) return 'Poor';
    return 'Very Poor';
  }

  // Format coordinates
  String formatCoordinates(double latitude, double longitude) {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lonDir = longitude >= 0 ? 'E' : 'W';
    
    return '${latitude.abs().toStringAsFixed(4)}°$latDir, '
           '${longitude.abs().toStringAsFixed(4)}°$lonDir';
  }

  // Dispose resources
  void dispose() {
    stopLocationUpdates();
  }
}

// Custom exceptions
class LocationServiceDisabledException implements Exception {
  final String message;
  LocationServiceDisabledException([this.message = 'Location services are disabled']);
  
  @override
  String toString() => message;
}

class PermissionDeniedException implements Exception {
  final String message;
  PermissionDeniedException(this.message);
  
  @override
  String toString() => message;
}