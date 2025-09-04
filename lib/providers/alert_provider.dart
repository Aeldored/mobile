import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/alert_model.dart';
import '../data/models/network_model.dart';
import 'network_provider.dart';

class AlertProvider extends ChangeNotifier {
  final List<AlertModel> _alerts = [];
  final List<AlertModel> _archivedAlerts = [];
  NetworkProvider? _networkProvider;

  List<AlertModel> get alerts => _alerts;
  List<AlertModel> get archivedAlerts => _archivedAlerts;
  
  List<AlertModel> get recentAlerts {
    final currentSessionId = _networkProvider?.currentScanSessionId;
    if (currentSessionId == null) {
      // If no network provider or session ID, return all non-archived alerts
      return _alerts
          .where((alert) => !alert.isArchived)
          .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    
    // Filter alerts by current scan session
    return _alerts
        .where((alert) => !alert.isArchived && alert.scanSessionId == currentSessionId)
        .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  List<AlertModel> get unreadAlerts => _alerts
      .where((alert) => !alert.isRead && !alert.isArchived)
      .toList();
  
  int get unreadCount => unreadAlerts.length;

  AlertProvider() {
    // Initialization now happens during splash screen for better control
    // Call initializeIfNeeded() from splash screen when ready
  }
  
  /// Set the network provider reference for scan session tracking
  void setNetworkProvider(NetworkProvider networkProvider) {
    _networkProvider = networkProvider;
  }

  /// Public method to trigger initialization when ready (called from splash screen)
  Future<void> initializeIfNeeded() async {
    if (_alerts.isEmpty) {
      await _initializeProductionAlerts();
    } else {
      // CRITICAL FIX: Clean up any existing false positive alerts for hidden networks
      await cleanupHiddenNetworkAlerts();
    }
  }

  Future<void> _initializeProductionAlerts() async {
    try {
      // CRITICAL FIX: Load persisted alerts instead of clearing them
      await _loadPersistedAlerts();
      
      // Only add welcome alert if no alerts exist
      if (_alerts.isEmpty) {
        final welcomeAlert = AlertModel(
          id: 'welcome_alert',
          type: AlertType.info,
          title: 'WiFi Security Scanner Ready',
          message: 'Tap "Scan Networks" to begin detecting nearby WiFi networks and potential security threats.',
          severity: AlertSeverity.low,
          networkName: null,
          securityType: null,
          macAddress: null,
          location: 'DICT CALABARZON Security System',
          timestamp: DateTime.now(),
          isRead: false,
        );
        
        _alerts.add(welcomeAlert);
        await _persistAlerts();
      } else {
        // CRITICAL FIX: Clean up any existing false positive alerts for hidden networks after loading persisted alerts
        await cleanupHiddenNetworkAlerts();
      }
      
      developer.log('📱 AlertProvider initialized with ${_alerts.length} persisted alerts');
    } catch (e) {
      developer.log('❌ Error initializing alerts: $e');
    }
  }

  /// Load alerts from persistent storage
  Future<void> _loadPersistedAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load regular alerts
      final alertsJson = prefs.getString('saved_alerts');
      if (alertsJson != null) {
        final List<dynamic> alertsList = json.decode(alertsJson);
        _alerts.clear();
        _alerts.addAll(alertsList.map((json) => AlertModel.fromJson(json)));
        
        // Remove alerts older than 7 days to prevent unlimited growth
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        _alerts.removeWhere((alert) => alert.timestamp.isBefore(weekAgo));
      }
      
      // Load archived alerts
      final archivedJson = prefs.getString('archived_alerts');
      if (archivedJson != null) {
        final List<dynamic> archivedList = json.decode(archivedJson);
        _archivedAlerts.clear();
        _archivedAlerts.addAll(archivedList.map((json) => AlertModel.fromJson(json)));
      }
      
      developer.log('📦 Loaded ${_alerts.length} alerts and ${_archivedAlerts.length} archived alerts from storage');
    } catch (e) {
      developer.log('❌ Error loading persisted alerts: $e');
    }
  }

