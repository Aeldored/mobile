import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for managing permission acknowledgment persistence
class PermissionPersistence {
  static const String _acknowledgedKey = 'permissions_acknowledged';
  static const String _timestampKey = 'permissions_acknowledged_timestamp';
  
  /// Check if permissions have been acknowledged
  static Future<bool> hasAcknowledgedPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_acknowledgedKey) ?? false;
    } catch (e) {
      // If SharedPreferences fails, assume not acknowledged for safety
      return false;
    }
  }
  
  /// Mark permissions as acknowledged
  static Future<void> markPermissionsAcknowledged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_acknowledgedKey, true);
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Silently fail - the app will still work
    }
  }
  
  /// Reset permission acknowledgment (e.g., when permissions are revoked)
  static Future<void> resetPermissionAcknowledgment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_acknowledgedKey, false);
      await prefs.remove(_timestampKey);
    } catch (e) {
      // Silently fail
    }
  }
  
  /// Get acknowledgment timestamp
  static Future<DateTime?> getAcknowledgmentTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_timestampKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Clear all permission data (for app reset/reinstall scenarios)
  static Future<void> clearAllPermissionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_acknowledgedKey);
      await prefs.remove(_timestampKey);
    } catch (e) {
      // Silently fail
    }
  }
}