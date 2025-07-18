import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:wifi_scan/wifi_scan.dart';
import '../models/network_model.dart';
import '../models/security_assessment.dart';

/// Comprehensive security analysis engine for Evil Twin detection and threat assessment
class SecurityAnalyzer {
  static final SecurityAnalyzer _instance = SecurityAnalyzer._internal();
  factory SecurityAnalyzer() => _instance;
  SecurityAnalyzer._internal();

  // Historical data for comparison analysis
  final Map<String, List<WiFiAccessPoint>> _networkHistory = {};
  final Map<String, NetworkFingerprint> _legitimateNetworks = {};
  final Set<String> _knownMaliciousMACs = {};
  
  // Real-time scanning data
  DateTime _lastScanTime = DateTime.now();

  /// Initialize security analyzer with baseline legitimate networks
  Future<void> initialize() async {
    try {
      developer.log('🛡️ Initializing SecurityAnalyzer with Evil Twin detection');
      
      // Load known legitimate network fingerprints
      await _loadLegitimateNetworkDatabase();
      
      // Initialize malicious MAC database
      _initializeMaliciousMACs();
      
      developer.log('✅ SecurityAnalyzer initialized successfully');
    } catch (e) {
      developer.log('❌ Failed to initialize SecurityAnalyzer: $e');
    }
  }

  /// Perform comprehensive security analysis on a network
  Future<SecurityAssessment> analyzeNetwork(
    WiFiAccessPoint target, 
    List<WiFiAccessPoint> allNetworks,
  ) async {
    try {
      developer.log('🔍 Analyzing network: ${target.ssid} (${target.bssid})');
      
      final threats = <SecurityThreat>[];
      var threatLevel = ThreatLevel.low;
      var confidenceScore = 0.0;

      // 1. Evil Twin Detection
      final evilTwinAnalysis = _detectEvilTwin(target, allNetworks);
      if (evilTwinAnalysis.isDetected && evilTwinAnalysis.threat != null) {
        threats.add(evilTwinAnalysis.threat!);
        threatLevel = ThreatLevel.high;
        confidenceScore += 0.4;
      }

      // 2. Signal Strength Anomaly Detection
      final signalAnomaly = _analyzeSignalAnomalies(target);
      if (signalAnomaly.isAnomalous && signalAnomaly.threat != null) {
        threats.add(signalAnomaly.threat!);
        threatLevel = _escalateThreatLevel(threatLevel, ThreatLevel.medium);
        confidenceScore += 0.2;
      }

      // 3. Security Configuration Analysis
      final securityAnalysis = _analyzeSecurityConfiguration(target);
      if (securityAnalysis.isSuspicious && securityAnalysis.threat != null) {
        threats.add(securityAnalysis.threat!);
        threatLevel = _escalateThreatLevel(threatLevel, ThreatLevel.medium);
        confidenceScore += 0.15;
      }

      // 4. MAC Address Pattern Analysis
      final macAnalysis = _analyzeMACAddress(target);
      if (macAnalysis.isSuspicious && macAnalysis.threat != null) {
        threats.add(macAnalysis.threat!);
        threatLevel = _escalateThreatLevel(threatLevel, ThreatLevel.medium);
        confidenceScore += 0.1;
      }

      // 5. Historical Comparison
      final historicalAnalysis = _compareWithHistory(target);
      if (historicalAnalysis.isAnomalous && historicalAnalysis.threat != null) {
        threats.add(historicalAnalysis.threat!);
        threatLevel = _escalateThreatLevel(threatLevel, ThreatLevel.medium);
        confidenceScore += 0.1;
      }

      // 6. Timing Pattern Analysis
      final timingAnalysis = _analyzeTimingPatterns(target);
      if (timingAnalysis.isSuspicious && timingAnalysis.threat != null) {
        threats.add(timingAnalysis.threat!);
        threatLevel = _escalateThreatLevel(threatLevel, ThreatLevel.low);
        confidenceScore += 0.05;
      }

      // Generate network fingerprint
      final fingerprint = _generateNetworkFingerprint(target);
      
      // Determine if network is known legitimate
      final isKnownLegitimate = _isKnownLegitimateNetwork(target);
      
      // Generate recommendations
      final recommendations = _generateSecurityRecommendations(
        threats, 
        threatLevel, 
        isKnownLegitimate,
      );

      developer.log('🛡️ Analysis complete: ${threats.length} threats, level: $threatLevel');

      return SecurityAssessment(
        networkId: target.bssid,
        ssid: target.ssid,
        threatLevel: threatLevel,
        confidenceScore: confidenceScore.clamp(0.0, 1.0),
        detectedThreats: threats,
        networkFingerprint: fingerprint.toMap(),
        isKnownLegitimate: isKnownLegitimate,
        recommendations: recommendations,
        analysisTimestamp: DateTime.now(),
      );

    } catch (e) {
      developer.log('❌ Security analysis failed: $e');
      return SecurityAssessment.createError(target.bssid, target.ssid, e.toString());
    }
  }

