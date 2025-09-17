import 'dart:developer' as developer;
import 'dart:math' as math;
import '../models/security_assessment.dart';

/// Advanced confidence calculation system for threat detection
/// Uses Bayesian inference and multi-factor analysis
class ConfidenceCalculator {
  static final ConfidenceCalculator _instance = ConfidenceCalculator._internal();
  factory ConfidenceCalculator() => _instance;
  ConfidenceCalculator._internal();
  
  // Historical accuracy tracking for each detection method
  final Map<String, DetectionMethodStats> _methodAccuracy = {};
  
  // Environmental adjustment factors
  final Map<String, EnvironmentProfile> _locationProfiles = {};

  /// Calculate overall threat confidence using Bayesian inference
  double calculateThreatConfidence({
    required List<ThreatEvidence> evidence,
    required String networkId,
    required String ssid,
    String? currentLocation,
  }) {
    try {
      if (evidence.isEmpty) return 0.0;

      // Start with base threat probability
      double priorProbability = _calculatePriorThreatProbability(ssid, currentLocation);
      
      // Apply Bayesian updates for each piece of evidence
      double posteriorProbability = priorProbability;
      
      for (final evidenceItem in evidence) {
        posteriorProbability = _bayesianUpdate(
          posteriorProbability, 
          evidenceItem,
          networkId,
        );
      }

      // Apply environmental adjustments
      posteriorProbability = _applyEnvironmentalAdjustments(
        posteriorProbability,
        currentLocation,
        evidence.length,
      );

      // Apply consensus bonus for multiple detection methods
      posteriorProbability = _applyConsensusBonus(posteriorProbability, evidence);

      final finalConfidence = posteriorProbability.clamp(0.0, 1.0);
      
      developer.log('🎯 Confidence calculation: $finalConfidence (${evidence.length} evidence items)');
      return finalConfidence;

    } catch (e) {
      developer.log('❌ Confidence calculation failed: $e');
      return 0.5; // Neutral confidence on error
    }
  }

  /// Calculate prior threat probability based on SSID and location
  double _calculatePriorThreatProbability(String ssid, String? location) {
    double baseProbability = 0.05; // 5% base threat probability
    
    // Adjust based on SSID patterns
    final lowerSSID = ssid.toLowerCase();
    
    // Government networks have lower base probability (should be legitimate)
    if (_isGovernmentSSID(lowerSSID)) {
      baseProbability = 0.02; // 2% for government networks
    }
    
    // Open/generic networks have higher base probability
    if (_isGenericSSID(lowerSSID)) {
      baseProbability = 0.15; // 15% for generic networks
    }
    
    // ISP networks have moderate probability
    if (_isISPNetwork(lowerSSID)) {
      baseProbability = 0.08; // 8% for ISP networks
    }

    // Location-based adjustments
    if (location != null) {
      final profile = _locationProfiles[location];
      if (profile != null) {
        baseProbability *= profile.threatMultiplier;
      }
    }

    return baseProbability.clamp(0.01, 0.3);
  }

  /// Apply Bayesian update for single piece of evidence
  double _bayesianUpdate(double priorProb, ThreatEvidence evidence, String networkId) {
    // Get method accuracy statistics
    final methodStats = _methodAccuracy[evidence.detectionMethod] ?? 
        DetectionMethodStats(evidence.detectionMethod);

    // Calculate likelihood ratio
    double likelihoodRatio = _calculateLikelihoodRatio(evidence, methodStats);
    
    // Apply Bayes' theorem
    double posteriorOdds = (priorProb / (1 - priorProb)) * likelihoodRatio;
    double posteriorProb = posteriorOdds / (1 + posteriorOdds);

    // Adjust based on evidence strength
    double evidenceWeight = _calculateEvidenceWeight(evidence);
    posteriorProb = priorProb + (posteriorProb - priorProb) * evidenceWeight;

    return posteriorProb.clamp(0.0, 1.0);
  }

