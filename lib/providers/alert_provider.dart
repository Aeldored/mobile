import 'package:flutter/foundation.dart';
import '../data/models/alert_model.dart';
import '../data/models/network_model.dart';

class AlertProvider extends ChangeNotifier {
  final List<AlertModel> _alerts = [];
  final List<AlertModel> _archivedAlerts = [];

  List<AlertModel> get alerts => _alerts;
  List<AlertModel> get archivedAlerts => _archivedAlerts;
  
  List<AlertModel> get recentAlerts => _alerts
      .where((alert) => !alert.isArchived)
      .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  
  List<AlertModel> get unreadAlerts => _alerts
      .where((alert) => !alert.isRead && !alert.isArchived)
      .toList();
  
  int get unreadCount => unreadAlerts.length;

  AlertProvider() {
    _initializeMockAlerts();
  }

  void _initializeMockAlerts() {
    final now = DateTime.now();
    
    // Add some initial alerts
    _alerts.addAll([
      AlertModel(
        id: 'alert_1',
        type: AlertType.evilTwin,
        title: 'Evil Twin Attack Detected',
        message: 'A suspicious network "DICT-CALABARZON-FREE" is mimicking the official government WiFi.',
        severity: AlertSeverity.critical,
        networkName: 'DICT-CALABARZON-FREE',
        securityType: 'Open',
        macAddress: 'FF:FF:FF:FF:FF:FF',
        location: 'Lipa City, Batangas',
        timestamp: now.subtract(const Duration(minutes: 5)),
        isRead: false,
      ),
      AlertModel(
        id: 'alert_2',
        type: AlertType.suspiciousNetwork,
        title: 'Suspicious Network Detected',
        message: 'Network "FREE_WiFi_CalambaCity" appears to be potentially malicious.',
        severity: AlertSeverity.high,
        networkName: 'FREE_WiFi_CalambaCity',
        securityType: 'Open',
        macAddress: 'DE:AD:BE:EF:CA:FE',
        location: 'Calamba City, Laguna',
        timestamp: now.subtract(const Duration(minutes: 15)),
        isRead: false,
      ),
      AlertModel(
        id: 'alert_3',
        type: AlertType.networkBlocked,
        title: 'Network Automatically Blocked',
        message: 'Suspicious network "SM_Free_WiFi" has been automatically blocked for your protection.',
        severity: AlertSeverity.medium,
        networkName: 'SM_Free_WiFi',
        securityType: 'Open',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        location: 'SM Calamba',
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: true,
      ),
    ]);
  }

  void generateAlertForNetwork(NetworkModel network) {
    if (network.status == NetworkStatus.suspicious) {
      final alertId = 'alert_${DateTime.now().millisecondsSinceEpoch}';
      
      AlertType alertType;
      String title;
      String message;
      AlertSeverity severity;
      
      if (network.description?.contains('evil twin') == true) {
        alertType = AlertType.evilTwin;
        title = 'Evil Twin Attack Detected';
        message = 'Suspicious network "${network.name}" is mimicking a legitimate network.';
        severity = AlertSeverity.critical;
      } else {
        alertType = AlertType.suspiciousNetwork;
        title = 'Suspicious Network Detected';
        message = 'Network "${network.name}" shows signs of potential malicious activity.';
        severity = AlertSeverity.high;
      }
      
      final alert = AlertModel(
        id: alertId,
        type: alertType,
        title: title,
        message: message,
        severity: severity,
        networkName: network.name,
        securityType: network.securityType.toString().split('.').last,
        macAddress: network.macAddress,
        location: network.latitude != null && network.longitude != null
            ? 'Lat: ${network.latitude!.toStringAsFixed(4)}, Lng: ${network.longitude!.toStringAsFixed(4)}'
            : 'Unknown location',
        timestamp: DateTime.now(),
        isRead: false,
      );
      
      _alerts.insert(0, alert); // Add to beginning for most recent first
      notifyListeners();
    }
  }
  
  void generateBlockedNetworkAlert(NetworkModel network) {
    final alertId = 'alert_blocked_${DateTime.now().millisecondsSinceEpoch}';
    
    final alert = AlertModel(
      id: alertId,
      type: AlertType.networkBlocked,
      title: 'Network Blocked',
      message: 'Network "${network.name}" has been blocked and will no longer appear in scan results.',
      severity: AlertSeverity.medium,
      networkName: network.name,
      securityType: network.securityType.toString().split('.').last,
      macAddress: network.macAddress,
      location: network.latitude != null && network.longitude != null
          ? 'Lat: ${network.latitude!.toStringAsFixed(4)}, Lng: ${network.longitude!.toStringAsFixed(4)}'
          : 'Unknown location',
      timestamp: DateTime.now(),
      isRead: false,
    );
    
    _alerts.insert(0, alert);
    notifyListeners();
  }

