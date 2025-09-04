import 'package:cloud_firestore/cloud_firestore.dart';
import 'alert_model.dart';
import 'network_model.dart';

/// Enhanced threat alert model with reporting capabilities
class ThreatAlert extends AlertModel {
  final String scanHistoryId;
  final double? confidenceScore;
  final List<String>? threatIndicators;
  final bool canReport;
  final String reportSuggestion;
  final NetworkModel? suspiciousNetwork;
  final NetworkModel? legitimateNetwork;
  final List<NetworkModel> contextNetworks;
  
  ThreatAlert({
    required super.id,
    required super.type,
    required super.title,
    required super.message,
    required super.severity,
    required super.timestamp,
    required this.scanHistoryId,
    super.networkName,
    super.securityType,
    super.macAddress,
    super.location,
    super.isRead,
    super.isArchived,
    this.confidenceScore,
    this.threatIndicators,
    this.canReport = false,
    this.reportSuggestion = '',
    this.suspiciousNetwork,
    this.legitimateNetwork,
    this.contextNetworks = const [],
  });
  
  factory ThreatAlert.fromAlert({
    required AlertModel alert,
    required String scanHistoryId,
    double? confidenceScore,
    List<String>? threatIndicators,
    bool canReport = false,
    String reportSuggestion = '',
    NetworkModel? suspiciousNetwork,
    NetworkModel? legitimateNetwork,
    List<NetworkModel> contextNetworks = const [],
  }) {
    return ThreatAlert(
      id: alert.id,
      type: alert.type,
      title: alert.title,
      message: alert.message,
      severity: alert.severity,
      timestamp: alert.timestamp,
      networkName: alert.networkName,
      securityType: alert.securityType,
      macAddress: alert.macAddress,
      location: alert.location,
      isRead: alert.isRead,
      isArchived: alert.isArchived,
      scanHistoryId: scanHistoryId,
      confidenceScore: confidenceScore,
      threatIndicators: threatIndicators,
      canReport: canReport,
      reportSuggestion: reportSuggestion,
      suspiciousNetwork: suspiciousNetwork,
      legitimateNetwork: legitimateNetwork,
      contextNetworks: contextNetworks,
    );
  }
  
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'scanHistoryId': scanHistoryId,
      'confidenceScore': confidenceScore,
      'threatIndicators': threatIndicators,
      'canReport': canReport,
      'reportSuggestion': reportSuggestion,
      'suspiciousNetwork': suspiciousNetwork?.toJson(),
      'legitimateNetwork': legitimateNetwork?.toJson(),
      'contextNetworks': contextNetworks.map((n) => n.toJson()).toList(),
    });
    return json;
  }
  
  factory ThreatAlert.fromJson(Map<String, dynamic> json) {
    final alert = AlertModel.fromJson(json);
    
    return ThreatAlert(
      id: alert.id,
      type: alert.type,
      title: alert.title,
      message: alert.message,
      severity: alert.severity,
      timestamp: alert.timestamp,
      networkName: alert.networkName,
      securityType: alert.securityType,
      macAddress: alert.macAddress,
      location: alert.location,
      isRead: alert.isRead,
      isArchived: alert.isArchived,
      scanHistoryId: json['scanHistoryId'] ?? '',
      confidenceScore: json['confidenceScore']?.toDouble(),
      threatIndicators: json['threatIndicators']?.cast<String>(),
      canReport: json['canReport'] ?? false,
      reportSuggestion: json['reportSuggestion'] ?? '',
      suspiciousNetwork: json['suspiciousNetwork'] != null 
          ? NetworkModel.fromJson(json['suspiciousNetwork'])
          : null,
      legitimateNetwork: json['legitimateNetwork'] != null 
          ? NetworkModel.fromJson(json['legitimateNetwork'])
          : null,
      contextNetworks: (json['contextNetworks'] as List<dynamic>?)
          ?.map((n) => NetworkModel.fromJson(n))
          .toList() ?? [],
    );
  }
  
  /// Check if this threat is suitable for reporting
  bool get isSuitableForReporting {
    return canReport && 
           (confidenceScore ?? 0.0) >= 0.6 && 
           severity.index >= AlertSeverity.medium.index;
  }
  
  /// Get reporting urgency level
  String get reportingUrgency {
    switch (severity) {
      case AlertSeverity.critical:
        return 'immediate';
      case AlertSeverity.high:
        return 'urgent';
      case AlertSeverity.medium:
        return 'standard';
      case AlertSeverity.low:
        return 'low_priority';
    }
  }
  
  /// Get threat type display name
  String get threatTypeDisplayName {
    switch (type) {
      case AlertType.evilTwin:
        return 'Evil Twin Attack';
      case AlertType.suspiciousNetwork:
        return 'Suspicious Network';
      case AlertType.networkBlocked:
        return 'Unauthorized Access Point';
      case AlertType.networkTrusted:
        return 'Network Security Issue';
      default:
        return 'Security Threat';
    }
  }
  
  /// Generate evidence summary for reporting
  String get evidenceSummary {
    final evidence = <String>[];
    
    if (confidenceScore != null) {
      evidence.add('Confidence: ${(confidenceScore! * 100).toInt()}%');
    }
    
    if (threatIndicators != null && threatIndicators!.isNotEmpty) {
      evidence.add('Indicators: ${threatIndicators!.join(', ')}');
    }
    
    if (suspiciousNetwork != null) {
      evidence.add('Network: ${suspiciousNetwork!.name} (${suspiciousNetwork!.macAddress})');
      evidence.add('Security: ${suspiciousNetwork!.securityTypeString}');
      evidence.add('Signal: ${suspiciousNetwork!.signalStrength}%');
    }
    
    return evidence.join('\n');
  }
}

/// Threat report submission result
class ThreatReportResult {
  final bool success;
  final String? reportId;
  final String? errorMessage;
  final DateTime timestamp;
  
  ThreatReportResult({
    required this.success,
    this.reportId,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  factory ThreatReportResult.success(String reportId) {
    return ThreatReportResult(
      success: true,
      reportId: reportId,
    );
  }
  
  factory ThreatReportResult.failure(String errorMessage) {
    return ThreatReportResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

/// Threat report status tracking
class ThreatReportStatus {
  final String reportId;
  final String status;
  final String? assignedTo;
  final String? priority;
  final List<String> notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  
  ThreatReportStatus({
    required this.reportId,
    required this.status,
    this.assignedTo,
    this.priority,
    this.notes = const [],
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
  });
  
  factory ThreatReportStatus.fromFirestore(Map<String, dynamic> data) {
    final investigation = data['investigation'] as Map<String, dynamic>? ?? {};
    
    return ThreatReportStatus(
      reportId: data['id'] ?? '',
      status: investigation['status'] ?? 'pending',
      assignedTo: investigation['assignedTo'],
      priority: investigation['priority'],
      notes: (investigation['notes'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: (investigation['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (investigation['updatedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (investigation['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }
  
  /// Get status display name
  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Under Review';
      case 'investigating':
        return 'Being Investigated';
      case 'resolved':
        return 'Resolved';
      case 'false_positive':
        return 'False Positive';
      default:
        return 'Unknown Status';
    }
  }
  
  /// Check if report is still active
  bool get isActive {
    return status != 'resolved' && status != 'false_positive';
  }
  
  /// Get priority display name
  String get priorityDisplayName {
    switch (priority) {
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High Priority';
      case 'medium':
        return 'Medium Priority';
      case 'low':
        return 'Low Priority';
      default:
        return 'Standard';
    }
  }
}