  /// Calculate likelihood ratio for evidence
  double _calculateLikelihoodRatio(ThreatEvidence evidence, DetectionMethodStats stats) {
    switch (evidence.severity) {
      case ThreatSeverity.critical:
        return 8.0; // Strong evidence for threat
      case ThreatSeverity.high:
        return 4.0;
      case ThreatSeverity.medium:
        return 2.0;
      case ThreatSeverity.low:
        return 1.2;
    }
  }

  /// Calculate weight of evidence based on quality and reliability
  double _calculateEvidenceWeight(ThreatEvidence evidence) {
    double weight = 1.0;
    
    // Adjust based on evidence type reliability
    switch (evidence.detectionMethod) {
      case 'evil_twin':
        weight = 0.9; // High reliability
        break;
      case 'government_impersonation':
        weight = 0.95; // Very high reliability
        break;
      case 'signal_anomaly':
        weight = 0.7; // Medium reliability
        break;
      case 'mac_analysis':
        weight = 0.6; // Lower reliability
        break;
      case 'security_config':
        weight = 0.8; // High reliability
        break;
      default:
        weight = 0.5; // Unknown method
    }

    // Adjust based on evidence freshness
    final ageMinutes = DateTime.now().difference(evidence.timestamp).inMinutes;
    if (ageMinutes > 5) {
      weight *= math.max(0.5, 1.0 - (ageMinutes / 60.0)); // Decay over time
    }

    // Adjust based on confidence score
    weight *= evidence.confidenceScore;

    return weight.clamp(0.1, 1.0);
  }

  /// Apply environmental adjustments
  double _applyEnvironmentalAdjustments(
    double confidence, 
    String? location, 
    int evidenceCount,
  ) {
    double adjustedConfidence = confidence;

    // More evidence increases confidence
    double evidenceBonus = math.min(0.2, evidenceCount * 0.05);
    adjustedConfidence += evidenceBonus;

    // Location-based adjustments
    if (location != null) {
      final profile = _locationProfiles[location];
      if (profile != null) {
        // High-risk locations (airports, malls) increase confidence
        if (profile.riskLevel == RiskLevel.high) {
          adjustedConfidence *= 1.2;
        }
        // Government buildings require higher confidence
        if (profile.riskLevel == RiskLevel.government) {
          adjustedConfidence *= 0.8; // Be more conservative
        }
      }
    }

    return adjustedConfidence.clamp(0.0, 1.0);
  }

  /// Apply consensus bonus for multiple detection methods
  double _applyConsensusBonus(double confidence, List<ThreatEvidence> evidence) {
    if (evidence.length <= 1) return confidence;

    // Get unique detection methods
    final uniqueMethods = evidence.map((e) => e.detectionMethod).toSet();
    
    // Bonus for multiple independent methods
    double consensusBonus = 0.0;
    if (uniqueMethods.length >= 2) consensusBonus = 0.15;
    if (uniqueMethods.length >= 3) consensusBonus = 0.25;
    if (uniqueMethods.length >= 4) consensusBonus = 0.35;

    // Check for method agreement
    double agreementBonus = _calculateMethodAgreement(evidence);
    
    return (confidence + consensusBonus + agreementBonus).clamp(0.0, 1.0);
  }

  /// Calculate agreement between different detection methods
  double _calculateMethodAgreement(List<ThreatEvidence> evidence) {
    if (evidence.length < 2) return 0.0;

    // Calculate variance in confidence scores
    final confidenceScores = evidence.map((e) => e.confidenceScore).toList();
    final mean = confidenceScores.reduce((a, b) => a + b) / confidenceScores.length;
    final variance = confidenceScores
        .map((score) => math.pow(score - mean, 2))
        .reduce((a, b) => a + b) / confidenceScores.length;
    
    // Lower variance = higher agreement = bonus
    final agreement = math.max(0.0, 0.2 - variance);
    return agreement;
  }