  /// Detect Evil Twin attacks by analyzing duplicate SSIDs
  EvilTwinAnalysisResult _detectEvilTwin(
    WiFiAccessPoint target, 
    List<WiFiAccessPoint> allNetworks,
  ) {
    try {
      // Find all networks with same SSID but different BSSID
      final duplicateSSIDs = allNetworks
          .where((ap) => 
              ap.ssid == target.ssid && 
              ap.bssid != target.bssid &&
              ap.ssid.isNotEmpty)
          .toList();

      if (duplicateSSIDs.isEmpty) {
        return EvilTwinAnalysisResult(isDetected: false);
      }

      developer.log('🚨 Found ${duplicateSSIDs.length} networks with same SSID: ${target.ssid}');

      // Analyze characteristics to determine which is likely malicious
      final suspiciousFactors = <String>[];
      var suspicionScore = 0.0;

      // Factor 1: Unusually strong signal (closer than expected)
      if (target.level > -30) {
        suspiciousFactors.add('Unusually strong signal strength (${target.level} dBm)');
        suspicionScore += 0.3;
      }

      // Factor 2: Open security when others are encrypted
      final targetIsOpen = !target.capabilities.contains('WPA') && 
                          !target.capabilities.contains('WEP');
      final othersEncrypted = duplicateSSIDs.any((ap) => 
          ap.capabilities.contains('WPA') || ap.capabilities.contains('WEP'));

      if (targetIsOpen && othersEncrypted) {
        suspiciousFactors.add('Open security while legitimate network is encrypted');
        suspicionScore += 0.4;
      }

      // Factor 3: MAC address vendor analysis
      if (_isSuspiciousMAC(target.bssid)) {
        suspiciousFactors.add('Suspicious MAC address pattern');
        suspicionScore += 0.2;
      }

      // Factor 4: Signal strength comparison with known legitimate
      final legitimateNetwork = _getLegitimateNetworkReference(target.ssid);
      if (legitimateNetwork != null) {
        final signalDifference = (target.level - legitimateNetwork.typicalSignalStrength).abs();
        if (signalDifference > 20) {
          suspiciousFactors.add('Signal strength differs significantly from known legitimate network');
          suspicionScore += 0.1;
        }
      }

      final isDetected = suspicionScore >= 0.3; // Threshold for Evil Twin detection

      if (isDetected) {
        return EvilTwinAnalysisResult(
          isDetected: true,
          threat: SecurityThreat(
            type: ThreatType.evilTwin,
            severity: suspicionScore >= 0.6 ? ThreatSeverity.critical : ThreatSeverity.high,
            description: 'Potential Evil Twin attack detected - multiple networks with same SSID',
            details: suspiciousFactors,
            affectedSSID: target.ssid,
            suspiciousBSSID: target.bssid,
            confidenceScore: suspicionScore,
          ),
        );
      }

      return EvilTwinAnalysisResult(isDetected: false);

    } catch (e) {
      developer.log('❌ Evil Twin detection failed: $e');
      return EvilTwinAnalysisResult(isDetected: false);
    }
  }

