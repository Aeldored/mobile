/// Threat level enumeration for security assessment
enum ThreatLevel { 
  low, 
  medium, 
  high, 
  critical;

  /// Get color representation for UI
  String get colorCode {
    switch (this) {
      case ThreatLevel.low:
        return '#4CAF50'; // Green
      case ThreatLevel.medium:
        return '#FF9800'; // Orange
      case ThreatLevel.high:
        return '#F44336'; // Red
      case ThreatLevel.critical:
        return '#9C27B0'; // Purple
    }
  }

  /// Get display name
  String get displayName {
    switch (this) {
      case ThreatLevel.low:
        return 'Low Risk';
      case ThreatLevel.medium:
        return 'Medium Risk';
      case ThreatLevel.high:
        return 'High Risk';
      case ThreatLevel.critical:
        return 'Critical Risk';
    }
  }

  /// Get security advice
  String get securityAdvice {
    switch (this) {
      case ThreatLevel.low:
        return 'Safe to connect with standard precautions';
      case ThreatLevel.medium:
        return 'Proceed with caution - use VPN recommended';
      case ThreatLevel.high:
        return 'High risk - avoid connecting if possible';
      case ThreatLevel.critical:
        return 'DO NOT CONNECT - Critical security threat detected';
    }
  }
}

/// Security threat type enumeration
enum ThreatType {
  evilTwin,
  signalAnomaly,
  securityDowngrade,
  suspiciousMac,
  historicalAnomaly,
  timingAnomaly,
  certificateInvalid,
  unknownThreat;

  /// Get display name for threat type
  String get displayName {
    switch (this) {
      case ThreatType.evilTwin:
        return 'Evil Twin Attack';
      case ThreatType.signalAnomaly:
        return 'Signal Anomaly';
      case ThreatType.securityDowngrade:
        return 'Security Downgrade';
      case ThreatType.suspiciousMac:
        return 'Suspicious Hardware';
      case ThreatType.historicalAnomaly:
        return 'Unusual Network Behavior';
      case ThreatType.timingAnomaly:
        return 'Timing Pattern Anomaly';
      case ThreatType.certificateInvalid:
        return 'Invalid Certificate';
      case ThreatType.unknownThreat:
        return 'Unknown Threat';
    }
  }

  /// Get emoji icon for threat type
  String get icon {
    switch (this) {
      case ThreatType.evilTwin:
        return '🎭';
      case ThreatType.signalAnomaly:
        return '';
      case ThreatType.securityDowngrade:
        return '🔓';
      case ThreatType.suspiciousMac:
        return '🔧';
      case ThreatType.historicalAnomaly:
        return '📊';
      case ThreatType.timingAnomaly:
        return '⏰';
      case ThreatType.certificateInvalid:
        return '🔐';
      case ThreatType.unknownThreat:
        return '❓';
    }
  }
}

/// Threat severity enumeration
enum ThreatSeverity {
  low,
  medium,
  high,
  critical;

  /// Get numerical value for comparison
  int get value {
    switch (this) {
      case ThreatSeverity.low:
        return 1;
      case ThreatSeverity.medium:
        return 2;
      case ThreatSeverity.high:
        return 3;
      case ThreatSeverity.critical:
        return 4;
    }
  }
}

/// Individual security threat detected during analysis
class SecurityThreat {
  final ThreatType type;
  final ThreatSeverity severity;
  final String description;
  final List<String> details;
  final String affectedSSID;
  final String? suspiciousBSSID;
  final double confidenceScore; // 0.0 to 1.0
  final DateTime detectedAt;
  final Map<String, dynamic>? additionalData;

  SecurityThreat({
    required this.type,
    required this.severity,
    required this.description,
    required this.details,
    required this.affectedSSID,
    this.suspiciousBSSID,
    required this.confidenceScore,
    DateTime? detectedAt,
    this.additionalData,
  }) : detectedAt = detectedAt ?? DateTime.now();

  /// Get threat priority for sorting (higher = more critical)
  int get priority => severity.value * 100 + (confidenceScore * 100).round();

  /// Check if threat is actionable (high confidence and severity)
  bool get isActionable => confidenceScore >= 0.6 && severity.value >= 2;

  /// Get user-friendly threat summary
  String get summary => '${type.icon} ${type.displayName}: $description';

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'severity': severity.toString(),
      'description': description,
      'details': details,
      'affectedSSID': affectedSSID,
      'suspiciousBSSID': suspiciousBSSID,
      'confidenceScore': confidenceScore,
      'detectedAt': detectedAt.toIso8601String(),
      'additionalData': additionalData,
    };
  }

  /// Create from map
  static SecurityThreat fromMap(Map<String, dynamic> map) {
    return SecurityThreat(
      type: ThreatType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => ThreatType.unknownThreat,
      ),
      severity: ThreatSeverity.values.firstWhere(
        (e) => e.toString() == map['severity'],
        orElse: () => ThreatSeverity.low,
      ),
      description: map['description'] ?? '',
      details: List<String>.from(map['details'] ?? []),
      affectedSSID: map['affectedSSID'] ?? '',
      suspiciousBSSID: map['suspiciousBSSID'],
      confidenceScore: (map['confidenceScore'] ?? 0.0).toDouble(),
      detectedAt: DateTime.tryParse(map['detectedAt'] ?? '') ?? DateTime.now(),
      additionalData: map['additionalData'],
    );
  }
}

