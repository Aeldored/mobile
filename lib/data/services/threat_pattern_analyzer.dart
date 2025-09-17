import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:wifi_scan/wifi_scan.dart';
import '../models/security_assessment.dart';

/// Advanced pattern recognition for coordinated attacks and behavioral analysis
class ThreatPatternAnalyzer {
  static final ThreatPatternAnalyzer _instance = ThreatPatternAnalyzer._internal();
  factory ThreatPatternAnalyzer() => _instance;
  ThreatPatternAnalyzer._internal();

  // Historical scan data for pattern analysis
  final List<ScanSnapshot> _scanHistory = [];
  final Map<String, NetworkBehavior> _networkBehaviors = {};
  final Map<String, AttackPattern> _detectedPatterns = {};
  
  // Timing analysis
  final List<DateTime> _scanTimestamps = [];
  
  // Pattern detection thresholds
  static const int _maxHistorySize = 50;

  /// Analyze scan results for behavioral patterns and coordinated attacks
  ThreatPatternAnalysis analyzeScanPatterns(List<WiFiAccessPoint> currentScan) {
    try {
      developer.log('🧠 Analyzing threat patterns for ${currentScan.length} networks');

      // Update scan history
      _updateScanHistory(currentScan);

      final detectedPatterns = <AttackPattern>[];
      var overallThreatScore = 0.0;

      // 1. Detect coordinated attacks (multiple suspicious networks appearing together)
      final coordinatedAttack = _detectCoordinatedAttacks(currentScan);
      if (coordinatedAttack != null) {
        detectedPatterns.add(coordinatedAttack);
        overallThreatScore += 0.4;
      }

      // 2. Detect timing-based attacks
      final timingAttack = _detectTimingBasedAttacks();
      if (timingAttack != null) {
        detectedPatterns.add(timingAttack);
        overallThreatScore += 0.3;
      }

      // 3. Detect beacon flooding attacks
      final beaconFlood = _detectBeaconFlooding(currentScan);
      if (beaconFlood != null) {
        detectedPatterns.add(beaconFlood);
        overallThreatScore += 0.5;
      }

      // 4. Detect network cycling patterns
      final cyclingPattern = _detectNetworkCycling();
      if (cyclingPattern != null) {
        detectedPatterns.add(cyclingPattern);
        overallThreatScore += 0.3;
      }

      // 5. Detect signal manipulation patterns
      final signalManipulation = _detectSignalManipulation();
      if (signalManipulation != null) {
        detectedPatterns.add(signalManipulation);
        overallThreatScore += 0.4;
      }

      // 6. Detect MAC randomization patterns
      final macRandomization = _detectMACRandomizationPattern();
      if (macRandomization != null) {
        detectedPatterns.add(macRandomization);
        overallThreatScore += 0.2;
      }

      // 7. Detect honeypot patterns
      final honeypotPattern = _detectHoneypotPatterns(currentScan);
      if (honeypotPattern != null) {
        detectedPatterns.add(honeypotPattern);
        overallThreatScore += 0.6;
      }

      // Update behavior tracking
      _updateNetworkBehaviors(currentScan);

      final finalThreatScore = math.min(1.0, overallThreatScore);
      
      developer.log('🔍 Pattern analysis complete: ${detectedPatterns.length} patterns, threat score: $finalThreatScore');

      return ThreatPatternAnalysis(
        detectedPatterns: detectedPatterns,
        overallThreatScore: finalThreatScore,
        scanCount: _scanHistory.length,
        analysisTimestamp: DateTime.now(),
        environmentalFactors: _analyzeEnvironmentalFactors(),
      );

    } catch (e) {
      developer.log('❌ Pattern analysis failed: $e');
      return ThreatPatternAnalysis(
        detectedPatterns: [],
        overallThreatScore: 0.0,
        scanCount: _scanHistory.length,
        analysisTimestamp: DateTime.now(),
        environmentalFactors: {},
      );
    }
  }

