/// WiFi connection results - shared across all WiFi services
enum WiFiConnectionResult {
  success,
  failed,
  error,
  permissionDenied,
  passwordRequired,
  userCancelled,
  notSupported,
  redirectedToSettings, // Used only by legacy native controller
}