  /// Analyze signal strength for anomalies indicating proximity spoofing
  SignalAnomalyResult _analyzeSignalAnomalies(WiFiAccessPoint target) {
    try {
      final anomalies = <String>[];
      var isAnomalous = false;

      // Check for unusually strong signal (potential proximity attack)
      if (target.level > -20) {
        anomalies.add('Extremely strong signal (${target.level} dBm) - device may be very close');
        isAnomalous = true;
      }

      // Check signal strength consistency with historical data
      if (_networkHistory.containsKey(target.ssid)) {
        final historicalSignals = _networkHistory[target.ssid]!
            .where((ap) => ap.bssid == target.bssid)
            .map((ap) => ap.level)
            .toList();

        if (historicalSignals.isNotEmpty) {
          final averageSignal = historicalSignals.reduce((a, b) => a + b) / historicalSignals.length;
          final signalDeviation = (target.level - averageSignal).abs();

          if (signalDeviation > 30) {
            anomalies.add('Signal strength deviates significantly from historical pattern');
            isAnomalous = true;
          }
        }
      }

      if (isAnomalous) {
        return SignalAnomalyResult(
          isAnomalous: true,
          threat: SecurityThreat(
            type: ThreatType.signalAnomaly,
            severity: ThreatSeverity.medium,
            description: 'Signal strength anomaly detected',
            details: anomalies,
            affectedSSID: target.ssid,
            suspiciousBSSID: target.bssid,
            confidenceScore: 0.6,
          ),
        );
      }

      return SignalAnomalyResult(isAnomalous: false);

    } catch (e) {
      developer.log('❌ Signal anomaly analysis failed: $e');
      return SignalAnomalyResult(isAnomalous: false);
    }
  }

  /// Analyze security configuration for downgrade attacks
  SecurityConfigAnalysisResult _analyzeSecurityConfiguration(WiFiAccessPoint target) {
    try {
      final issues = <String>[];
      var isSuspicious = false;

      // Check for security downgrade compared to historical data
      if (_networkHistory.containsKey(target.ssid)) {
        final historicalAPs = _networkHistory[target.ssid]!;
        final previousSecurity = historicalAPs
            .where((ap) => ap.bssid == target.bssid)
            .map((ap) => _extractSecurityType(ap.capabilities))
            .toSet();

        final currentSecurity = _extractSecurityType(target.capabilities);

        // Check for downgrade (WPA3 -> WPA2 -> WPA -> Open)
        if (previousSecurity.contains(SecurityType.wpa3) && currentSecurity != SecurityType.wpa3) {
          issues.add('Security downgraded from WPA3 to ${currentSecurity.toString()}');
          isSuspicious = true;
        } else if (previousSecurity.contains(SecurityType.wpa2) && 
                   (currentSecurity == SecurityType.wep || currentSecurity == SecurityType.open)) {
          issues.add('Security downgraded from WPA2 to ${currentSecurity.toString()}');
          isSuspicious = true;
        }
      }

      // Check for suspicious open networks
      if (!target.capabilities.contains('WPA') && !target.capabilities.contains('WEP')) {
        if (_isLikelyToBeSecured(target.ssid)) {
          issues.add('Network expected to be secured but appears open');
          isSuspicious = true;
        }
      }

      if (isSuspicious) {
        return SecurityConfigAnalysisResult(
          isSuspicious: true,
          threat: SecurityThreat(
            type: ThreatType.securityDowngrade,
            severity: ThreatSeverity.medium,
            description: 'Suspicious security configuration detected',
            details: issues,
            affectedSSID: target.ssid,
            suspiciousBSSID: target.bssid,
            confidenceScore: 0.7,
          ),
        );
      }

      return SecurityConfigAnalysisResult(isSuspicious: false);

    } catch (e) {
      developer.log('❌ Security configuration analysis failed: $e');
      return SecurityConfigAnalysisResult(isSuspicious: false);
    }
  }