  /// Detect coordinated attacks (multiple suspicious networks appearing simultaneously)
  AttackPattern? _detectCoordinatedAttacks(List<WiFiAccessPoint> currentScan) {
    final suspiciousNetworks = <WiFiAccessPoint>[];
    
    // Look for networks that appeared at the same time
    for (final ap in currentScan) {
      if (_isNetworkSuspicious(ap)) {
        suspiciousNetworks.add(ap);
      }
    }

    if (suspiciousNetworks.length >= 3) {
      // Check if they appeared in the same time window
      final now = DateTime.now();
      final recentPatterns = _detectedPatterns.values
          .where((pattern) => now.difference(pattern.firstDetected).inMinutes < 5)
          .length;

      if (recentPatterns <= 1) { // First time seeing this pattern
        developer.log('🚨 Coordinated attack detected: ${suspiciousNetworks.length} suspicious networks');
        
        return AttackPattern(
          type: AttackType.coordinatedAttack,
          severity: ThreatSeverity.high,
          description: 'Multiple suspicious networks appeared simultaneously',
          evidence: [
            '${suspiciousNetworks.length} suspicious networks detected together',
            'Networks: ${suspiciousNetworks.map((ap) => ap.ssid).join(", ")}',
            'Possible multi-vector attack in progress',
          ],
          affectedNetworks: suspiciousNetworks.map((ap) => ap.ssid).toList(),
          confidenceScore: 0.8,
          firstDetected: DateTime.now(),
        );
      }
    }

    return null;
  }

  /// Detect timing-based attacks (networks appearing when legitimate ones disappear)
  AttackPattern? _detectTimingBasedAttacks() {
    if (_scanHistory.length < 3) return null;

    final currentScan = _scanHistory.last;
    final previousScan = _scanHistory[_scanHistory.length - 2];
    
    // Find networks that disappeared and new ones that appeared
    final disappeared = previousScan.networks.where(
      (prev) => !currentScan.networks.any((curr) => curr.bssid == prev.bssid)
    ).toList();
    
    final appeared = currentScan.networks.where(
      (curr) => !previousScan.networks.any((prev) => prev.bssid == curr.bssid)
    ).toList();

    // Suspicious if legitimate network disappears and similar one appears
    for (final disappearedAP in disappeared) {
      for (final appearedAP in appeared) {
        if (_areSSIDsSimilar(disappearedAP.ssid, appearedAP.ssid, 0.8)) {
          developer.log('🕐 Timing attack detected: ${disappearedAP.ssid} → ${appearedAP.ssid}');
          
          return AttackPattern(
            type: AttackType.timingReplacement,
            severity: ThreatSeverity.high,
            description: 'Network replacement detected - possible evil twin timing attack',
            evidence: [
              'Network "${disappearedAP.ssid}" (${disappearedAP.bssid}) disappeared',
              'Similar network "${appearedAP.ssid}" (${appearedAP.bssid}) appeared immediately',
              'Timing pattern suggests coordinated replacement attack',
            ],
            affectedNetworks: [disappearedAP.ssid, appearedAP.ssid],
            confidenceScore: 0.85,
            firstDetected: DateTime.now(),
          );
        }
      }
    }

    return null;
  }

