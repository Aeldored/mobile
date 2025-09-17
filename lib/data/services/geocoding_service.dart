import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  // CALABARZON region boundaries and city data
  static const Map<String, Map<String, dynamic>> _calabarzonCities = {
    // Cavite
    'Cavite City': {'lat': 14.4791, 'lng': 120.8984, 'province': 'Cavite'},
    'Bacoor': {'lat': 14.4588, 'lng': 120.9378, 'province': 'Cavite'},
    'Imus': {'lat': 14.4297, 'lng': 120.9370, 'province': 'Cavite'},
    'Dasmariñas': {'lat': 14.3294, 'lng': 120.9367, 'province': 'Cavite'},
    'General Trias': {'lat': 14.3875, 'lng': 120.8808, 'province': 'Cavite'},
    'Tagaytay': {'lat': 14.1053, 'lng': 120.9621, 'province': 'Cavite'},
    'Trece Martires': {'lat': 14.2832, 'lng': 120.8674, 'province': 'Cavite'},
    
    // Laguna
    'Santa Rosa': {'lat': 14.3124, 'lng': 121.1114, 'province': 'Laguna'},
    'Biñan': {'lat': 14.3371, 'lng': 121.0764, 'province': 'Laguna'},
    'San Pedro': {'lat': 14.3583, 'lng': 121.0584, 'province': 'Laguna'},
    'Sta. Cruz': {'lat': 14.2791, 'lng': 121.4166, 'province': 'Laguna'},
    'Calamba': {'lat': 14.2118, 'lng': 121.1653, 'province': 'Laguna'},
    'Los Baños': {'lat': 14.1693, 'lng': 121.2416, 'province': 'Laguna'},
    'San Pablo': {'lat': 14.0683, 'lng': 121.3256, 'province': 'Laguna'},
    
    // Batangas
    'Batangas City': {'lat': 13.7565, 'lng': 121.0584, 'province': 'Batangas'},
    'Lipa': {'lat': 13.9411, 'lng': 121.1648, 'province': 'Batangas'},
    'Tanauan': {'lat': 14.0863, 'lng': 121.1489, 'province': 'Batangas'},
    'Santo Tomas': {'lat': 14.1078, 'lng': 121.1412, 'province': 'Batangas'},
    'Nasugbu': {'lat': 14.0788, 'lng': 120.6367, 'province': 'Batangas'},
    'Bauan': {'lat': 13.7927, 'lng': 121.0091, 'province': 'Batangas'},
    'Malvar': {'lat': 14.0456, 'lng': 121.1542, 'province': 'Batangas'},
    
    // Rizal
    'Antipolo': {'lat': 14.5995, 'lng': 121.1794, 'province': 'Rizal'},
    'Cainta': {'lat': 14.5769, 'lng': 121.1222, 'province': 'Rizal'},
    'Marikina': {'lat': 14.6507, 'lng': 121.1029, 'province': 'Rizal'},
    'San Mateo': {'lat': 14.6972, 'lng': 121.1224, 'province': 'Rizal'},
    'Taytay': {'lat': 14.5574, 'lng': 121.1320, 'province': 'Rizal'},
    'Angono': {'lat': 14.5264, 'lng': 121.1531, 'province': 'Rizal'},
    'Teresa': {'lat': 14.5598, 'lng': 121.2119, 'province': 'Rizal'},
    
    // Quezon
    'Lucena': {'lat': 13.9372, 'lng': 121.6173, 'province': 'Quezon'},
    'Tayabas': {'lat': 14.0266, 'lng': 121.5917, 'province': 'Quezon'},
    'Sariaya': {'lat': 13.9619, 'lng': 121.5264, 'province': 'Quezon'},
    'Candelaria': {'lat': 13.9322, 'lng': 121.4236, 'province': 'Quezon'},
    'Tiaong': {'lat': 13.9494, 'lng': 121.3289, 'province': 'Quezon'},
    'San Antonio': {'lat': 13.8547, 'lng': 121.3661, 'province': 'Quezon'},
    'Dolores': {'lat': 13.9431, 'lng': 121.4164, 'province': 'Quezon'},
  };

  // CALABARZON region bounds - extended to match web dashboard coverage
  static const double _northBound = 15.5;
  static const double _southBound = 13.0;
  static const double _eastBound = 123.0;
  static const double _westBound = 120.2;

  /// Check if coordinates are within CALABARZON region
  bool isWithinCalabarzon(double latitude, double longitude) {
    return latitude >= _southBound &&
           latitude <= _northBound &&
           longitude >= _westBound &&
           longitude <= _eastBound;
  }

  /// Get the nearest city name for given coordinates
  String? getCityName(double latitude, double longitude) {
    if (!isWithinCalabarzon(latitude, longitude)) {
      return null; // Outside CALABARZON
    }

    String? nearestCity;
    double minDistance = double.infinity;

    for (final entry in _calabarzonCities.entries) {
      final cityData = entry.value;
      final cityLat = cityData['lat'] as double;
      final cityLng = cityData['lng'] as double;
      
      final distance = _calculateDistance(latitude, longitude, cityLat, cityLng);
      
      if (distance < minDistance) {
        minDistance = distance;
        nearestCity = entry.key;
      }
    }

    // Only return city if within reasonable distance (50km)
    return minDistance <= 50.0 ? nearestCity : null;
  }

  /// Get city information including province
  Map<String, String>? getCityInfo(String cityName) {
    final cityData = _calabarzonCities[cityName];
    if (cityData == null) return null;

    return {
      'city': cityName,
      'province': cityData['province'] as String,
      'fullName': '$cityName, ${cityData['province']}',
    };
  }

  /// Get all cities in a specific province
  List<String> getCitiesByProvince(String province) {
    return _calabarzonCities.entries
        .where((entry) => entry.value['province'] == province)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get random coordinates within a city (for mock data)
  LatLng? getRandomCityCoordinates(String cityName) {
    final cityData = _calabarzonCities[cityName];
    if (cityData == null) return null;

    final baseLat = cityData['lat'] as double;
    final baseLng = cityData['lng'] as double;
    
    // Add random offset within ~5km radius
    final random = DateTime.now().millisecondsSinceEpoch % 1000;
    final latOffset = (random - 500) / 100000; // ~±0.005 degrees
    final lngOffset = (random - 500) / 100000;
    
    return LatLng(
      baseLat + latOffset,
      baseLng + lngOffset,
    );
  }

  /// Get center coordinates for CALABARZON region
  LatLng getCalabarzonCenter() {
    return const LatLng(14.296990, 121.459040); // Updated to match web dashboard center
  }

  /// Get bounds for CALABARZON region
  Map<String, double> getCalabarzonBounds() {
    return {
      'north': _northBound,
      'south': _southBound,
      'east': _eastBound,
      'west': _westBound,
    };
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.pow(math.sin(dLat / 2), 2) +
              math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
              math.pow(math.sin(dLon / 2), 2);
    
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (math.pi / 180);

  /// Get province color for map visualization
  static Map<String, int> getProvinceColors() {
    return {
      'Cavite': 0xFF4CAF50,    // Green
      'Laguna': 0xFF2196F3,    // Blue  
      'Batangas': 0xFFFF9800,  // Orange
      'Rizal': 0xFF9C27B0,     // Purple
      'Quezon': 0xFFF44336,    // Red
    };
  }

  /// Get all CALABARZON provinces
  List<String> getProvinces() {
    return ['Cavite', 'Laguna', 'Batangas', 'Rizal', 'Quezon'];
  }

  /// Get all cities in CALABARZON
  List<String> getAllCities() {
    return _calabarzonCities.keys.toList();
  }
}