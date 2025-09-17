import 'dart:developer' as developer;
import '../models/network_model.dart';
import '../models/security_assessment.dart';
import '../models/alert_model.dart';
import '../models/scan_history_model.dart';
import 'scan_history_service.dart';

/// Service for automatically gathering data for threat reports
class AutoReportDataService {
  final ScanHistoryService _scanHistoryService;
  
  AutoReportDataService(this._scanHistoryService);
  
  /// Generate comprehensive report data for a suspicious network
  Future<ReportData> generateReportDataForNetwork(
    NetworkModel network, {
    AlertModel? sourceAlert,
  }) async {
    try {
      developer.log('🔍 Generating auto-report data for network: ${network.name}');
      
      // Find recent scan entries containing this network
      final recentScans = _findRecentScansWithNetwork(network);
      
      // Gather network context from scan history
      final networkContext = _gatherNetworkContext(network, recentScans);
      
      // Generate threat analysis based on network characteristics
      final threatAnalysis = _analyzeThreatCharacteristics(network, networkContext);
      
      // Create suggested report content
      final suggestedContent = _generateSuggestedContent(
        network, 
        threatAnalysis, 
        networkContext,
        sourceAlert,
      );
      
      return ReportData(
        network: network,
        sourceAlert: sourceAlert,
        networkContext: networkContext,
        threatAnalysis: threatAnalysis,
        suggestedTitle: suggestedContent.title,
        suggestedDescription: suggestedContent.description,
        suggestedSeverity: suggestedContent.severity,
        suggestedThreatType: suggestedContent.threatType,
        contextualEvidence: suggestedContent.evidence,
        relatedNetworks: networkContext.nearbyNetworks,
        scanHistory: recentScans,
      );
    } catch (e) {
      developer.log('❌ Error generating auto-report data: $e');
      // Return minimal data if something fails
      return ReportData.minimal(network, sourceAlert);
    }
  }
  
  /// Find recent scan entries that contain the specified network
  List<ScanHistoryEntry> _findRecentScansWithNetwork(NetworkModel network) {
    final recentLimit = DateTime.now().subtract(const Duration(days: 7));
    
    return _scanHistoryService.history
        .where((entry) => 
          entry.timestamp.isAfter(recentLimit) &&
          entry.networkSummaries.any((n) => 
            n.macAddress == network.macAddress || 
            n.ssid == network.name
          ))
        .take(5) // Last 5 relevant scans
        .toList();
  }
  
  /// Gather contextual information about the network
  NetworkContext _gatherNetworkContext(NetworkModel network, List<ScanHistoryEntry> scans) {
    final allNetworkSummaries = <NetworkSummary>[];
    final scanTimes = <DateTime>[];
    final locations = <String>[];
    
    for (final scan in scans) {
      scanTimes.add(scan.timestamp);
      if (scan.location != null) locations.add(scan.location!);
      allNetworkSummaries.addAll(scan.networkSummaries);
    }
    
    // Find networks with similar names (potential Evil Twin indicators)
    final similarNameSummaries = allNetworkSummaries
        .where((n) => 
          n.macAddress != network.macAddress && 
          _isSimilarNetworkName(n.ssid, network.name))
        .toSet()
        .toList();
    
    // Convert summaries back to NetworkModels for compatibility
    final similarNameNetworks = similarNameSummaries
        .map((summary) => _networkSummaryToModel(summary))
        .toList();
    
    // For nearby networks, we'll use a subset since NetworkSummary doesn't have location
    final nearbyNetworks = <NetworkModel>[];
    
    // Calculate frequency of detection
    final detectionCount = scans.length;
    final firstSeen = scanTimes.isEmpty ? network.lastSeen : 
        scanTimes.reduce((a, b) => a.isBefore(b) ? a : b);
    
    return NetworkContext(
      detectionFrequency: detectionCount,
      firstDetected: firstSeen,
      lastDetected: scanTimes.isEmpty ? network.lastSeen :
          scanTimes.reduce((a, b) => a.isAfter(b) ? a : b),
      locations: locations.toSet().toList(),
      similarNameNetworks: similarNameNetworks,
      nearbyNetworks: nearbyNetworks,
      totalScansAnalyzed: scans.length,
    );
  }
  