  /// Detect beacon flooding attacks (excessive number of networks)
  AttackPattern? _detectBeaconFlooding(List<WiFiAccessPoint> currentScan) {
    final networkCount = currentScan.length;
    
    // Calculate average network count from history
    if (_scanHistory.length < 5) return null;
    
    final historicalCounts = _scanHistory
        .skip(math.max(0, _scanHistory.length - 10))
        .map((scan) => scan.networks.length)
        .toList();
    
    final averageCount = historicalCounts.reduce((a, b) => a + b) / historicalCounts.length;
    
    // If current scan has significantly more networks
    if (networkCount > averageCount * 2.5 && networkCount > 20) {
      // Check if many networks have suspicious characteristics
      final openNetworks = currentScan.where((ap) => !ap.capabilities.contains('WPA')).length;
      final randomMacs = currentScan.where((ap) => _hasRandomizedMAC(ap.bssid)).length;
      
      if (openNetworks > networkCount * 0.7 || randomMacs > networkCount * 0.5) {
        developer.log('📡 Beacon flooding detected: $networkCount networks (avg: ${averageCount.toInt()})');
        
        return AttackPattern(
          type: AttackType.beaconFlooding,
          severity: ThreatSeverity.medium,
          description: 'Excessive number of wireless networks detected - possible beacon flooding',
          evidence: [
            '$networkCount networks detected (${(averageCount * 2.5).toInt()}+ threshold)',
            '$openNetworks open networks (${((openNetworks / networkCount) * 100).toInt()}%)',
            '$randomMacs randomized MAC addresses (${((randomMacs / networkCount) * 100).toInt()}%)',
            'Pattern suggests beacon flooding attack',
          ],
          affectedNetworks: ['Multiple networks'],
          confidenceScore: 0.7,
          firstDetected: DateTime.now(),
        );
      }
    }

    return null;
  }

  /// Detect network cycling patterns (networks appearing/disappearing in cycles)
  AttackPattern? _detectNetworkCycling() {
    if (_scanHistory.length < 6) return null;

    final cyclingNetworks = <String, List<bool>>{};
    
    // Track presence of each SSID across scans
    for (int i = _scanHistory.length - 6; i < _scanHistory.length; i++) {
      final scan = _scanHistory[i];
      for (final ap in scan.networks) {
        cyclingNetworks.putIfAbsent(ap.ssid, () => []);
        cyclingNetworks[ap.ssid]!.add(true);
      }
      
      // Mark absent networks
      for (final ssid in cyclingNetworks.keys) {
        if (!scan.networks.any((ap) => ap.ssid == ssid)) {
          cyclingNetworks[ssid]!.add(false);
        }
      }
    }

    // Look for cycling patterns
    for (final entry in cyclingNetworks.entries) {
      final ssid = entry.key;
      final presence = entry.value;
      
      if (presence.length >= 6) {
        // Check for alternating pattern
        bool hasCycles = false;
        int changes = 0;
        
        for (int i = 1; i < presence.length; i++) {
          if (presence[i] != presence[i - 1]) {
            changes++;
          }
        }
        
        if (changes >= 3) { // Multiple appearance/disappearance cycles
          hasCycles = true;
        }
        
        if (hasCycles) {
          developer.log('🔄 Network cycling detected: $ssid');
          
          return AttackPattern(
            type: AttackType.networkCycling,
            severity: ThreatSeverity.medium,
            description: 'Network cycling pattern detected - possible attack probe',
            evidence: [
              'Network "$ssid" appeared/disappeared $changes times',
              'Pattern: ${presence.map((p) => p ? "ON" : "OFF").join(" → ")}',
              'Cycling behavior suggests automated attack tool',
            ],
            affectedNetworks: [ssid],
            confidenceScore: 0.6,
            firstDetected: DateTime.now(),
          );
        }
      }
    }

    return null;
  }

