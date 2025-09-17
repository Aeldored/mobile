import 'dart:developer' as developer;
import 'package:wifi_scan/wifi_scan.dart';
import '../models/security_assessment.dart';
import 'oui_database.dart' as oui;
import 'confidence_calculator.dart';
import 'ssid_analyzer.dart';
import 'threat_pattern_analyzer.dart';

/// Enhanced security analysis engine for Evil Twin detection and threat assessment
/// Features multi-layered detection with cross-validation and advanced confidence scoring
class SecurityAnalyzer {
  static final SecurityAnalyzer _instance = SecurityAnalyzer._internal();
  factory SecurityAnalyzer() => _instance;
  SecurityAnalyzer._internal();

  // Enhanced analysis components
  final oui.OUIDatabase _ouiDatabase = oui.OUIDatabase();
  final ConfidenceCalculator _confidenceCalculator = ConfidenceCalculator();
  final SSIDAnalyzer _ssidAnalyzer = SSIDAnalyzer();
  final ThreatPatternAnalyzer _patternAnalyzer = ThreatPatternAnalyzer();

  // Historical data for comparison analysis
  final Map<String, List<WiFiAccessPoint>> _networkHistory = {};
  final Map<String, NetworkFingerprint> _legitimateNetworks = {};
  final Set<String> _knownMaliciousMACs = {};
  
  // Real-time scanning data and statistics
  int _totalAnalyses = 0;
  int _threatsDetected = 0;

  /// Initialize enhanced security analyzer with all detection components
  Future<void> initialize() async {
    try {
      developer.log('🛡️ Initializing Enhanced SecurityAnalyzer v2.0');
      
      // Load known legitimate network fingerprints
      await _loadLegitimateNetworkDatabase();
      
      // Initialize malicious MAC database
      _initializeMaliciousMACs();
      
      // Initialize environmental profiles for confidence calculation
      _initializeEnvironmentalProfiles();
      
      developer.log('✅ Enhanced SecurityAnalyzer initialized successfully');
      developer.log('📊 Components: OUI DB, Confidence Calc, SSID Analyzer, Pattern Analyzer');
    } catch (e) {
      developer.log('❌ Failed to initialize SecurityAnalyzer: $e');
    }
  }

