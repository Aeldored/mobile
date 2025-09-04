enum AlertType { critical, warning, info, evilTwin, suspiciousNetwork, networkBlocked, networkTrusted, reportSuggestion }

enum AlertSeverity { low, medium, high, critical }

enum ThreatReportStatus { 
  notApplicable,  // For alerts that don't need reporting
  pending,        // Can be reported
  reported,       // Has been reported
  failed          // Report attempt failed
}

class AlertModel {
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final AlertSeverity severity;
  final String? networkName;
  final String? securityType;
  final String? macAddress;
  final String? location;
  final DateTime timestamp;
  final int? scanSessionId; // Track which scan session generated this alert
  bool isRead;
  bool isArchived;
  ThreatReportStatus threatReportStatus;

  AlertModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    this.networkName,
    this.securityType,
    this.macAddress,
    this.location,
    required this.timestamp,
    this.scanSessionId,
    this.isRead = false,
    this.isArchived = false,
    this.threatReportStatus = ThreatReportStatus.notApplicable,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'],
      type: AlertType.values.firstWhere(
        (e) => e.toString() == 'AlertType.${json['type']}',
      ),
      title: json['title'],
      message: json['message'],
      severity: AlertSeverity.values.firstWhere(
        (e) => e.toString() == 'AlertSeverity.${json['severity']}',
      ),
      networkName: json['networkName'],
      securityType: json['securityType'],
      macAddress: json['macAddress'],
      location: json['location'],
      timestamp: DateTime.parse(json['timestamp']),
      scanSessionId: json['scanSessionId'],
      isRead: json['isRead'] ?? false,
      isArchived: json['isArchived'] ?? false,
      threatReportStatus: json['threatReportStatus'] != null
          ? ThreatReportStatus.values.firstWhere(
              (e) => e.toString() == 'ThreatReportStatus.${json['threatReportStatus']}',
              orElse: () => ThreatReportStatus.notApplicable,
            )
          : ThreatReportStatus.notApplicable,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'severity': severity.toString().split('.').last,
      'networkName': networkName,
      'securityType': securityType,
      'macAddress': macAddress,
      'location': location,
      'timestamp': timestamp.toIso8601String(),
      'scanSessionId': scanSessionId,
      'isRead': isRead,
      'isArchived': isArchived,
      'threatReportStatus': threatReportStatus.toString().split('.').last,
    };
  }
}