  /// Analyze MAC address for suspicious patterns
  MACAnalysisResult _analyzeMACAddress(WiFiAccessPoint target) {
    try {
      final issues = <String>[];
      var isSuspicious = false;

      // Check for known malicious MACs
      if (_knownMaliciousMACs.contains(target.bssid)) {
        issues.add('MAC address found in malicious network database');
        isSuspicious = true;
      }

      // Check for randomized MAC patterns (often used by malicious APs)
      if (target.bssid.startsWith('02:') || target.bssid.startsWith('06:') || 
          target.bssid.startsWith('0A:') || target.bssid.startsWith('0E:')) {
        issues.add('Locally administered MAC address (potentially randomized)');
        isSuspicious = true;
      }

      // Check for suspicious vendor patterns
      final macPrefix = target.bssid.substring(0, 8).toUpperCase();
      if (_isSuspiciousVendor(macPrefix)) {
        issues.add('MAC address from vendor commonly used in malicious devices');
        isSuspicious = true;
      }

      if (isSuspicious) {
        return MACAnalysisResult(
          isSuspicious: true,
          threat: SecurityThreat(
            type: ThreatType.suspiciousMac,
            severity: ThreatSeverity.low,
            description: 'Suspicious MAC address pattern detected',
            details: issues,
            affectedSSID: target.ssid,
            suspiciousBSSID: target.bssid,
            confidenceScore: 0.5,
          ),
        );
      }

      return MACAnalysisResult(isSuspicious: false);

    } catch (e) {
      developer.log('❌ MAC analysis failed: $e');
      return MACAnalysisResult(isSuspicious: false);
    }
  }

  /// Compare current network with historical data
  HistoricalAnalysisResult _compareWithHistory(WiFiAccessPoint target) {
    try {
      if (!_networkHistory.containsKey(target.ssid)) {
        // First time seeing this network - not necessarily suspicious
        return HistoricalAnalysisResult(isAnomalous: false);
      }

      final historicalAPs = _networkHistory[target.ssid]!;
      final issues = <String>[];
      var isAnomalous = false;

      // Check if BSSID for this SSID has changed recently
      final recentAPs = historicalAPs.where((ap) => 
          DateTime.now().difference(_lastScanTime).inHours < 24).toList();

      final recentBSSIDs = recentAPs.map((ap) => ap.bssid).toSet();
      if (recentBSSIDs.length > 1 && !recentBSSIDs.contains(target.bssid)) {
        issues.add('New BSSID appeared for known SSID within 24 hours');
        isAnomalous = true;
      }

      if (isAnomalous) {
        return HistoricalAnalysisResult(
          isAnomalous: true,
          threat: SecurityThreat(
            type: ThreatType.historicalAnomaly,
            severity: ThreatSeverity.low,
            description: 'Network differs from historical patterns',
            details: issues,
            affectedSSID: target.ssid,
            suspiciousBSSID: target.bssid,
            confidenceScore: 0.4,
          ),
        );
      }

      return HistoricalAnalysisResult(isAnomalous: false);

    } catch (e) {
      developer.log('❌ Historical analysis failed: $e');
      return HistoricalAnalysisResult(isAnomalous: false);
    }
  }

  /// Analyze timing patterns for suspicious behavior
  TimingAnalysisResult _analyzeTimingPatterns(WiFiAccessPoint target) {
    try {
      // For now, simple timing analysis
      // In a full implementation, this would analyze:
      // - Sudden appearance of networks during specific times
      // - Networks that appear only when legitimate ones disappear
      // - Unusual scanning patterns
      
      return TimingAnalysisResult(isSuspicious: false);
    } catch (e) {
      developer.log('❌ Timing analysis failed: $e');
      return TimingAnalysisResult(isSuspicious: false);
    }
  }

  /// Update historical data with current scan results
  void updateHistoricalData(List<WiFiAccessPoint> scanResults) {
    try {
      _lastScanTime = DateTime.now();

      for (final ap in scanResults) {
        if (ap.ssid.isNotEmpty) {
          _networkHistory.putIfAbsent(ap.ssid, () => []);
          _networkHistory[ap.ssid]!.add(ap);

          // Keep only last 100 entries per SSID to prevent memory bloat
          if (_networkHistory[ap.ssid]!.length > 100) {
            _networkHistory[ap.ssid]!.removeAt(0);
          }
        }
      }

      developer.log('📊 Updated historical data: ${_networkHistory.length} SSIDs tracked');
    } catch (e) {
      developer.log('❌ Failed to update historical data: $e');
    }
  }

  // Helper methods
  