/// Comprehensive security assessment for a network
class SecurityAssessment {
  final String networkId; // Usually BSSID
  final String ssid;
  final ThreatLevel threatLevel;
  final double confidenceScore; // 0.0 to 1.0
  final List<SecurityThreat> detectedThreats;
  final Map<String, dynamic> networkFingerprint;
  final bool isKnownLegitimate;
  final List<String> recommendations;
  final DateTime analysisTimestamp;
  final String? errorMessage;

  SecurityAssessment({
    required this.networkId,
    required this.ssid,
    required this.threatLevel,
    required this.confidenceScore,
    required this.detectedThreats,
    required this.networkFingerprint,
    required this.isKnownLegitimate,
    required this.recommendations,
    DateTime? analysisTimestamp,
    this.errorMessage,
  }) : analysisTimestamp = analysisTimestamp ?? DateTime.now();

  /// Create error assessment
  factory SecurityAssessment.createError(String networkId, String ssid, String error) {
    return SecurityAssessment(
      networkId: networkId,
      ssid: ssid,
      threatLevel: ThreatLevel.medium,
      confidenceScore: 0.0,
      detectedThreats: [],
      networkFingerprint: {},
      isKnownLegitimate: false,
      recommendations: ['Unable to perform security analysis', 'Proceed with standard caution'],
      errorMessage: error,
    );
  }

  /// Check if assessment indicates it's safe to connect
  bool get isSafeToConnect {
    return threatLevel == ThreatLevel.low || 
           (threatLevel == ThreatLevel.medium && isKnownLegitimate);
  }

  /// Check if assessment recommends avoiding connection
  bool get shouldAvoidConnection {
    return threatLevel == ThreatLevel.high || threatLevel == ThreatLevel.critical;
  }

  /// Get the most critical threat
  SecurityThreat? get mostCriticalThreat {
    if (detectedThreats.isEmpty) return null;
    
    detectedThreats.sort((a, b) => b.priority.compareTo(a.priority));
    return detectedThreats.first;
  }

  /// Get threat count by severity
  Map<ThreatSeverity, int> get threatCountBySeverity {
    final counts = <ThreatSeverity, int>{};
    for (final severity in ThreatSeverity.values) {
      counts[severity] = detectedThreats.where((t) => t.severity == severity).length;
    }
    return counts;
  }

  /// Get overall security score (0-100)
  int get securityScore {
    if (errorMessage != null) return 50; // Neutral score for errors
    
    var score = 100;
    
    // Deduct points based on threat level
    switch (threatLevel) {
      case ThreatLevel.low:
        score -= 10;
        break;
      case ThreatLevel.medium:
        score -= 30;
        break;
      case ThreatLevel.high:
        score -= 60;
        break;
      case ThreatLevel.critical:
        score -= 90;
        break;
    }
    
    // Deduct points for each threat
    for (final threat in detectedThreats) {
      score -= (threat.severity.value * 5);
    }
    
    // Add points for known legitimate networks
    if (isKnownLegitimate) {
      score += 20;
    }
    
    return score.clamp(0, 100);
  }

  /// Get security grade (A-F)
  String get securityGrade {
    final score = securityScore;
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  /// Get primary recommendation
  String get primaryRecommendation {
    if (recommendations.isNotEmpty) {
      return recommendations.first;
    }
    return threatLevel.securityAdvice;
  }

  /// Check if assessment is recent (within last 5 minutes)
  bool get isRecent {
    return DateTime.now().difference(analysisTimestamp).inMinutes < 5;
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'networkId': networkId,
      'ssid': ssid,
      'threatLevel': threatLevel.toString(),
      'confidenceScore': confidenceScore,
      'detectedThreats': detectedThreats.map((t) => t.toMap()).toList(),
      'networkFingerprint': networkFingerprint,
      'isKnownLegitimate': isKnownLegitimate,
      'recommendations': recommendations,
      'analysisTimestamp': analysisTimestamp.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  /// Create from map
  static SecurityAssessment fromMap(Map<String, dynamic> map) {
    return SecurityAssessment(
      networkId: map['networkId'] ?? '',
      ssid: map['ssid'] ?? '',
      threatLevel: ThreatLevel.values.firstWhere(
        (e) => e.toString() == map['threatLevel'],
        orElse: () => ThreatLevel.low,
      ),
      confidenceScore: (map['confidenceScore'] ?? 0.0).toDouble(),
      detectedThreats: (map['detectedThreats'] as List<dynamic>? ?? [])
          .map((t) => SecurityThreat.fromMap(t))
          .toList(),
      networkFingerprint: Map<String, dynamic>.from(map['networkFingerprint'] ?? {}),
      isKnownLegitimate: map['isKnownLegitimate'] ?? false,
      recommendations: List<String>.from(map['recommendations'] ?? []),
      analysisTimestamp: DateTime.tryParse(map['analysisTimestamp'] ?? '') ?? DateTime.now(),
      errorMessage: map['errorMessage'],
    );
  }

  @override
  String toString() {
    return 'SecurityAssessment(ssid: $ssid, level: $threatLevel, threats: ${detectedThreats.length}, score: $securityScore)';
  }
}

/// Security type enumeration for network analysis
enum SecurityType {
  open,
  wep,
  wpa2,
  wpa3;
  
  @override
  String toString() {
    switch (this) {
      case SecurityType.open:
        return 'Open';
      case SecurityType.wep:
        return 'WEP';
      case SecurityType.wpa2:
        return 'WPA2';
      case SecurityType.wpa3:
        return 'WPA3';
    }
  }
}

/// Trust level for MAC address vendors
enum TrustLevel {
  high,
  medium,
  low,
  critical,
}