  /// Detect signal manipulation patterns
  AttackPattern? _detectSignalManipulation() {
    if (_scanHistory.length < 4) return null;

    // Look for networks with unusual signal strength changes
    final recentScans = _scanHistory.skip(_scanHistory.length - 4).toList();
    final signalJumps = <String, List<int>>{};

    for (final scan in recentScans) {
      for (final ap in scan.networks) {
        signalJumps.putIfAbsent('${ap.ssid}:${ap.bssid}', () => []);
        signalJumps['${ap.ssid}:${ap.bssid}']!.add(ap.level);
      }
    }

    for (final entry in signalJumps.entries) {
      final networkId = entry.key;
      final signals = entry.value;
      
      if (signals.length >= 3) {
        // Look for sudden signal jumps
        for (int i = 1; i < signals.length; i++) {
          final jump = (signals[i] - signals[i - 1]).abs();
          
          if (jump > 30) { // More than 30 dBm change
            final ssid = networkId.split(':')[0];
            developer.log('📶 Signal manipulation detected: $ssid (${jump}dBm jump)');
            
            return AttackPattern(
              type: AttackType.signalManipulation,
              severity: ThreatSeverity.medium,
              description: 'Unusual signal strength changes detected',
              evidence: [
                'Network "$ssid" had ${jump}dBm signal jump',
                'Signal pattern: ${signals.join(" → ")} dBm',
                'Sudden changes suggest signal manipulation',
              ],
              affectedNetworks: [ssid],
              confidenceScore: 0.7,
              firstDetected: DateTime.now(),
            );
          }
        }
      }
    }

    return null;
  }

  /// Detect MAC randomization patterns
  AttackPattern? _detectMACRandomizationPattern() {
    if (_scanHistory.length < 3) return null;

    final currentScan = _scanHistory.last;
    final randomizedMacs = currentScan.networks
        .where((ap) => _hasRandomizedMAC(ap.bssid))
        .length;
    
    final totalNetworks = currentScan.networks.length;
    final randomizationRatio = randomizedMacs / totalNetworks;

    if (randomizationRatio > 0.4 && randomizedMacs > 3) {
      developer.log('🎭 High MAC randomization detected: ${(randomizationRatio * 100).toInt()}%');
      
      return AttackPattern(
        type: AttackType.macRandomization,
        severity: ThreatSeverity.low,
        description: 'High percentage of randomized MAC addresses detected',
        evidence: [
          '$randomizedMacs out of $totalNetworks networks have randomized MACs',
          '${(randomizationRatio * 100).toInt()}% randomization rate',
          'May indicate presence of attack tools or privacy-focused devices',
        ],
        affectedNetworks: ['Multiple networks'],
        confidenceScore: 0.5,
        firstDetected: DateTime.now(),
      );
    }

    return null;
  }

  /// Detect honeypot patterns
  AttackPattern? _detectHoneypotPatterns(List<WiFiAccessPoint> currentScan) {
    final honeypotIndicators = <WiFiAccessPoint>[];

    for (final ap in currentScan) {
      var honeypotScore = 0.0;
      final indicators = <String>[];

      // Open network with common enterprise names
      if (!ap.capabilities.contains('WPA')) {
        if (ap.ssid.toLowerCase().contains('corp') ||
            ap.ssid.toLowerCase().contains('company') ||
            ap.ssid.toLowerCase().contains('office') ||
            ap.ssid.toLowerCase().contains('enterprise')) {
          honeypotScore += 0.4;
          indicators.add('Open network with enterprise-style name');
        }
      }

      // Very strong signal (device very close)
      if (ap.level > -30) {
        honeypotScore += 0.3;
        indicators.add('Unusually strong signal (${ap.level} dBm)');
      }

      // Generic/enticing names
      final enticingNames = ['free_wifi', 'fast_internet', 'unlimited', 'premium_wifi'];
      for (final name in enticingNames) {
        if (ap.ssid.toLowerCase().contains(name.replaceAll('_', ''))) {
          honeypotScore += 0.2;
          indicators.add('Enticing network name');
          break;
        }
      }

      // Randomized MAC
      if (_hasRandomizedMAC(ap.bssid)) {
        honeypotScore += 0.1;
        indicators.add('Randomized MAC address');
      }

      if (honeypotScore >= 0.6) {
        honeypotIndicators.add(ap);
      }
    }

    if (honeypotIndicators.isNotEmpty) {
      developer.log('🍯 Honeypot patterns detected: ${honeypotIndicators.length} networks');
      
      return AttackPattern(
        type: AttackType.honeypotPattern,
        severity: ThreatSeverity.high,
        description: 'Potential honeypot networks detected',
        evidence: [
          '${honeypotIndicators.length} networks show honeypot characteristics',
          'Networks: ${honeypotIndicators.map((ap) => ap.ssid).join(", ")}',
          'Common indicators: open enterprise networks, strong signals, enticing names',
        ],
        affectedNetworks: honeypotIndicators.map((ap) => ap.ssid).toList(),
        confidenceScore: 0.75,
        firstDetected: DateTime.now(),
      );
    }

    return null;
  }