  /// Analyze threat characteristics of the network
  ThreatAnalysis _analyzeThreatCharacteristics(NetworkModel network, NetworkContext context) {
    final threatIndicators = <String>[];
    final riskFactors = <String>[];
    double confidenceScore = 0.3; // Base confidence
    
    // Analyze security type vs typical networks
    if (network.securityType == SecurityType.open && 
        network.name.toLowerCase().contains('wifi') ||
        network.name.toLowerCase().contains('internet') ||
        network.name.toLowerCase().contains('free')) {
      threatIndicators.add('Open security on public-sounding network name');
      riskFactors.add('Potential honeypot or malicious hotspot');
      confidenceScore += 0.2;
    }
    
    // Check for Evil Twin patterns
    if (context.similarNameNetworks.isNotEmpty) {
      threatIndicators.add('Similar network names detected (${context.similarNameNetworks.length} variants)');
      riskFactors.add('Possible Evil Twin attack - multiple networks with similar names');
      confidenceScore += 0.3;
    }
    
    // Analyze signal strength patterns
    if (network.signalStrength > 90) {
      threatIndicators.add('Unusually strong signal strength (${network.signalStrength}%)');
      riskFactors.add('May indicate proximity-based attack or signal amplification');
      confidenceScore += 0.1;
    }
    
    // Check MAC address patterns
    if (_isSuspiciousMacAddress(network.macAddress)) {
      threatIndicators.add('Suspicious MAC address pattern');
      riskFactors.add('Locally administered MAC may indicate spoofing');
      confidenceScore += 0.15;
    }
    
    // Frequency analysis
    if (context.detectionFrequency == 1) {
      riskFactors.add('Network appeared only once (potential temporary setup)');
      confidenceScore += 0.1;
    } else if (context.detectionFrequency > 5) {
      riskFactors.add('Network frequently detected (${context.detectionFrequency} times)');
    }
    
    // Network status consideration
    if (network.status == NetworkStatus.suspicious) {
      threatIndicators.add('Flagged as suspicious by security analysis');
      confidenceScore += 0.2;
    }
    
    return ThreatAnalysis(
      confidenceScore: confidenceScore.clamp(0.0, 1.0),
      threatIndicators: threatIndicators,
      riskFactors: riskFactors,
      severityEstimate: _estimateSeverity(confidenceScore, threatIndicators.length),
      recommendedAction: _getRecommendedAction(confidenceScore, network),
    );
  }
  
  /// Generate suggested content for the threat report
  SuggestedContent _generateSuggestedContent(
    NetworkModel network, 
    ThreatAnalysis analysis, 
    NetworkContext context,
    AlertModel? sourceAlert,
  ) {
    final title = sourceAlert?.title.replaceAll(' - Report Recommended', '') ??
                 _generateTitleFromAnalysis(network, analysis);
    
    final description = _generateDescriptionFromAnalysis(network, analysis, context);
    
    final evidence = [
      'Network Details:',
      '• Name: ${network.name}',
      '• MAC Address: ${network.macAddress}',
      '• Security: ${network.securityTypeString}',
      '• Signal Strength: ${network.signalStrength}%',
      '• Status: ${network.statusDisplayName}',
      if (network.displayLocation != 'Unknown location')
        '• Location: ${network.displayLocation}',
      '',
      'Detection History:',
      '• First Detected: ${_formatDateTime(context.firstDetected)}',
      '• Last Seen: ${_formatDateTime(context.lastDetected)}',
      '• Detection Frequency: ${context.detectionFrequency} times',
      if (context.locations.isNotEmpty)
        '• Locations: ${context.locations.join(', ')}',
      '',
      'Threat Analysis:',
      ...analysis.threatIndicators.map((i) => '• $i'),
      '',
      'Risk Assessment:',
      ...analysis.riskFactors.map((r) => '• $r'),
      '',
      'Confidence Score: ${(analysis.confidenceScore * 100).toInt()}%',
    ];
    
    return SuggestedContent(
      title: title,
      description: description,
      severity: analysis.severityEstimate,
      threatType: _getThreatTypeFromAnalysis(analysis),
      evidence: evidence,
    );
  }
  