  /// Find existing alert by network identity (SSID + MAC)
  AlertModel? _findExistingAlert(String networkName, String? macAddress, {bool includeRead = false}) {
    developer.log('🔍 _findExistingAlert: Looking for $networkName ($macAddress), includeRead: $includeRead');
    
    final matches = _alerts.where((alert) => 
      alert.networkName == networkName && 
      alert.macAddress == macAddress &&
      (includeRead || !alert.isRead) // Include read alerts only if specified
    ).toList();
    
    developer.log('🔍 _findExistingAlert: Found ${matches.length} matching alerts');
    for (final match in matches) {
      developer.log('   - Match: ${match.id}, Read: ${match.isRead}, Status: ${match.threatReportStatus}, includeRead: $includeRead, passes filter: ${includeRead || !match.isRead}');
    }
    
    // CRITICAL FIX: Prioritize already reported alerts to prevent duplicate reporting
    AlertModel? result;
    
    // First, try to find an already reported alert
    final reportedAlert = matches.where((alert) => alert.threatReportStatus == ThreatReportStatus.reported).firstOrNull;
    
    if (reportedAlert != null) {
      result = reportedAlert;
      developer.log('🔍 _findExistingAlert: Found reported alert, returning ${result.id}');
    } else {
      // If no reported alert, return the first available match
      result = matches.firstOrNull;
      developer.log('🔍 _findExistingAlert: No reported alert found, returning ${result != null ? result.id : "null"}');
    }
    
    return result;
  }

  /// Update existing alert with new timestamp and location data
  AlertModel _updateExistingAlert(AlertModel existingAlert, NetworkModel network) {
    // Preserve important states but show recent activity
    return AlertModel(
      id: existingAlert.id,
      type: existingAlert.type,
      title: existingAlert.title,
      message: _updateMessageForRecentActivity(existingAlert.message, existingAlert.threatReportStatus),
      severity: existingAlert.severity,
      networkName: existingAlert.networkName,
      securityType: existingAlert.securityType,
      macAddress: existingAlert.macAddress,
      location: network.latitude != null && network.longitude != null
        ? 'Lat: ${network.latitude!.toStringAsFixed(4)}, Lng: ${network.longitude!.toStringAsFixed(4)}'
        : existingAlert.location,
      timestamp: DateTime.now(), // Always update to show recent detection
      isRead: existingAlert.isRead, // Preserve read status
      isArchived: existingAlert.isArchived,
      threatReportStatus: existingAlert.threatReportStatus, // Preserve reporting status
    );
  }

  /// Update alert message to reflect recent activity and reporting status
  String _updateMessageForRecentActivity(String originalMessage, ThreatReportStatus reportStatus) {
    String baseMessage = originalMessage;
    
    // Remove any existing "recently detected" or "already reported" suffixes
    baseMessage = baseMessage.replaceAll(RegExp(r'\s*\(Recently detected.*?\)'), '');
    baseMessage = baseMessage.replaceAll(RegExp(r'\s*\(Already reported.*?\)'), '');
    
    // Add appropriate suffix based on reporting status
    if (reportStatus == ThreatReportStatus.reported) {
      return '$baseMessage (Recently detected - Already reported from this device)';
    } else {
      return '$baseMessage (Recently detected again)';
    }
  }


  /// Remove all alerts for a specific network (SSID + MAC combination)
  void _removeAllAlertsForNetwork(String networkName, String? macAddress) {
    _alerts.removeWhere((alert) => 
      alert.networkName == networkName && alert.macAddress == macAddress
    );
  }

  /// Check if a network has already been reported from this device
  bool hasNetworkBeenReported(String networkName, String? macAddress) {
    return _alerts.any((alert) =>
      alert.networkName == networkName &&
      alert.macAddress == macAddress &&
      alert.threatReportStatus == ThreatReportStatus.reported
    ) || _archivedAlerts.any((alert) =>
      alert.networkName == networkName &&
      alert.macAddress == macAddress &&
      alert.threatReportStatus == ThreatReportStatus.reported
    );
  }

  /// Prevent duplicate reporting for same network
  bool canNetworkBeReported(String networkName, String? macAddress) {
    if (hasNetworkBeenReported(networkName, macAddress)) {
      developer.log('⚠️ Network ${networkName} (${macAddress}) already reported from this device');
      return false;
    }
    return true;
  }

  /// Save alerts to persistent storage
  Future<void> _persistAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save regular alerts
      final alertsJson = json.encode(_alerts.map((alert) => alert.toJson()).toList());
      await prefs.setString('saved_alerts', alertsJson);
      
      // Save archived alerts
      final archivedJson = json.encode(_archivedAlerts.map((alert) => alert.toJson()).toList());
      await prefs.setString('archived_alerts', archivedJson);
      