  /// Update scan history with current results
  void _updateScanHistory(List<WiFiAccessPoint> currentScan) {
    _scanTimestamps.add(DateTime.now());
    
    _scanHistory.add(ScanSnapshot(
      networks: List.from(currentScan),
      timestamp: DateTime.now(),
      networkCount: currentScan.length,
    ));

    // Keep history size manageable
    if (_scanHistory.length > _maxHistorySize) {
      _scanHistory.removeAt(0);
    }

    if (_scanTimestamps.length > _maxHistorySize) {
      _scanTimestamps.removeAt(0);
    }

    // Update last scan timestamp (stored in _scanTimestamps)
  }

  /// Update network behavior tracking
  void _updateNetworkBehaviors(List<WiFiAccessPoint> currentScan) {
    for (final ap in currentScan) {
      final behaviorKey = '${ap.ssid}:${ap.bssid}';
      
      _networkBehaviors.putIfAbsent(behaviorKey, () => NetworkBehavior(
        ssid: ap.ssid,
        bssid: ap.bssid,
      ));
      
      _networkBehaviors[behaviorKey]!.addObservation(ap);
    }

    // Clean up old behaviors
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    _networkBehaviors.removeWhere((key, behavior) => 
        behavior.lastSeen.isBefore(cutoff));
  }

  /// Analyze environmental factors
  Map<String, dynamic> _analyzeEnvironmentalFactors() {
    if (_scanHistory.isEmpty) return {};

    final currentScan = _scanHistory.last;
    final networkCount = currentScan.networks.length;
    final openNetworks = currentScan.networks
        .where((ap) => !ap.capabilities.contains('WPA')).length;
    
    // Calculate scan frequency
    double scanFrequency = 0.0;
    if (_scanTimestamps.length > 1) {
      final totalTime = _scanTimestamps.last.difference(_scanTimestamps.first);
      scanFrequency = _scanTimestamps.length / totalTime.inMinutes;
    }

    return {
      'total_networks': networkCount,
      'open_networks': openNetworks,
      'open_percentage': networkCount > 0 ? (openNetworks / networkCount) * 100 : 0,
      'scan_frequency': scanFrequency,
      'scan_count': _scanHistory.length,
      'analysis_time': DateTime.now().toIso8601String(),
    };
  }

  /// Helper methods
  bool _isNetworkSuspicious(WiFiAccessPoint ap) {
    // Basic heuristics for suspicious networks
    return !ap.capabilities.contains('WPA') || // Open network
           _hasRandomizedMAC(ap.bssid) ||        // Randomized MAC
           ap.level > -25 ||                     // Very strong signal
           ap.ssid.toLowerCase().contains('free'); // Enticing name
  }

  bool _hasRandomizedMAC(String bssid) {
    return bssid.startsWith('02:') || bssid.startsWith('06:') ||
           bssid.startsWith('0A:') || bssid.startsWith('0E:');
  }

  bool _areSSIDsSimilar(String ssid1, String ssid2, double threshold) {
    if (ssid1.isEmpty || ssid2.isEmpty) return false;
    
    final longer = ssid1.length > ssid2.length ? ssid1 : ssid2;
    final shorter = ssid1.length > ssid2.length ? ssid2 : ssid1;
    
    if (longer.isEmpty) return true;
    
    // Simple similarity based on common characters
    int commonChars = 0;
    for (int i = 0; i < shorter.length; i++) {
      if (longer.toLowerCase().contains(shorter[i].toLowerCase())) {
        commonChars++;
      }
    }
    
    return (commonChars / longer.length) >= threshold;
  }