  String _generateTitleFromAnalysis(NetworkModel network, ThreatAnalysis analysis) {
    if (analysis.threatIndicators.any((i) => i.contains('Evil Twin'))) {
      return 'Potential Evil Twin Attack: ${network.name}';
    } else if (analysis.threatIndicators.any((i) => i.contains('Open security'))) {
      return 'Suspicious Open Network: ${network.name}';
    } else if (network.signalStrength > 90) {
      return 'Suspicious High-Power Network: ${network.name}';
    } else {
      return 'Security Threat: ${network.name}';
    }
  }
  
  String _generateDescriptionFromAnalysis(
    NetworkModel network, 
    ThreatAnalysis analysis, 
    NetworkContext context
  ) {
    final description = StringBuffer();
    
    description.writeln('Suspicious network activity detected:');
    description.writeln();
    
    if (analysis.threatIndicators.isNotEmpty) {
      description.writeln('Primary Concerns:');
      for (final indicator in analysis.threatIndicators) {
        description.writeln('- $indicator');
      }
      description.writeln();
    }
    
    if (analysis.riskFactors.isNotEmpty) {
      description.writeln('Risk Factors:');
      for (final factor in analysis.riskFactors) {
        description.writeln('- $factor');
      }
      description.writeln();
    }
    
    description.writeln('Recommendation: ${analysis.recommendedAction}');
    
    return description.toString().trim();
  }
  
  // Helper methods
  bool _isSimilarNetworkName(String name1, String name2) {
    final clean1 = name1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final clean2 = name2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    
    // Check for exact match after cleaning
    if (clean1 == clean2) return true;
    
    // Check for similar patterns (common Evil Twin technique)
    if (clean1.length == clean2.length) {
      int differences = 0;
      for (int i = 0; i < clean1.length; i++) {
        if (clean1[i] != clean2[i]) differences++;
      }
      return differences <= 2; // Allow up to 2 character differences
    }
    
    return false;
  }
  
  
  bool _isSuspiciousMacAddress(String macAddress) {
    // Check for locally administered MAC (2nd least significant bit of first octet is 1)
    if (macAddress.length >= 2) {
      final firstByte = int.tryParse(macAddress.substring(0, 2), radix: 16);
      if (firstByte != null && (firstByte & 0x02) != 0) {
        return true;
      }
    }
    return false;
  }
  
  AlertSeverity _estimateSeverity(double confidence, int indicatorCount) {
    if (confidence >= 0.8 || indicatorCount >= 4) {
      return AlertSeverity.critical;
    } else if (confidence >= 0.6 || indicatorCount >= 3) {
      return AlertSeverity.high;
    } else if (confidence >= 0.4 || indicatorCount >= 2) {
      return AlertSeverity.medium;
    } else {
      return AlertSeverity.low;
    }
  }
  
  String _getRecommendedAction(double confidence, NetworkModel network) {
    if (confidence >= 0.8) {
      return 'Immediate reporting recommended - high confidence threat detected';
    } else if (confidence >= 0.6) {
      return 'Report this network to security team for investigation';
    } else if (network.status == NetworkStatus.suspicious) {
      return 'Monitor this network and report if suspicious activity continues';
    } else {
      return 'Consider reporting if you observe any malicious behavior';
    }
  }
  