  /// Load legitimate network database
  Future<void> _loadLegitimateNetworkDatabase() async {
    // In a production app, this would load from a secure database
    // For now, we'll initialize with common legitimate patterns
    _legitimateNetworks['PLDT_HOME'] = NetworkFingerprint(
      ssid: 'PLDT_HOME',
      expectedSecurity: SecurityType.wpa2,
      typicalSignalStrength: -60,
      commonVendorPrefixes: ['00:1F:3F', '00:26:B8'],
    );
    
    _legitimateNetworks['Globe_Broadband'] = NetworkFingerprint(
      ssid: 'Globe_Broadband',
      expectedSecurity: SecurityType.wpa2,
      typicalSignalStrength: -55,
      commonVendorPrefixes: ['00:1A:2B', '00:50:7F'],
    );
  }

  /// Initialize known malicious MAC database
  void _initializeMaliciousMACs() {
    // This would be loaded from a threat intelligence database
    _knownMaliciousMACs.addAll([
      '00:00:00:00:00:00', // Common test/fake MAC
      'FF:FF:FF:FF:FF:FF', // Broadcast MAC (suspicious for AP)
    ]);
  }

  /// Check if MAC is suspicious
  bool _isSuspiciousMAC(String bssid) {
    // Check for patterns commonly used in malicious devices
    final suspiciousPatterns = [
      '02:', // Locally administered
      '06:', // Locally administered
      '0A:', // Locally administered
      '0E:', // Locally administered
      '12:', // Common in cheap/fake devices
      'FF:FF:FF', // Broadcast patterns
    ];

    return suspiciousPatterns.any((pattern) => bssid.startsWith(pattern));
  }

  /// Check if vendor is suspicious
  bool _isSuspiciousVendor(String macPrefix) {
    // Known vendors commonly used in cheap/malicious devices
    final suspiciousVendors = [
      '00:00:00', // Invalid/test vendor
      '02:00:00', // Common in cheap adapters
    ];

    return suspiciousVendors.contains(macPrefix);
  }

  /// Extract security type from capabilities string
  SecurityType _extractSecurityType(String capabilities) {
    if (capabilities.contains('WPA3')) return SecurityType.wpa3;
    if (capabilities.contains('WPA2')) return SecurityType.wpa2;
    if (capabilities.contains('WPA')) return SecurityType.wpa2;
    if (capabilities.contains('WEP')) return SecurityType.wep;
    return SecurityType.open;
  }

  /// Check if network is likely to be secured based on SSID
  bool _isLikelyToBeSecured(String ssid) {
    final securedPatterns = [
      'home', 'house', 'office', 'work', 'private',
      'pldt', 'globe', 'smart', 'converge',
      'dict', 'dost', 'gov', 'official',
    ];

    final lowerSSID = ssid.toLowerCase();
    return securedPatterns.any((pattern) => lowerSSID.contains(pattern));
  }

  /// Get legitimate network reference
  NetworkFingerprint? _getLegitimateNetworkReference(String ssid) {
    return _legitimateNetworks[ssid];
  }

  /// Check if network is known legitimate
  bool _isKnownLegitimateNetwork(WiFiAccessPoint ap) {
    final fingerprint = _legitimateNetworks[ap.ssid];
    if (fingerprint == null) return false;

    // Check if current network matches known legitimate fingerprint
    final currentSecurity = _extractSecurityType(ap.capabilities);
    if (currentSecurity != fingerprint.expectedSecurity) return false;

    // Check MAC vendor
    final macPrefix = ap.bssid.substring(0, 8);
    if (!fingerprint.commonVendorPrefixes.contains(macPrefix)) return false;

    return true;
  }

  /// Escalate threat level
  ThreatLevel _escalateThreatLevel(ThreatLevel current, ThreatLevel newLevel) {
    final levels = [ThreatLevel.low, ThreatLevel.medium, ThreatLevel.high, ThreatLevel.critical];
    final currentIndex = levels.indexOf(current);
    final newIndex = levels.indexOf(newLevel);
    return levels[math.max(currentIndex, newIndex)];
  }