  /// Perform enhanced multi-layered security analysis on a network
  Future<SecurityAssessment> analyzeNetwork(
    WiFiAccessPoint target, 
    List<WiFiAccessPoint> allNetworks,
  ) async {
    try {
      _totalAnalyses++;
      developer.log('🔍 Enhanced analysis #$_totalAnalyses: ${target.ssid} (${target.bssid})');
      
      final threats = <SecurityThreat>[];
      final evidenceItems = <ThreatEvidence>[];

      // 1. SSID Analysis (NEW - Advanced typosquatting detection)
      final ssidAnalysis = _ssidAnalyzer.analyzeSSID(target.ssid, allNetworks.map((ap) => ap.ssid).toList());
      if (ssidAnalysis.isDetected) {
        final threat = SecurityThreat(
          type: ThreatType.evilTwin,
          severity: ThreatSeverity.high,
          description: 'Suspicious SSID pattern detected',
          details: ssidAnalysis.suspiciousFactors,
          affectedSSID: target.ssid,
          suspiciousBSSID: target.bssid,
          confidenceScore: ssidAnalysis.confidenceScore,
        );
        threats.add(threat);
        evidenceItems.add(ThreatEvidence(
          detectionMethod: 'ssid_analysis',
          severity: ThreatSeverity.high,
          confidenceScore: ssidAnalysis.confidenceScore,
        ));
      }

      // 2. Enhanced Evil Twin Detection
      final evilTwinAnalysis = _detectEvilTwin(target, allNetworks);
      if (evilTwinAnalysis.isDetected && evilTwinAnalysis.threat != null) {
        threats.add(evilTwinAnalysis.threat!);
        evidenceItems.add(ThreatEvidence(
          detectionMethod: 'evil_twin',
          severity: evilTwinAnalysis.threat!.severity,
          confidenceScore: evilTwinAnalysis.threat!.confidenceScore,
        ));
      }

      // 3. Enhanced MAC Address Analysis with OUI Database
      final macAnalysis = _analyzeMACAddressEnhanced(target);
      if (macAnalysis.isSuspicious && macAnalysis.threat != null) {
        threats.add(macAnalysis.threat!);
        evidenceItems.add(ThreatEvidence(
          detectionMethod: 'mac_analysis',
          severity: macAnalysis.threat!.severity,
          confidenceScore: macAnalysis.threat!.confidenceScore,
        ));
      }

      // 4. Signal Strength Anomaly Detection (Enhanced)
      final signalAnomaly = _analyzeSignalAnomaliesEnhanced(target);
      if (signalAnomaly.isAnomalous && signalAnomaly.threat != null) {
        threats.add(signalAnomaly.threat!);
        evidenceItems.add(ThreatEvidence(
          detectionMethod: 'signal_anomaly',
          severity: signalAnomaly.threat!.severity,
          confidenceScore: signalAnomaly.threat!.confidenceScore,
        ));
      }

      // 5. Security Configuration Analysis (Enhanced)
      final securityAnalysis = _analyzeSecurityConfigurationEnhanced(target);
      if (securityAnalysis.isSuspicious && securityAnalysis.threat != null) {
        threats.add(securityAnalysis.threat!);
        evidenceItems.add(ThreatEvidence(
          detectionMethod: 'security_config',
          severity: securityAnalysis.threat!.severity,
          confidenceScore: securityAnalysis.threat!.confidenceScore,
        ));
      }

      // 6. Historical Comparison (Enhanced)
      final historicalAnalysis = _compareWithHistoryEnhanced(target);
      if (historicalAnalysis.isAnomalous && historicalAnalysis.threat != null) {
        threats.add(historicalAnalysis.threat!);
        evidenceItems.add(ThreatEvidence(
          detectionMethod: 'historical_analysis',
          severity: historicalAnalysis.threat!.severity,
          confidenceScore: historicalAnalysis.threat!.confidenceScore,
        ));
      }

      // 7. Advanced Confidence Calculation with Bayesian Inference
      final finalConfidence = _confidenceCalculator.calculateThreatConfidence(
        evidence: evidenceItems,
        networkId: target.bssid,
        ssid: target.ssid,
      );

      // 8. Determine threat level based on confidence and evidence
      final threatLevel = _calculateThreatLevel(finalConfidence, threats);
      
      // 9. Cross-validation: Require multiple methods for high-confidence detection
      final validatedThreats = _crossValidateThreats(threats, evidenceItems, finalConfidence);
      
      // 10. Generate network fingerprint
      final fingerprint = _generateNetworkFingerprint(target);
      
      // 11. Check if network is known legitimate
      final isKnownLegitimate = _isKnownLegitimateNetworkEnhanced(target);
      
      // 12. Generate enhanced recommendations
      final recommendations = _generateSecurityRecommendations(
        validatedThreats, 
        threatLevel,
        isKnownLegitimate,
      );

      // Update statistics
      if (validatedThreats.isNotEmpty) _threatsDetected++;

      developer.log('🛡️ Enhanced analysis complete: ${validatedThreats.length} threats, confidence: $finalConfidence');
      developer.log('📊 Stats: $_threatsDetected/$_totalAnalyses threats detected (${((_threatsDetected/_totalAnalyses)*100).toInt()}%)');

      return SecurityAssessment(
        networkId: target.bssid,
        ssid: target.ssid,
        threatLevel: threatLevel,
        confidenceScore: finalConfidence,
        detectedThreats: validatedThreats,
        networkFingerprint: fingerprint.toMap(),
        isKnownLegitimate: isKnownLegitimate,
        recommendations: recommendations,
        analysisTimestamp: DateTime.now(),
      );

    } catch (e) {
      developer.log('❌ Enhanced security analysis failed: $e');
      return SecurityAssessment.createError(target.bssid, target.ssid, e.toString());
    }
  }

  /// Perform pattern analysis on all networks (NEW)
  Future<void> performPatternAnalysis(List<WiFiAccessPoint> allNetworks) async {
    try {
      final patternAnalysis = _patternAnalyzer.analyzeScanPatterns(allNetworks);
      
      if (patternAnalysis.hasPatterns) {
        developer.log('🚨 Attack patterns detected: ${patternAnalysis.detectedPatterns.length}');
        for (final pattern in patternAnalysis.detectedPatterns) {
          developer.log('   - ${pattern.type}: ${pattern.description}');
        }
      }
    } catch (e) {
      developer.log('❌ Pattern analysis failed: $e');
    }
  }