      developer.log('💾 Persisted ${_alerts.length} alerts to storage');
    } catch (e) {
      developer.log('❌ Error persisting alerts: $e');
    }
  }

  void generateAlertForNetwork(NetworkModel network, {int? scanSessionId}) {
    if (network.status == NetworkStatus.suspicious) {
      // CRITICAL FIX: Don't generate alerts for hidden networks as they shouldn't be flagged as suspicious
      if (network.name == 'Hidden Network') {
        developer.log('🔍 Skipping alert generation for hidden network (MAC: ${network.macAddress}) - hidden networks should not be suspicious');
        return;
      }
      
      developer.log('🔍 Checking for existing alert: ${network.name} (${network.macAddress})');
      developer.log('📊 Total alerts in memory: ${_alerts.length}');
      
      // Debug: List all existing alerts for this network
      final matchingAlerts = _alerts.where((alert) => 
        alert.networkName == network.name && alert.macAddress == network.macAddress
      ).toList();
      
      developer.log('📋 Found ${matchingAlerts.length} existing alerts for this network:');
      for (final alert in matchingAlerts) {
        developer.log('   - ID: ${alert.id}, Read: ${alert.isRead}, Status: ${alert.threatReportStatus}, Time: ${alert.timestamp}');
      }
      
      // Check for existing alert with same SSID and MAC address (INCLUDING READ/REPORTED ALERTS)
      final existingAlert = _findExistingAlert(network.name, network.macAddress, includeRead: true);
      
      if (existingAlert != null) {
        // CRITICAL FIX: Remove ALL duplicates for this network, not just one
        _removeAllAlertsForNetwork(network.name, network.macAddress);
        
        // Update existing alert with fresh timestamp and location, preserve reporting status
        final updatedAlert = _updateExistingAlert(existingAlert, network);
        
        // Add the updated alert to the top
        _alerts.insert(0, updatedAlert);
        
        developer.log('🧹 Cleaned ${matchingAlerts.length} duplicate alerts for ${network.name} (${network.macAddress})');
        developer.log('🔄 Updated existing alert for ${network.name} (${network.macAddress}) - Status: ${existingAlert.threatReportStatus}');
        _persistAlerts();
        notifyListeners();
        return;
      }
      
      // Create new alert if no duplicate found
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
      
      // Determine threat report status based on whether network was already reported
      final alreadyReported = hasNetworkBeenReported(network.name, network.macAddress);
      final threatStatus = alreadyReported ? ThreatReportStatus.reported : ThreatReportStatus.pending;
      
      if (alreadyReported) {
        developer.log('🚫 Network ${network.name} (${network.macAddress}) already reported - creating new alert with reported status');
      } else {
        developer.log('📝 Network ${network.name} (${network.macAddress}) not yet reported - creating new alert with pending status');
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
        scanSessionId: scanSessionId, // Track which scan generated this alert
        isRead: false,
        threatReportStatus: threatStatus,
      );
      
      _alerts.insert(0, alert); // Add to beginning for most recent first
      developer.log('🚨 Created new alert for ${network.name} (${network.macAddress})');
      _persistAlerts(); // CRITICAL: Persist alerts immediately
      notifyListeners();
    }
  }
  
  void generateBlockedNetworkAlert(NetworkModel network, {int? scanSessionId}) {
    // Check for existing blocked alert for same network
    final existingAlert = _findExistingAlert(network.name, network.macAddress, includeRead: true);
    
    // If alert already exists and is for blocking, just update timestamp
    if (existingAlert != null && existingAlert.type == AlertType.networkBlocked) {
      // CRITICAL FIX: Remove ALL duplicates for this network, not just one
      _removeAllAlertsForNetwork(network.name, network.macAddress);
      
      final updatedAlert = _updateExistingAlert(existingAlert, network);
      
      // Add the updated alert to the top
      _alerts.insert(0, updatedAlert);
      
      developer.log('🧹 Cleaned duplicates for blocked network ${network.name} (${network.macAddress})');
      developer.log('🔄 Updated existing blocked alert for ${network.name} (${network.macAddress})');
      _persistAlerts();
      notifyListeners();
      return;
    }
    
    // Create new blocked network alert
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
      scanSessionId: scanSessionId,
      isRead: false,
    );
    
    _alerts.insert(0, alert);
    developer.log('🚨 Created new blocked alert for ${network.name} (${network.macAddress})');
    _persistAlerts(); // CRITICAL: Persist alerts immediately
    notifyListeners();
  }

  void generateFlaggedNetworkAlert(NetworkModel network, {int? scanSessionId}) {
    // Check for existing alert for same network (any type)
    final existingAlert = _findExistingAlert(network.name, network.macAddress, includeRead: true);
    
    // If alert already exists, update it with flagged status
    if (existingAlert != null) {
      final updatedAlert = AlertModel(
        id: existingAlert.id,
        type: AlertType.suspiciousNetwork, // Update type to suspicious
        title: 'Network Flagged as Suspicious',
        message: 'You have flagged "${network.name}" as suspicious. Connection warnings will be shown.',
        severity: AlertSeverity.medium,
        networkName: existingAlert.networkName,
        securityType: existingAlert.securityType,
        macAddress: existingAlert.macAddress,
        location: network.latitude != null && network.longitude != null
          ? 'Lat: ${network.latitude!.toStringAsFixed(4)}, Lng: ${network.longitude!.toStringAsFixed(4)}'
          : existingAlert.location,
        timestamp: DateTime.now(),
        scanSessionId: scanSessionId ?? existingAlert.scanSessionId,
        isRead: false, // Reset read status for flagged networks
        isArchived: existingAlert.isArchived,
        threatReportStatus: ThreatReportStatus.pending, // Enable reporting
      );
      
      // CRITICAL FIX: Remove ALL duplicates for this network, not just one
      _removeAllAlertsForNetwork(network.name, network.macAddress);
      
      // Add the updated alert to the top
      _alerts.insert(0, updatedAlert);
      
      developer.log('🧹 Cleaned duplicates for flagged network ${network.name} (${network.macAddress})');
      developer.log('🔄 Updated existing alert as flagged for ${network.name} (${network.macAddress})');
      _persistAlerts();
      notifyListeners();
      return;
    }
    
    // Create new flagged network alert
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
      scanSessionId: scanSessionId,
      isRead: false,
      threatReportStatus: ThreatReportStatus.pending,
    );
    
    _alerts.insert(0, alert);
    developer.log('🚨 Created new flagged alert for ${network.name} (${network.macAddress})');
    _persistAlerts(); // CRITICAL: Persist alerts immediately
    notifyListeners();
  }

  void generateTrustedNetworkAlert(NetworkModel network, {int? scanSessionId}) {
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
      scanSessionId: scanSessionId,
      isRead: false,
    );
    
    _alerts.insert(0, alert);
    _persistAlerts(); // CRITICAL: Persist alerts immediately
    notifyListeners();
  }

  void generateUnifiedSuspiciousNetworkAlert(NetworkModel network, String threatDescription, List<String> recommendations, {bool isWhitelistMimicking = false, int? scanSessionId}) {
    // Generate unified alert that combines suspicious network detection with optional reporting
    final alertId = 'alert_unified_${DateTime.now().millisecondsSinceEpoch}';
    
    // Determine alert type and severity
    AlertType alertType;
    AlertSeverity severity;
    String title;
    ThreatReportStatus reportStatus;
    
    if (network.description?.contains('evil twin') == true) {
      alertType = AlertType.evilTwin;
      severity = AlertSeverity.critical;
      title = 'Evil Twin Attack Detected';
    } else {
      alertType = AlertType.suspiciousNetwork;
      severity = AlertSeverity.high;
      title = 'Suspicious Network Detected';
    }
    
    // Set report status based on whether this is a reportable threat
    if (isWhitelistMimicking) {
      reportStatus = ThreatReportStatus.pending;
    } else {
      reportStatus = ThreatReportStatus.notApplicable;
    }
    
    // Create clean, unified message without duplicate reporting instructions
    String message = 'Network "${network.name}" shows signs of potential malicious activity.';
    
    if (threatDescription.isNotEmpty) {
      message += '\n\n$threatDescription';
    }
    
    if (recommendations.isNotEmpty) {
      final cleanRecommendations = recommendations.take(3).map((r) => 
        '• ${r.replaceAll('🚨', '').replaceAll('⚡', '').replaceAll('📱', '').replaceAll('🛡️', '').replaceAll('⛔', '').replaceAll('📋', '').replaceAll('🔍', '').trim()}'
      ).join('\n');
      message += '\n\nRecommendations:\n$cleanRecommendations';
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
      scanSessionId: scanSessionId,
      isRead: false,
      threatReportStatus: reportStatus,
    );
    
    _alerts.insert(0, alert);
    _persistAlerts(); // CRITICAL: Persist alerts immediately
    notifyListeners();
  }
  
  void generateScanSummaryAlert(int totalNetworks, int threatsDetected, DateTime scanTime, {int? scanSessionId}) {
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
      scanSessionId: scanSessionId,
      isRead: false,
    );
    
    _alerts.insert(0, alert);
    _persistAlerts(); // CRITICAL: Persist alerts immediately
    notifyListeners();
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void markAsRead(String alertId) {
    final index = _alerts.indexWhere((alert) => alert.id == alertId);
    if (index != -1) {
      _alerts[index].isRead = true;
      _persistAlerts(); // Persist read state changes
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var alert in _alerts) {
      alert.isRead = true;
    }
    _persistAlerts(); // Persist all read state changes
    notifyListeners();
  }

  void archiveAlert(String alertId) {
    final index = _alerts.indexWhere((alert) => alert.id == alertId);
    if (index != -1) {
      final alert = _alerts.removeAt(index);
      alert.isArchived = true;
      _archivedAlerts.insert(0, alert);
      _persistAlerts(); // Persist archive changes
      notifyListeners();
    }
  }

  void deleteAlert(String alertId) {
    _alerts.removeWhere((alert) => alert.id == alertId);
    _archivedAlerts.removeWhere((alert) => alert.id == alertId);
    _persistAlerts(); // Persist deletion changes
    notifyListeners();
  }

  void clearAllAlerts() {
    _alerts.clear();
    _archivedAlerts.clear();
    _persistAlerts(); // Persist clear operation
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

  /// Update threat report status for an alert
  void updateThreatReportStatus(String alertId, ThreatReportStatus status) {
    final index = _alerts.indexWhere((alert) => alert.id == alertId);
    if (index != -1) {
      final alert = _alerts[index];
      _alerts[index].threatReportStatus = status;
      _persistAlerts(); // Persist status changes
      notifyListeners();
      
      if (status == ThreatReportStatus.reported) {
        developer.log('✅ THREAT REPORTED: ${alert.networkName} (${alert.macAddress}) - Alert $alertId marked as reported');
        developer.log('🚫 Future scans will show this network as already reported');
      } else {
        developer.log('📝 Updated threat report status for alert $alertId to $status');
      }
    }
  }

  /// Check if an alert can be reported
  bool canReportThreat(String alertId) {
    final alert = _alerts.firstWhere((a) => a.id == alertId);
    return alert.threatReportStatus == ThreatReportStatus.pending;
  }

  /// Get reportable alerts
  List<AlertModel> get reportableAlerts => _alerts
      .where((alert) => alert.threatReportStatus == ThreatReportStatus.pending)
      .toList();

  /// Clean up false positive alerts for hidden networks (called during initialization)
  Future<void> cleanupHiddenNetworkAlerts() async {
    final hiddenNetworkAlerts = _alerts.where((alert) => alert.networkName == 'Hidden Network').toList();
    
    if (hiddenNetworkAlerts.isNotEmpty) {
      developer.log('🧹 Found ${hiddenNetworkAlerts.length} false positive alerts for hidden networks - removing them');
      
      for (final alert in hiddenNetworkAlerts) {
        _alerts.remove(alert);
        developer.log('   - Removed alert ${alert.id} for hidden network (MAC: ${alert.macAddress})');
      }
      
      await _persistAlerts();
      notifyListeners();
      developer.log('✅ Cleaned up ${hiddenNetworkAlerts.length} false positive hidden network alerts');
    }
  }

  /// Generate special alert for auto-blocked networks
  void generateAutoBlockAlert(NetworkModel network, {int? scanSessionId}) {
    final alertId = 'alert_auto_blocked_${DateTime.now().millisecondsSinceEpoch}';
    
    final alert = AlertModel(
      id: alertId,
      type: AlertType.networkBlocked,
      title: 'Auto-Blocked Suspicious Network',
      message: 'Network "${network.name}" was automatically blocked due to suspicious activity. It has been hidden from scan results and added to your blocked networks list in Access Point Manager.',
      severity: AlertSeverity.high,
      networkName: network.name,
      securityType: network.securityType.toString().split('.').last,
      macAddress: network.macAddress,
      location: network.latitude != null && network.longitude != null
          ? 'Lat: ${network.latitude!.toStringAsFixed(4)}, Lng: ${network.longitude!.toStringAsFixed(4)}'
          : 'Location unavailable',
      timestamp: DateTime.now(),
      scanSessionId: scanSessionId,
      isRead: false,
    );
    
    _alerts.insert(0, alert);
    _persistAlerts();
    notifyListeners();
    
    developer.log('🚨 Generated auto-block alert for ${network.name} (MAC: ${network.macAddress})');
  }
}