  /// Generate network fingerprint
  NetworkFingerprint _generateNetworkFingerprint(WiFiAccessPoint ap) {
    return NetworkFingerprint(
      ssid: ap.ssid,
      bssid: ap.bssid,
      expectedSecurity: _extractSecurityType(ap.capabilities),
      typicalSignalStrength: ap.level,
      commonVendorPrefixes: [ap.bssid.substring(0, 8)],
      capabilities: ap.capabilities,
      frequency: ap.frequency,
      timestamp: DateTime.now(),
    );
  }

  /// Generate security recommendations
  List<String> _generateSecurityRecommendations(
    List<SecurityThreat> threats,
    ThreatLevel threatLevel,
    bool isKnownLegitimate,
  ) {
    final recommendations = <String>[];

    if (threatLevel == ThreatLevel.critical || threatLevel == ThreatLevel.high) {
      recommendations.add('⛔ DO NOT CONNECT - High security risk detected');
      recommendations.add('🔍 Verify network legitimacy with network administrator');
      recommendations.add('📱 Use mobile data instead of this network');
    } else if (threatLevel == ThreatLevel.medium) {
      recommendations.add('⚠️ Proceed with caution');
      recommendations.add('🛡️ Use VPN if you must connect');
      recommendations.add('🔐 Avoid accessing sensitive information');
    } else if (isKnownLegitimate) {
      recommendations.add('✅ Safe to connect - verified legitimate network');
    } else {
      recommendations.add('ℹ️ Network appears safe but unknown');
      recommendations.add('🔐 Use standard security precautions');
    }

    // Add specific recommendations based on threat types
    for (final threat in threats) {
      switch (threat.type) {
        case ThreatType.evilTwin:
          recommendations.add('🎭 Multiple networks with same name detected - verify correct one');
          break;
        case ThreatType.signalAnomaly:
          recommendations.add('📡 Unusual signal patterns detected - verify network location');
          break;
        case ThreatType.securityDowngrade:
          recommendations.add('🔓 Security appears downgraded - verify with network owner');
          break;
        case ThreatType.suspiciousMac:
          recommendations.add('🔧 Network hardware appears suspicious');
          break;
        default:
          break;
      }
    }

    return recommendations;
  }

  /// Dispose of resources
  void dispose() {
    _networkHistory.clear();
    _legitimateNetworks.clear();
    _knownMaliciousMACs.clear();
  }
}

// Analysis result classes
class EvilTwinAnalysisResult {
  final bool isDetected;
  final SecurityThreat? threat;

  EvilTwinAnalysisResult({required this.isDetected, this.threat});
}

class SignalAnomalyResult {
  final bool isAnomalous;
  final SecurityThreat? threat;

  SignalAnomalyResult({required this.isAnomalous, this.threat});
}

class SecurityConfigAnalysisResult {
  final bool isSuspicious;
  final SecurityThreat? threat;

  SecurityConfigAnalysisResult({required this.isSuspicious, this.threat});
}

class MACAnalysisResult {
  final bool isSuspicious;
  final SecurityThreat? threat;

  MACAnalysisResult({required this.isSuspicious, this.threat});
}

class HistoricalAnalysisResult {
  final bool isAnomalous;
  final SecurityThreat? threat;

  HistoricalAnalysisResult({required this.isAnomalous, this.threat});
}

class TimingAnalysisResult {
  final bool isSuspicious;
  final SecurityThreat? threat;

  TimingAnalysisResult({required this.isSuspicious, this.threat});
}

// Network fingerprint for legitimate network identification
class NetworkFingerprint {
  final String ssid;
  final String? bssid;
  final SecurityType expectedSecurity;
  final int typicalSignalStrength;
  final List<String> commonVendorPrefixes;
  final String? capabilities;
  final int? frequency;
  final DateTime? timestamp;

  NetworkFingerprint({
    required this.ssid,
    this.bssid,
    required this.expectedSecurity,
    required this.typicalSignalStrength,
    required this.commonVendorPrefixes,
    this.capabilities,
    this.frequency,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'ssid': ssid,
      'bssid': bssid,
      'expectedSecurity': expectedSecurity.toString(),
      'typicalSignalStrength': typicalSignalStrength,
      'commonVendorPrefixes': commonVendorPrefixes,
      'capabilities': capabilities,
      'frequency': frequency,
      'timestamp': timestamp?.toIso8601String(),
    };
  }
}