  /// Clear history for testing
  void clearHistory() {
    _scanHistory.clear();
    _networkBehaviors.clear();
    _detectedPatterns.clear();
    _scanTimestamps.clear();
  }

  /// Get analyzer statistics
  Map<String, dynamic> getAnalyzerStats() {
    return {
      'scan_history_size': _scanHistory.length,
      'tracked_behaviors': _networkBehaviors.length,
      'detected_patterns': _detectedPatterns.length,
      'scan_timestamps': _scanTimestamps.length,
    };
  }
}

/// Snapshot of a WiFi scan for historical analysis
class ScanSnapshot {
  final List<WiFiAccessPoint> networks;
  final DateTime timestamp;
  final int networkCount;

  ScanSnapshot({
    required this.networks,
    required this.timestamp,
    required this.networkCount,
  });
}

/// Network behavior tracking
class NetworkBehavior {
  final String ssid;
  final String bssid;
  final List<int> signalHistory = [];
  final List<DateTime> seenTimestamps = [];
  DateTime firstSeen;
  DateTime lastSeen;
  
  NetworkBehavior({
    required this.ssid,
    required this.bssid,
  }) : firstSeen = DateTime.now(), lastSeen = DateTime.now();

  void addObservation(WiFiAccessPoint ap) {
    signalHistory.add(ap.level);
    seenTimestamps.add(DateTime.now());
    lastSeen = DateTime.now();
    
    // Keep history manageable
    if (signalHistory.length > 20) {
      signalHistory.removeAt(0);
      seenTimestamps.removeAt(0);
    }
  }

  double get averageSignal => 
      signalHistory.isNotEmpty ? signalHistory.reduce((a, b) => a + b) / signalHistory.length : 0.0;
      
  double get signalVariance {
    if (signalHistory.length < 2) return 0.0;
    final mean = averageSignal;
    final variance = signalHistory.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) / signalHistory.length;
    return variance;
  }
}

/// Attack pattern detected by analyzer
class AttackPattern {
  final AttackType type;
  final ThreatSeverity severity;
  final String description;
  final List<String> evidence;
  final List<String> affectedNetworks;
  final double confidenceScore;
  final DateTime firstDetected;

  AttackPattern({
    required this.type,
    required this.severity,
    required this.description,
    required this.evidence,
    required this.affectedNetworks,
    required this.confidenceScore,
    required this.firstDetected,
  });

  @override
  String toString() {
    return 'AttackPattern(type: $type, severity: $severity, confidence: $confidenceScore)';
  }
}

/// Result of threat pattern analysis
class ThreatPatternAnalysis {
  final List<AttackPattern> detectedPatterns;
  final double overallThreatScore;
  final int scanCount;
  final DateTime analysisTimestamp;
  final Map<String, dynamic> environmentalFactors;

  ThreatPatternAnalysis({
    required this.detectedPatterns,
    required this.overallThreatScore,
    required this.scanCount,
    required this.analysisTimestamp,
    required this.environmentalFactors,
  });

  bool get hasPatterns => detectedPatterns.isNotEmpty;
  
  AttackPattern? get mostSeverePattern {
    if (detectedPatterns.isEmpty) return null;
    return detectedPatterns.reduce((a, b) => 
        a.severity.index > b.severity.index ? a : b);
  }

  @override
  String toString() {
    return 'ThreatPatternAnalysis(patterns: ${detectedPatterns.length}, threat: $overallThreatScore)';
  }
}

/// Types of attack patterns that can be detected
enum AttackType {
  coordinatedAttack,
  timingReplacement,
  beaconFlooding,
  networkCycling,
  signalManipulation,
  macRandomization,
  honeypotPattern,
}