  /// Enhanced Evil Twin detection with cross-validation
  EvilTwinAnalysisResult _detectEvilTwin(
    WiFiAccessPoint target, 
    List<WiFiAccessPoint> allNetworks,
  ) {
    try {
      // CRITICAL: Check for government network impersonation first
      final governmentImpersonation = _detectGovernmentNetworkImpersonation(target);
      if (governmentImpersonation.isDetected) {
        developer.log('🚨🏛️ CRITICAL: Government network impersonation detected: ${target.ssid}');
        return governmentImpersonation;
      }

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

      // Factor 1: Signal strength analysis - ONLY for specific contexts
      // Strong signal is only suspicious if:
      // 1. Network is open (no encryption) AND has strong signal, OR
      // 2. Network has similar SSID to verified networks but different MAC
      final targetIsOpen = !target.capabilities.contains('WPA') && !target.capabilities.contains('WEP');
      final hasSimilarVerifiedSSID = _hasSimilarSSIDInWhitelist(target.ssid);
      
      if (target.level > -30 && (targetIsOpen || hasSimilarVerifiedSSID)) {
        suspiciousFactors.add('Unusually strong signal for ${targetIsOpen ? "open" : "similar"} network (${target.level} dBm)');
        suspicionScore += 0.3;
        developer.log('🔍 SUSPICIOUS: Strong signal detected for ${target.ssid}: ${target.level} dBm (${targetIsOpen ? "open" : "similar SSID"})');
      }

      // Factor 2: Open security when others are encrypted
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

      // ENHANCED: Higher threshold with vendor validation
      final vendorCompatibility = _ouiDatabase.getVendorSSIDCompatibility(target.bssid, target.ssid);
      if (vendorCompatibility < 0.5) {
        suspiciousFactors.add('MAC vendor incompatible with SSID type (${(vendorCompatibility * 100).toInt()}% compatibility)');
        suspicionScore += 0.3;
      }

      final isDetected = suspicionScore >= 0.6; // RAISED threshold for better accuracy

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

  /// CRITICAL: Detect government network impersonation attacks
  EvilTwinAnalysisResult _detectGovernmentNetworkImpersonation(WiFiAccessPoint target) {
    try {
      // Government network name patterns that should NEVER be mimicked
      final governmentPatterns = [
        // DICT patterns
        'dict',
        'DICT',
        'Dict',
        'dict-calabarzon',
        'DICT-CALABARZON', 
        'Dict-Calabarzon',
        'dict_calabarzon',
        'DICT_CALABARZON',
        // Government office patterns
        'dost',
        'DOST',
        'dilg',
        'DILG',
        'deped',
        'DepEd',
        'DEPED',
        'doh',
        'DOH',
        'dti',
        'DTI',
        'dswd',
        'DSWD',
        // Regional government patterns
        'calabarzon',
        'CALABARZON',
        'Calabarzon',
        'region4a',
        'REGION4A',
        'Region4A',
        // Municipal patterns
        'lgu',
        'LGU',
        'municipal',
        'MUNICIPAL',
        'Municipal',
        'city_hall',
        'CITY_HALL',
        'cityhall',
        'CITYHALL',
        // Generic government patterns
        'gov',
        'GOV',
        'Gov',
        'government',
        'GOVERNMENT',
        'Government',
        'official',
        'OFFICIAL',
        'Official'
      ];

      final ssid = target.ssid.toLowerCase();
      bool containsGovPattern = false;
      String matchedPattern = '';

      // Check if SSID contains any government patterns
      for (final pattern in governmentPatterns) {
        if (ssid.contains(pattern.toLowerCase())) {
          containsGovPattern = true;
          matchedPattern = pattern;
          break;
        }
      }

      if (!containsGovPattern) {
        return EvilTwinAnalysisResult(isDetected: false);
      }

      // CRITICAL: If it contains government patterns, check if it's in our verified whitelist
      final isInWhitelist = _isNetworkInVerifiedWhitelist(target);
      
      if (!isInWhitelist) {
        developer.log('🚨🏛️ GOVERNMENT IMPERSONATION DETECTED!');
        developer.log('   Network: ${target.ssid}');
        developer.log('   MAC: ${target.bssid}');
        developer.log('   Pattern: $matchedPattern');
        developer.log('   Signal: ${target.level} dBm');
        developer.log('   Security: ${target.capabilities}');

        return EvilTwinAnalysisResult(
          isDetected: true,
          threat: SecurityThreat(
            type: ThreatType.evilTwin,
            severity: ThreatSeverity.critical,
            description: 'CRITICAL: Unauthorized network impersonating "$matchedPattern" government network',
            details: [
              'Network name mimics government/DICT infrastructure',
              'Not in verified government whitelist', 
              'Potential Evil Twin attack targeting government employees',
              'Could be attempting to steal government credentials',
              'May be harvesting sensitive government data'
            ],
            affectedSSID: target.ssid,
            suspiciousBSSID: target.bssid,
            confidenceScore: 0.95, // Very high confidence
            additionalData: {
              'impersonated_pattern': matchedPattern,
              'signal_strength': target.level,
              'security_type': target.capabilities,
              'threat_type': 'government_impersonation',
              'severity_reason': 'Critical government infrastructure mimicking'
            },
          ),
        );
      }

      return EvilTwinAnalysisResult(isDetected: false);

    } catch (e) {
      developer.log('❌ Error in government impersonation detection: $e');
      return EvilTwinAnalysisResult(isDetected: false);
    }
  }

  /// Check if network is in verified government whitelist
  bool _isNetworkInVerifiedWhitelist(WiFiAccessPoint target) {
    // For now, assume any government-named network NOT in our database is suspicious
    // This forces all government-named networks to be flagged for verification
    return false; // This will flag ALL government-named networks as suspicious for testing
  }

  /// Enhanced signal analysis with multi-scan correlation
  SignalAnomalyResult _analyzeSignalAnomaliesEnhanced(WiFiAccessPoint target) {
    try {
      final anomalies = <String>[];
      var isAnomalous = false;
      var confidenceScore = 0.0;

      // 1. Extreme signal strength check (more sophisticated)
      if (target.level > -20) {
        anomalies.add('Extremely strong signal (${target.level} dBm) - device likely within 1 meter');
        isAnomalous = true;
        confidenceScore += 0.4;
      } else if (target.level > -30) {
        anomalies.add('Very strong signal (${target.level} dBm) - unusually close device');
        isAnomalous = true;
        confidenceScore += 0.2;
      }

      // 2. Historical signal consistency
      if (_networkHistory.containsKey(target.ssid)) {
        final historicalSignals = _networkHistory[target.ssid]!
            .where((ap) => ap.bssid == target.bssid)
            .map((ap) => ap.level)
            .toList();

        if (historicalSignals.isNotEmpty && historicalSignals.length >= 3) {
          final averageSignal = historicalSignals.reduce((a, b) => a + b) / historicalSignals.length;
          final signalDeviation = (target.level - averageSignal).abs();

          // More sophisticated deviation analysis
          if (signalDeviation > 25) {
            anomalies.add('Signal deviates ${signalDeviation.toInt()}dBm from historical average');
            isAnomalous = true;
            confidenceScore += 0.3;
          }

          // Check for signal jump pattern (evil twin activation)
          if (historicalSignals.length >= 2) {
            final lastSignal = historicalSignals.last;
            final signalJump = (target.level - lastSignal).abs();
            if (signalJump > 15) {
              anomalies.add('Sudden signal jump of ${signalJump.toInt()}dBm since last scan');
              isAnomalous = true;
              confidenceScore += 0.2;
            }
          }
        }
      }

      // 3. Signal implausibility check
      if (target.level > -10) {
        anomalies.add('Implausibly strong signal - possible signal amplification attack');
        isAnomalous = true;
        confidenceScore += 0.5;
      }

      if (isAnomalous) {
        return SignalAnomalyResult(
          isAnomalous: true,
          threat: SecurityThreat(
            type: ThreatType.signalAnomaly,
            severity: confidenceScore > 0.6 ? ThreatSeverity.high : ThreatSeverity.medium,
            description: 'Signal strength anomaly detected',
            details: anomalies,
            affectedSSID: target.ssid,
            suspiciousBSSID: target.bssid,
            confidenceScore: confidenceScore,
          ),
        );
      }

      return SignalAnomalyResult(isAnomalous: false);

    } catch (e) {
      developer.log('❌ Enhanced signal analysis failed: $e');
      return SignalAnomalyResult(isAnomalous: false);
    }
  }


  /// Enhanced security configuration analysis
  SecurityConfigAnalysisResult _analyzeSecurityConfigurationEnhanced(WiFiAccessPoint target) {
    try {
      final issues = <String>[];
      var isSuspicious = false;
      var confidenceScore = 0.0;

      // 1. Enhanced security downgrade detection
      if (_networkHistory.containsKey(target.ssid)) {
        final historicalAPs = _networkHistory[target.ssid]!;
        final previousSecurityTypes = historicalAPs
            .where((ap) => ap.bssid == target.bssid)
            .map((ap) => _extractSecurityType(ap.capabilities))
            .toSet();

        final currentSecurity = _extractSecurityType(target.capabilities);

        // Check for security downgrade with more granularity
        if (previousSecurityTypes.contains(SecurityType.wpa3) && currentSecurity != SecurityType.wpa3) {
          issues.add('Security downgraded from WPA3 to ${currentSecurity.toString()}');
          isSuspicious = true;
          confidenceScore += 0.8; // High confidence for WPA3 downgrade
        } else if (previousSecurityTypes.contains(SecurityType.wpa2)) {
          if (currentSecurity == SecurityType.wep || currentSecurity == SecurityType.open) {
            issues.add('Security downgraded from WPA2 to ${currentSecurity.toString()}');
            isSuspicious = true;
            confidenceScore += 0.6;
          }
        }
      }

      // 2. SSID-security mismatch analysis
      final expectedSecurity = _predictExpectedSecurity(target.ssid);
      final currentSecurity = _extractSecurityType(target.capabilities);
      
      if (expectedSecurity != null && currentSecurity != expectedSecurity) {
        if (expectedSecurity.index > currentSecurity.index) { // Weaker than expected
          issues.add('Security weaker than expected for SSID type (expected: $expectedSecurity, actual: $currentSecurity)');
          isSuspicious = true;
          confidenceScore += 0.4;
        }
      }

      // 3. Enterprise network without proper security
      if (_isEnterpriseSSID(target.ssid) && currentSecurity == SecurityType.open) {
        issues.add('Enterprise network without encryption - highly suspicious');
        isSuspicious = true;
        confidenceScore += 0.7;
      }

      // 4. Government network security validation
      if (_isGovernmentSSID(target.ssid)) {
        if (currentSecurity == SecurityType.open || currentSecurity == SecurityType.wep) {
          issues.add('Government network with inadequate security');
          isSuspicious = true;
          confidenceScore += 0.9; // Very high confidence
        }
      }

      if (isSuspicious) {
        return SecurityConfigAnalysisResult(
          isSuspicious: true,
          threat: SecurityThreat(
            type: ThreatType.securityDowngrade,
            severity: confidenceScore > 0.7 ? ThreatSeverity.high : ThreatSeverity.medium,
            description: 'Suspicious security configuration detected',
            details: issues,
            affectedSSID: target.ssid,
            suspiciousBSSID: target.bssid,
            confidenceScore: confidenceScore,
          ),
        );
      }

      return SecurityConfigAnalysisResult(isSuspicious: false);

    } catch (e) {
      developer.log('❌ Enhanced security config analysis failed: $e');
      return SecurityConfigAnalysisResult(isSuspicious: false);
    }
  }

  /// Legacy security configuration analysis

  /// Enhanced MAC analysis using OUI database
  MACAnalysisResult _analyzeMACAddressEnhanced(WiFiAccessPoint target) {
    try {
      final issues = <String>[];
      var isSuspicious = false;

      // Check OUI database for vendor information
      final vendorInfo = _ouiDatabase.lookupVendor(target.bssid);
      if (vendorInfo != null) {
        // Check if vendor is suspicious
        if (_ouiDatabase.isSuspiciousVendor(target.bssid)) {
          issues.add('MAC from suspicious vendor: ${vendorInfo.vendor} (${vendorInfo.type})');
          isSuspicious = true;
        }
        
        // Check SSID-vendor compatibility
        final compatibility = _ouiDatabase.getVendorSSIDCompatibility(target.bssid, target.ssid);
        if (compatibility < 0.3) {
          issues.add('Poor SSID-vendor compatibility: ${(compatibility * 100).toInt()}%');
          isSuspicious = true;
        }
      } else {
        // Unknown vendor is suspicious
        issues.add('Unknown MAC vendor - not in database');
        isSuspicious = true;
      }

      // Check for known malicious MACs
      if (_knownMaliciousMACs.contains(target.bssid)) {
        issues.add('MAC address found in malicious network database');
        isSuspicious = true;
      }

      if (isSuspicious) {
        return MACAnalysisResult(
          isSuspicious: true,
          threat: SecurityThreat(
            type: ThreatType.suspiciousMac,
            severity: vendorInfo?.trustLevel == oui.TrustLevel.critical ? ThreatSeverity.critical : ThreatSeverity.medium,
            description: 'Suspicious MAC address detected',
            details: issues,
            affectedSSID: target.ssid,
            suspiciousBSSID: target.bssid,
            confidenceScore: 0.7,
          ),
        );
      }

      return MACAnalysisResult(isSuspicious: false);

    } catch (e) {
      developer.log('❌ Enhanced MAC analysis failed: $e');
      return MACAnalysisResult(isSuspicious: false);
    }
  }

  /// Legacy MAC analysis (keeping for compatibility)

  /// Enhanced historical comparison with behavioral analysis
  HistoricalAnalysisResult _compareWithHistoryEnhanced(WiFiAccessPoint target) {
    try {
      if (!_networkHistory.containsKey(target.ssid)) {
        // First time seeing this network - neutral but log for future
        return HistoricalAnalysisResult(isAnomalous: false);
      }

      final historicalAPs = _networkHistory[target.ssid]!;
      final issues = <String>[];
      var isAnomalous = false;
      var confidenceScore = 0.0;

      // 1. BSSID consistency analysis  
      final recentAPs = historicalAPs.where((ap) => 
          DateTime.now().difference(DateTime.now().subtract(const Duration(hours: 24))).inHours < 24).toList();

      final recentBSSIDs = recentAPs.map((ap) => ap.bssid).toSet();
      
      // Check for BSSID changes in short time
      if (recentBSSIDs.length > 1 && !recentBSSIDs.contains(target.bssid)) {
        issues.add('New BSSID appeared for known SSID within 24 hours');
        issues.add('Recent BSSIDs: ${recentBSSIDs.join(", ")}');
        issues.add('Current BSSID: ${target.bssid}');
        isAnomalous = true;
        confidenceScore += 0.5;
      }

      // 2. Network behavior pattern analysis
      if (historicalAPs.length >= 5) {
        // Check for unusual appearance patterns
        final timeBetweenSightings = <Duration>[];
        for (int i = 1; i < historicalAPs.length; i++) {
          // This is simplified - in reality we'd track actual timestamps
          // For now, assume regular scanning intervals
          timeBetweenSightings.add(const Duration(minutes: 5));
        }
        
        // Look for networks that appear/disappear in suspicious patterns
        // This would be more sophisticated with actual timestamps
      }

      // 3. Vendor consistency check
      final historicalVendors = historicalAPs
          .map((ap) => _ouiDatabase.lookupVendor(ap.bssid)?.vendor)
          .where((vendor) => vendor != null)
          .toSet();
      
      final currentVendor = _ouiDatabase.lookupVendor(target.bssid)?.vendor;
      if (currentVendor != null && historicalVendors.isNotEmpty) {
        if (!historicalVendors.contains(currentVendor)) {
          issues.add('Different MAC vendor than historical data (was: ${historicalVendors.join(", ")}, now: $currentVendor)');
          isAnomalous = true;
          confidenceScore += 0.3;
        }
      }

      if (isAnomalous) {
        return HistoricalAnalysisResult(
          isAnomalous: true,
          threat: SecurityThreat(
            type: ThreatType.historicalAnomaly,
            severity: confidenceScore > 0.6 ? ThreatSeverity.medium : ThreatSeverity.low,
            description: 'Network behavior differs from historical patterns',
            details: issues,
            affectedSSID: target.ssid,
            suspiciousBSSID: target.bssid,
            confidenceScore: confidenceScore,
          ),
        );
      }

      return HistoricalAnalysisResult(isAnomalous: false);

    } catch (e) {
      developer.log('❌ Enhanced historical analysis failed: $e');
      return HistoricalAnalysisResult(isAnomalous: false);
    }
  }

  /// Legacy historical comparison

  /// Cross-validate threats using multiple detection methods
  List<SecurityThreat> _crossValidateThreats(
    List<SecurityThreat> threats, 
    List<ThreatEvidence> evidence, 
    double overallConfidence
  ) {
    final validatedThreats = <SecurityThreat>[];
    
    // Require higher evidence for high-severity threats
    for (final threat in threats) {
      var shouldInclude = false;
      
      switch (threat.severity) {
        case ThreatSeverity.critical:
          // Critical threats need very high confidence OR multiple evidence
          shouldInclude = threat.confidenceScore >= 0.9 || evidence.length >= 3;
          break;
        case ThreatSeverity.high:
          // High threats need high confidence OR multiple evidence
          shouldInclude = threat.confidenceScore >= 0.7 || evidence.length >= 2;
          break;
        case ThreatSeverity.medium:
          // Medium threats need moderate confidence
          shouldInclude = threat.confidenceScore >= 0.6;
          break;
        case ThreatSeverity.low:
          // Low threats accepted with basic confidence
          shouldInclude = threat.confidenceScore >= 0.4;
          break;
      }
      
      if (shouldInclude) {
        validatedThreats.add(threat);
      } else {
        developer.log('🖻 Filtered out ${threat.type} (confidence: ${threat.confidenceScore}, evidence: ${evidence.length})');
      }
    }
    
    return validatedThreats;
  }

  /// Calculate threat level based on confidence and threat types
  ThreatLevel _calculateThreatLevel(double confidence, List<SecurityThreat> threats) {
    if (threats.isEmpty) return ThreatLevel.low;
    
    // Check for critical threats
    if (threats.any((t) => t.severity == ThreatSeverity.critical)) {
      return ThreatLevel.critical;
    }
    
    // Use confidence-based calculation
    if (confidence >= 0.9) return ThreatLevel.critical;
    if (confidence >= 0.7) return ThreatLevel.high;
    if (confidence >= 0.5) return ThreatLevel.medium;
    return ThreatLevel.low;
  }

  /// Enhanced legitimate network detection
  bool _isKnownLegitimateNetworkEnhanced(WiFiAccessPoint ap) {
    // Check against fingerprint database
    final fingerprint = _legitimateNetworks[ap.ssid];
    if (fingerprint != null) {
      // Enhanced fingerprint matching with vendor validation
      final currentSecurity = _extractSecurityType(ap.capabilities);
      if (currentSecurity != fingerprint.expectedSecurity) return false;

      // Check MAC vendor compatibility
      final vendorCompatibility = _ouiDatabase.getVendorSSIDCompatibility(ap.bssid, ap.ssid);
      if (vendorCompatibility < 0.7) return false;

      return true;
    }
    
    // Check if vendor is known legitimate for router/ISP equipment
    return _ouiDatabase.isLegitimateRouterVendor(ap.bssid);
  }

  /// Analyze timing patterns for suspicious behavior

  /// Update historical data with current scan results
  void updateHistoricalData(List<WiFiAccessPoint> scanResults) {
    try {
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
      '00:13:37:00:00:00', // WiFi Pineapple range
      '00:C0:CA:00:00:00', // Alfa adapter range (common in attacks)
    ]);
  }

  /// Initialize environmental profiles for confidence calculation
  void _initializeEnvironmentalProfiles() {
    _confidenceCalculator.registerLocationProfile(
      'airport',
      const EnvironmentProfile(
        riskLevel: RiskLevel.high,
        threatMultiplier: 1.5,
        commonThreats: ['evil_twin', 'honeypot'],
        description: 'Airport - high risk environment',
      ),
    );
    
    _confidenceCalculator.registerLocationProfile(
      'government_building',
      const EnvironmentProfile(
        riskLevel: RiskLevel.government,
        threatMultiplier: 0.8, // More conservative
        commonThreats: ['government_impersonation', 'evil_twin'],
        description: 'Government building - requires higher validation',
      ),
    );
    
    _confidenceCalculator.registerLocationProfile(
      'home',
      const EnvironmentProfile(
        riskLevel: RiskLevel.low,
        threatMultiplier: 0.5,
        commonThreats: ['neighbor_spoofing'],
        description: 'Residential area - lower threat probability',
      ),
    );
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

  /// Extract security type from capabilities string
  SecurityType _extractSecurityType(String capabilities) {
    if (capabilities.contains('WPA3')) return SecurityType.wpa3;
    if (capabilities.contains('WPA2')) return SecurityType.wpa2;
    if (capabilities.contains('WPA')) return SecurityType.wpa2;
    if (capabilities.contains('WEP')) return SecurityType.wep;
    return SecurityType.open;
  }

  /// Predict expected security type based on SSID
  SecurityType? _predictExpectedSecurity(String ssid) {
    final lowerSSID = ssid.toLowerCase();
    
    // Government networks should use WPA2 minimum
    if (_isGovernmentSSID(lowerSSID)) {
      return SecurityType.wpa2;
    }
    
    // ISP networks typically use WPA2
    if (_isISPNetwork(lowerSSID)) {
      return SecurityType.wpa2;
    }
    
    // Enterprise networks should be secured
    if (_isEnterpriseSSID(lowerSSID)) {
      return SecurityType.wpa2;
    }
    
    // Home networks typically secured
    if (_isHomeNetwork(lowerSSID)) {
      return SecurityType.wpa2;
    }
    
    return null; // No prediction for other networks
  }

  /// Check if SSID indicates government network
  bool _isGovernmentSSID(String lowerSSID) {
    final govPatterns = ['dict', 'dost', 'dilg', 'deped', 'doh', 'dti', 'dswd', 
                        'calabarzon', 'region4a', 'lgu', 'municipal', 'cityhall', 
                        'government', 'official', 'gov'];
    return govPatterns.any((pattern) => lowerSSID.contains(pattern));
  }

  /// Check if SSID indicates ISP network
  bool _isISPNetwork(String lowerSSID) {
    final ispPatterns = ['pldt', 'globe', 'smart', 'converge', 'sky', 'bayantel'];
    return ispPatterns.any((pattern) => lowerSSID.contains(pattern));
  }

  /// Check if SSID indicates enterprise network
  bool _isEnterpriseSSID(String lowerSSID) {
    final enterprisePatterns = ['corp', 'company', 'office', 'enterprise', 'business', 'work'];
    return enterprisePatterns.any((pattern) => lowerSSID.contains(pattern));
  }

  /// Check if SSID indicates home network
  bool _isHomeNetwork(String lowerSSID) {
    final homePatterns = ['home', 'house', 'family', 'residence', 'private'];
    return homePatterns.any((pattern) => lowerSSID.contains(pattern));
  }

  /// Check if network is likely to be secured based on SSID

  /// Get legitimate network reference
  NetworkFingerprint? _getLegitimateNetworkReference(String ssid) {
    return _legitimateNetworks[ssid];
  }

  /// Check if network is known legitimate

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

  /// Check if SSID is similar to any whitelisted networks
  bool _hasSimilarSSIDInWhitelist(String ssid) {
    // This would integrate with the whitelist service
    // For now, return false to not trigger false positives
    // TODO: Integrate with WhitelistService to check for similar SSIDs
    return false;
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
          recommendations.add('📌 Unusual signal patterns detected - verify network location');
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

  /// Get enhanced analyzer statistics
  Map<String, dynamic> getEnhancedStats() {
    return {
      'total_analyses': _totalAnalyses,
      'threats_detected': _threatsDetected,
      'detection_rate': _totalAnalyses > 0 ? (_threatsDetected / _totalAnalyses) * 100 : 0.0,
      'network_history_size': _networkHistory.length,
      'legitimate_networks': _legitimateNetworks.length,
      'malicious_macs': _knownMaliciousMACs.length,
      'oui_database_stats': _ouiDatabase.getDatabaseStats(),
      'confidence_calculator_stats': _confidenceCalculator.getCalculatorStats(),
      'ssid_analyzer_stats': _ssidAnalyzer.getAnalyzerStats(),
      'pattern_analyzer_stats': _patternAnalyzer.getAnalyzerStats(),
    };
  }

  /// Update method accuracy based on user feedback
  void provideFeedback(String networkId, bool wasActualThreat, double confidence) {
    // This would be called when user reports false positive/negative
    _confidenceCalculator.updateMethodAccuracy('combined_analysis', wasActualThreat, confidence);
    developer.log('📝 User feedback received: $networkId, threat: $wasActualThreat, confidence: $confidence');
  }

  /// Clear all historical data and reset statistics
  void clearHistory() {
    _networkHistory.clear();
    _totalAnalyses = 0;
    _threatsDetected = 0;
    _confidenceCalculator.clearHistory();
    _patternAnalyzer.clearHistory();
    developer.log('🧹 Analyzer history cleared');
  }

  /// Dispose of resources
  void dispose() {
    _networkHistory.clear();
    _legitimateNetworks.clear();
    _knownMaliciousMACs.clear();
    _confidenceCalculator.clearHistory();
    _patternAnalyzer.clearHistory();
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