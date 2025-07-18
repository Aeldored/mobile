class AppConstants {
  // App Info
  static const String appName = 'DisConX';
  static const String appFullName = 'DICT Secure Connect';
  static const String appVersion = '1.2.5';
  static const String organization = 'DICT-CALABARZON';
  
  // API Endpoints (to be configured with your backend)
  static const String baseUrl = 'https://api.disconx.dict.gov.ph';
  static const String whitelistEndpoint = '/api/v1/whitelist';
  static const String networksEndpoint = '/api/v1/networks';
  static const String alertsEndpoint = '/api/v1/alerts';
  static const String reportEndpoint = '/api/v1/report';
  
  // Timeouts and Intervals
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration scanInterval = Duration(seconds: 10);
  static const Duration locationUpdateInterval = Duration(minutes: 5);
  static const Duration cacheExpiration = Duration(hours: 24);
  
  // Limits
  static const int maxNetworkHistory = 100;
  static const int maxAlertHistory = 50;
  static const int minPasswordLength = 8;
  static const int maxSearchResults = 20;
  
  // Network Signal Thresholds
  static const int strongSignalThreshold = 70;
  static const int mediumSignalThreshold = 40;
  static const int weakSignalThreshold = 20;
  
  // Map Configuration
  static const double defaultMapZoom = 15.0;
  static const double minMapZoom = 10.0;
  static const double maxMapZoom = 18.0;
  
  // Default Location (Lipa City, Batangas)
  static const double defaultLatitude = 13.9425;
  static const double defaultLongitude = 121.1644;
  
  // Security Configuration
  static const List<String> trustedMacPrefixes = [
    '00:1A:2B', // Example DICT prefix
    'A1:B2:C3', // Example trusted vendor
  ];
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Storage Keys
  static const String keyUserPreferences = 'user_preferences';
  static const String keyNetworkHistory = 'network_history';
  static const String keyBlockedNetworks = 'blocked_networks';
  static const String keyWhitelistCache = 'whitelist_cache';
  static const String keyLastSyncTime = 'last_sync_time';
  
  // Error Messages
  static const String errorNoInternet = 'No internet connection. Please check your connection and try again.';
  static const String errorTimeout = 'Request timed out. Please try again.';
  static const String errorGeneric = 'Something went wrong. Please try again later.';
  static const String errorLocationPermission = 'Location permission is required to scan for nearby networks.';
  static const String errorLocationService = 'Please enable location services to use this feature.';
}