  void generateFlaggedNetworkAlert(NetworkModel network) {
    final alertId = 'alert_flagged_${DateTime.now().millisecondsSinceEpoch}';
    
    final alert = AlertModel(
      id: alertId,
      type: AlertType.suspiciousNetwork,
      title: 'Network Flagged as Suspicious',
      message: 'You have flagged "${network.name}" as suspicious. Connection warnings will be shown.',
      severity: AlertSeverity.medium,
      networkName: network.name,
      securityType: network.securityType.toString().split('.').last,
      macAddress: network.macAddress,
      location: network.latitude != null && network.longitude != null
          ? 'Lat: ${network.latitude!.toStringAsFixed(4)}, Lng: ${network.longitude!.toStringAsFixed(4)}'
          : 'Unknown location',
      timestamp: DateTime.now(),
      isRead: false,
    );
    
    _alerts.insert(0, alert);
    notifyListeners();
  }

  void generateTrustedNetworkAlert(NetworkModel network) {
    final alertId = 'alert_trusted_${DateTime.now().millisecondsSinceEpoch}';
    
    final alert = AlertModel(
      id: alertId,
      type: AlertType.networkTrusted,
      title: 'Network Added to Trusted List',
      message: 'Network "${network.name}" has been marked as trusted for secure connections.',
      severity: AlertSeverity.low,
      networkName: network.name,
      securityType: network.securityType.toString().split('.').last,
      macAddress: network.macAddress,
      location: network.latitude != null && network.longitude != null
          ? 'Lat: ${network.latitude!.toStringAsFixed(4)}, Lng: ${network.longitude!.toStringAsFixed(4)}'
          : 'Unknown location',
      timestamp: DateTime.now(),
      isRead: false,
    );
    
    _alerts.insert(0, alert);
    notifyListeners();
  }
  
  void generateScanSummaryAlert(int totalNetworks, int threatsDetected, DateTime scanTime) {
    final alertId = 'alert_summary_${DateTime.now().millisecondsSinceEpoch}';
    
    final alert = AlertModel(
      id: alertId,
      type: threatsDetected > 0 ? AlertType.warning : AlertType.info,
      title: 'Scan Complete',
      message: 'Found $totalNetworks networks, $threatsDetected potential threats detected.',
      severity: threatsDetected > 0 ? AlertSeverity.medium : AlertSeverity.low,
      networkName: null,
      securityType: null,
      macAddress: null,
      location: 'Scan completed at ${_formatTime(scanTime)}',
      timestamp: DateTime.now(),
      isRead: false,
    );
    
    _alerts.insert(0, alert);
    notifyListeners();
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void markAsRead(String alertId) {
    final index = _alerts.indexWhere((alert) => alert.id == alertId);
    if (index != -1) {
      _alerts[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var alert in _alerts) {
      alert.isRead = true;
    }
    notifyListeners();
  }

  void archiveAlert(String alertId) {
    final index = _alerts.indexWhere((alert) => alert.id == alertId);
    if (index != -1) {
      final alert = _alerts.removeAt(index);
      alert.isArchived = true;
      _archivedAlerts.insert(0, alert);
      notifyListeners();
    }
  }

  void deleteAlert(String alertId) {
    _alerts.removeWhere((alert) => alert.id == alertId);
    _archivedAlerts.removeWhere((alert) => alert.id == alertId);
    notifyListeners();
  }

  void clearAllAlerts() {
    _alerts.clear();
    _archivedAlerts.clear();
    notifyListeners();
  }

  List<AlertModel> getAlertsByType(AlertType type) {
    return _alerts.where((alert) => alert.type == type && !alert.isArchived).toList();
  }

  List<AlertModel> getAlertsBySeverity(AlertSeverity severity) {
    return _alerts.where((alert) => alert.severity == severity && !alert.isArchived).toList();
  }
  
  /// Settings integration
  bool _notificationsEnabled = true;
  
  bool get notificationsEnabled => _notificationsEnabled;
  
  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
  }
}