  AlertType _getThreatTypeFromAnalysis(ThreatAnalysis analysis) {
    if (analysis.threatIndicators.any((i) => i.contains('Evil Twin'))) {
      return AlertType.evilTwin;
    } else {
      return AlertType.suspiciousNetwork;
    }
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  /// Convert NetworkSummary to NetworkModel for compatibility
  NetworkModel _networkSummaryToModel(NetworkSummary summary) {
    return NetworkModel(
      id: 'summary_${summary.ssid}_${summary.macAddress ?? 'unknown'}',
      name: summary.ssid,
      description: 'Network from scan history',
      status: summary.status,
      securityType: _parseSecurityType(summary.securityType),
      signalStrength: summary.signalStrength,
      macAddress: summary.macAddress ?? '00:00:00:00:00:00',
      lastSeen: DateTime.now(),
      isConnected: summary.isCurrentNetwork,
    );
  }
  
  /// Parse security type string back to SecurityType enum
  SecurityType _parseSecurityType(String securityTypeString) {
    switch (securityTypeString.toLowerCase()) {
      case 'wpa2':
        return SecurityType.wpa2;
      case 'wpa3':
        return SecurityType.wpa3;
      case 'wep':
        return SecurityType.wep;
      case 'open':
        return SecurityType.open;
      default:
        return SecurityType.open;
    }
  }
}

/// Container for all auto-generated report data
class ReportData {
  final NetworkModel network;
  final AlertModel? sourceAlert;
  final NetworkContext networkContext;
  final ThreatAnalysis threatAnalysis;
  final String suggestedTitle;
  final String suggestedDescription;
  final AlertSeverity suggestedSeverity;
  final AlertType suggestedThreatType;
  final List<String> contextualEvidence;
  final List<NetworkModel> relatedNetworks;
  final List<ScanHistoryEntry> scanHistory;
  
  ReportData({
    required this.network,
    this.sourceAlert,
    required this.networkContext,
    required this.threatAnalysis,
    required this.suggestedTitle,
    required this.suggestedDescription,
    required this.suggestedSeverity,
    required this.suggestedThreatType,
    required this.contextualEvidence,
    required this.relatedNetworks,
    required this.scanHistory,
  });
  
  /// Create minimal report data when auto-generation fails
  factory ReportData.minimal(NetworkModel network, AlertModel? sourceAlert) {
    return ReportData(
      network: network,
      sourceAlert: sourceAlert,
      networkContext: NetworkContext.empty(),
      threatAnalysis: ThreatAnalysis.minimal(),
      suggestedTitle: 'Security Threat: ${network.name}',
      suggestedDescription: 'Suspicious network detected requiring investigation.',
      suggestedSeverity: AlertSeverity.medium,
      suggestedThreatType: AlertType.suspiciousNetwork,
      contextualEvidence: [
        'Network: ${network.name}',
        'MAC Address: ${network.macAddress}',
        'Security Type: ${network.securityTypeString}',
      ],
      relatedNetworks: [],
      scanHistory: [],
    );
  }
}

/// Network context gathered from scan history
class NetworkContext {
  final int detectionFrequency;
  final DateTime firstDetected;
  final DateTime lastDetected;
  final List<String> locations;
  final List<NetworkModel> similarNameNetworks;
  final List<NetworkModel> nearbyNetworks;
  final int totalScansAnalyzed;
  
  NetworkContext({
    required this.detectionFrequency,
    required this.firstDetected,
    required this.lastDetected,
    required this.locations,
    required this.similarNameNetworks,
    required this.nearbyNetworks,
    required this.totalScansAnalyzed,
  });
  
  factory NetworkContext.empty() {
    final now = DateTime.now();
    return NetworkContext(
      detectionFrequency: 1,
      firstDetected: now,
      lastDetected: now,
      locations: [],
      similarNameNetworks: [],
      nearbyNetworks: [],
      totalScansAnalyzed: 0,
    );
  }
}

/// Threat analysis results
class ThreatAnalysis {
  final double confidenceScore;
  final List<String> threatIndicators;
  final List<String> riskFactors;
  final AlertSeverity severityEstimate;
  final String recommendedAction;
  
  ThreatAnalysis({
    required this.confidenceScore,
    required this.threatIndicators,
    required this.riskFactors,
    required this.severityEstimate,
    required this.recommendedAction,
  });
  
  factory ThreatAnalysis.minimal() {
    return ThreatAnalysis(
      confidenceScore: 0.5,
      threatIndicators: ['Network flagged for suspicious activity'],
      riskFactors: ['Requires manual investigation'],
      severityEstimate: AlertSeverity.medium,
      recommendedAction: 'Report for security analysis',
    );
  }
}

/// Suggested content for the threat report
class SuggestedContent {
  final String title;
  final String description;
  final AlertSeverity severity;
  final AlertType threatType;
  final List<String> evidence;
  
  SuggestedContent({
    required this.title,
    required this.description,
    required this.severity,
    required this.threatType,
    required this.evidence,
  });
}