  /// Update method accuracy statistics based on feedback
  void updateMethodAccuracy(String method, bool wasCorrect, double confidence) {
    _methodAccuracy.putIfAbsent(method, () => DetectionMethodStats(method));
    _methodAccuracy[method]!.addResult(wasCorrect, confidence);
  }

  /// Register location profile for environmental adjustments
  void registerLocationProfile(String locationId, EnvironmentProfile profile) {
    _locationProfiles[locationId] = profile;
    developer.log('📍 Registered location profile: $locationId (${profile.riskLevel})');
  }

  /// Get confidence threshold for threat level
  double getConfidenceThreshold(ThreatLevel threatLevel) {
    switch (threatLevel) {
      case ThreatLevel.low:
        return 0.3;
      case ThreatLevel.medium:
        return 0.6;
      case ThreatLevel.high:
        return 0.8;
      case ThreatLevel.critical:
        return 0.9;
    }
  }

  /// Helper methods for SSID classification
  bool _isGovernmentSSID(String ssid) {
    return ssid.contains('dict') || ssid.contains('gov') || 
           ssid.contains('dost') || ssid.contains('calabarzon');
  }

  bool _isGenericSSID(String ssid) {
    final genericPatterns = ['wifi', 'internet', 'free', 'public', 'guest'];
    return genericPatterns.any((pattern) => ssid.contains(pattern));
  }

  bool _isISPNetwork(String ssid) {
    return ssid.contains('pldt') || ssid.contains('globe') || 
           ssid.contains('smart') || ssid.contains('converge');
  }

  /// Get statistics for monitoring
  Map<String, dynamic> getCalculatorStats() {
    return {
      'method_accuracy': _methodAccuracy.map((k, v) => MapEntry(k, v.toMap())),
      'location_profiles': _locationProfiles.length,
      'total_calculations': _methodAccuracy.values
          .map((stats) => stats.totalCalculations)
          .fold(0, (a, b) => a + b),
    };
  }

  /// Clear historical data (for testing)
  void clearHistory() {
    _methodAccuracy.clear();
    _locationProfiles.clear();
  }
}

/// Evidence item for threat detection
class ThreatEvidence {
  final String detectionMethod;
  final ThreatSeverity severity;
  final double confidenceScore;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  ThreatEvidence({
    required this.detectionMethod,
    required this.severity,
    required this.confidenceScore,
    DateTime? timestamp,
    this.details = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  double get severityWeight {
    switch (severity) {
      case ThreatSeverity.critical: return 1.0;
      case ThreatSeverity.high: return 0.8;
      case ThreatSeverity.medium: return 0.6;
      case ThreatSeverity.low: return 0.4;
    }
  }
}

/// Statistics for detection method accuracy
class DetectionMethodStats {
  final String method;
  int correctDetections = 0;
  int totalDetections = 0;
  double totalConfidence = 0.0;
  int totalCalculations = 0;

  DetectionMethodStats(this.method);

  void addResult(bool wasCorrect, double confidence) {
    totalDetections++;
    totalConfidence += confidence;
    totalCalculations++;
    
    if (wasCorrect) correctDetections++;
  }

  double get accuracy => totalDetections > 0 ? correctDetections / totalDetections : 0.5;
  double get averageConfidence => totalCalculations > 0 ? totalConfidence / totalCalculations : 0.5;

  Map<String, dynamic> toMap() {
    return {
      'method': method,
      'accuracy': accuracy,
      'total_detections': totalDetections,
      'correct_detections': correctDetections,
      'average_confidence': averageConfidence,
    };
  }
}

/// Environment profile for location-based adjustments
class EnvironmentProfile {
  final RiskLevel riskLevel;
  final double threatMultiplier;
  final List<String> commonThreats;
  final String description;

  const EnvironmentProfile({
    required this.riskLevel,
    required this.threatMultiplier,
    required this.commonThreats,
    required this.description,
  });
}

/// Risk levels for different environments
enum RiskLevel {
  low,        // Home, secure office
  medium,     // Coffee shops, hotels
  high,       // Airports, malls, public areas
  government, // Government buildings
}