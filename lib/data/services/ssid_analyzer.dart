import 'dart:developer' as developer;
import 'dart:math' as math;

/// Advanced SSID analysis for typosquatting and impersonation detection
class SSIDAnalyzer {
  static final SSIDAnalyzer _instance = SSIDAnalyzer._internal();
  factory SSIDAnalyzer() => _instance;
  SSIDAnalyzer._internal();

  // Philippine government and ISP networks database
  static const List<String> _legitimateNetworks = [
    // Government networks
    'DICT-CALABARZON',
    'DICT_CALABARZON',
    'dict-calabarzon',
    'DOST-REGION4A',
    'DILG-CALABARZON',
    'DEPED-REGION4A',
    'DOH-CALABARZON',
    'DTI-REGION4A',
    'DSWD-CALABARZON',
    'LGU-BATANGAS',
    'LGU-CAVITE',
    'LGU-LAGUNA',
    'LGU-QUEZON',
    'LGU-RIZAL',
    'MUNICIPAL-HALL',
    'CITY-HALL',
    'GOVERNMENT-FREE-WIFI',
    'PISO-NET',
    
    // Major ISP networks
    'PLDT_HOME',
    'PLDTMyDSL',
    'PLDT_FIBR',
    'Globe_Broadband',
    'GlobeDSL',
    'Globe_LTE',
    'Smart_Bro',
    'SmartWiFi',
    'Converge',
    'Sky_Broadband',
    'BAYANTEL',
    
    // Common legitimate patterns
    'HOME-WIFI',
    'OFFICE-WIFI',
    'FAMILY-WIFI',
    'PRIVATE-NETWORK',
  ];

  // Common typosquatting patterns
  static const Map<String, List<String>> _typosquattingPatterns = {
    'DICT': ['D1CT', 'DIGT', 'DJCT', 'DICL', 'DiCT', 'DICT_', '_DICT'],
    'PLDT': ['PIDT', 'PLDT_', '_PLDT', 'PLDl', 'P1DT', 'PLDr'],
    'GLOBE': ['GL0BE', 'GLOVE', 'GLOBE_', '_GLOBE', 'GLoBE', 'Gl0be'],
    'SMART': ['SM4RT', 'SMRT', 'SMART_', '_SMART', 'sMARt', 'SmARt'],
    'WIFI': ['WlFl', 'W1F1', 'WiFl', 'W1Fi', 'WJFI', 'WIF1'],
    'FREE': ['FR33', 'FR3E', 'FRE3', 'FREE_', '_FREE', 'Fr33'],
    'GOV': ['G0V', 'GOV_', '_GOV', 'g0v', 'Gov'],
    'OFFICE': ['0FFICE', 'OFFIC3', 'OFF1CE', 'OFFICE_', '_OFFICE'],
  };

  // Character substitution patterns
  static const Map<String, List<String>> _characterSubstitutions = {
    'A': ['4', '@', 'Α'], // Greek Alpha
    'E': ['3', '€'],
    'I': ['1', 'l', '!', 'ı'], // Turkish dotless i
    'O': ['0', 'Ο'], // Greek Omicron
    'S': ['5', '\$', 'Ѕ'], // Cyrillic S
    'T': ['7', 'Т'], // Cyrillic T
    'G': ['6', 'G'],
    'L': ['1', 'I'],
    'C': ['G', '('],
    'D': ['O', '0'],
  };

  /// Analyze SSID for suspicious patterns and similarities
  SSIDAnalysisResult analyzeSSID(String targetSSID, List<String> allSSIDs) {
    try {
      developer.log('🔍 Analyzing SSID: $targetSSID');

      final suspiciousFactors = <String>[];
      var suspicionScore = 0.0;

      // 1. Check for typosquatting against legitimate networks
      final typosquattingResult = _detectTyposquatting(targetSSID);
      if (typosquattingResult.isDetected) {
        suspiciousFactors.addAll(typosquattingResult.evidence);
        suspicionScore += 0.6; // High weight for typosquatting
      }

      // 2. Check for character substitution attacks
      final substitutionResult = _detectCharacterSubstitution(targetSSID);
      if (substitutionResult.isDetected) {
        suspiciousFactors.addAll(substitutionResult.evidence);
        suspicionScore += 0.5;
      }

      // 3. Check for homograph attacks (unicode spoofing)
      final homographResult = _detectHomographAttack(targetSSID);
      if (homographResult.isDetected) {
        suspiciousFactors.addAll(homographResult.evidence);
        suspicionScore += 0.7; // Very high weight
      }

      // 4. Check for whitespace manipulation
      final whitespaceResult = _detectWhitespaceManipulation(targetSSID);
      if (whitespaceResult.isDetected) {
        suspiciousFactors.addAll(whitespaceResult.evidence);
        suspicionScore += 0.3;
      }

      // 5. Check similarity to other SSIDs in scan
      final similarityResult = _detectSimilarSSIDs(targetSSID, allSSIDs);
      if (similarityResult.isDetected) {
        suspiciousFactors.addAll(similarityResult.evidence);
        suspicionScore += 0.4;
      }

      // 6. Check for government impersonation patterns
      final govImpersonationResult = _detectGovernmentImpersonation(targetSSID);
      if (govImpersonationResult.isDetected) {
        suspiciousFactors.addAll(govImpersonationResult.evidence);
        suspicionScore += 0.8; // Very high weight
      }

      // 7. Check for generic/suspicious patterns
      final genericResult = _detectGenericSuspiciousPatterns(targetSSID);
      if (genericResult.isDetected) {
        suspiciousFactors.addAll(genericResult.evidence);
        suspicionScore += 0.2;
      }

      final confidenceScore = math.min(1.0, suspicionScore);
      final isDetected = confidenceScore >= 0.5; // Threshold for SSID-based detection

      developer.log('📊 SSID analysis complete: score=$confidenceScore, factors=${suspiciousFactors.length}');

      return SSIDAnalysisResult(
        isDetected: isDetected,
        confidenceScore: confidenceScore,
        suspiciousFactors: suspiciousFactors,
        legitimateSSIDMatches: _findLegitimateMatches(targetSSID),
        analysisTimestamp: DateTime.now(),
      );

    } catch (e) {
      developer.log('❌ SSID analysis failed: $e');
      return SSIDAnalysisResult(
        isDetected: false,
        confidenceScore: 0.0,
        suspiciousFactors: ['Analysis error: $e'],
        legitimateSSIDMatches: [],
        analysisTimestamp: DateTime.now(),
      );
    }
  }

  /// Detect typosquatting attacks against known legitimate networks
  DetectionResult _detectTyposquatting(String ssid) {
    final evidence = <String>[];
    
    for (final legitimate in _legitimateNetworks) {
      final distance = _calculateLevenshteinDistance(ssid.toLowerCase(), legitimate.toLowerCase());
      final similarity = 1.0 - (distance / math.max(ssid.length, legitimate.length));
      
      // If very similar but not exact match
      if (similarity >= 0.8 && ssid.toLowerCase() != legitimate.toLowerCase()) {
        evidence.add('Similar to legitimate network "$legitimate" (${(similarity * 100).toInt()}% match)');
      }
      
      // Check for known typosquatting patterns
      for (final entry in _typosquattingPatterns.entries) {
        if (legitimate.toUpperCase().contains(entry.key)) {
          for (final typo in entry.value) {
            if (ssid.toUpperCase().contains(typo)) {
              evidence.add('Contains known typosquatting pattern "$typo" targeting "${entry.key}"');
            }
          }
        }
      }
    }

    return DetectionResult(
      isDetected: evidence.isNotEmpty,
      evidence: evidence,
    );
  }

  /// Detect character substitution attacks
  DetectionResult _detectCharacterSubstitution(String ssid) {
    final evidence = <String>[];
    
    for (final entry in _characterSubstitutions.entries) {
      final originalChar = entry.key;
      final substitutes = entry.value;
      
      for (final substitute in substitutes) {
        if (ssid.contains(substitute)) {
          // Check if this could be a substitution for a legitimate network
          final reconstructed = ssid.replaceAll(substitute, originalChar);
          
          for (final legitimate in _legitimateNetworks) {
            if (reconstructed.toLowerCase() == legitimate.toLowerCase()) {
              evidence.add('Character substitution detected: "$substitute" → "$originalChar" (targeting "$legitimate")');
            }
          }
        }
      }
    }

    return DetectionResult(
      isDetected: evidence.isNotEmpty,
      evidence: evidence,
    );
  }

  /// Detect homograph attacks using similar-looking unicode characters
  DetectionResult _detectHomographAttack(String ssid) {
    final evidence = <String>[];
    
    // Check for mixed scripts
    bool hasLatin = false;
    bool hasCyrillic = false;
    bool hasGreek = false;
    
    for (int i = 0; i < ssid.length; i++) {
      final char = ssid.codeUnitAt(i);
      
      // Latin: 0x0041-0x007A
      if ((char >= 0x0041 && char <= 0x005A) || (char >= 0x0061 && char <= 0x007A)) {
        hasLatin = true;
      }
      // Cyrillic: 0x0400-0x04FF
      else if (char >= 0x0400 && char <= 0x04FF) {
        hasCyrillic = true;
      }
      // Greek: 0x0370-0x03FF
      else if (char >= 0x0370 && char <= 0x03FF) {
        hasGreek = true;
      }
    }
    
    if ((hasLatin && hasCyrillic) || (hasLatin && hasGreek)) {
      evidence.add('Mixed character scripts detected - possible homograph attack');
    }
    
    // Check for specific homograph characters
    final homographs = {
      'А': 'A', // Cyrillic A looks like Latin A
      'Е': 'E', // Cyrillic E looks like Latin E
      'О': 'O', // Cyrillic O looks like Latin O
      'Р': 'P', // Cyrillic P looks like Latin P
      'С': 'C', // Cyrillic C looks like Latin C
      'Т': 'T', // Cyrillic T looks like Latin T
      'Х': 'X', // Cyrillic X looks like Latin X
      'Ѕ': 'S', // Cyrillic S looks like Latin S
      'Α': 'A', // Greek Alpha looks like Latin A
      'Ο': 'O', // Greek Omicron looks like Latin O
    };
    
    for (final entry in homographs.entries) {
      if (ssid.contains(entry.key)) {
        evidence.add('Homograph character detected: "${entry.key}" (looks like "${entry.value}")');
      }
    }

    return DetectionResult(
      isDetected: evidence.isNotEmpty,
      evidence: evidence,
    );
  }

  /// Detect whitespace and special character manipulation
  DetectionResult _detectWhitespaceManipulation(String ssid) {
    final evidence = <String>[];
    
    // Check for leading/trailing whitespace
    if (ssid != ssid.trim()) {
      evidence.add('Leading or trailing whitespace detected');
    }
    
    // Check for unusual whitespace characters
    if (ssid.contains('\u00A0')) { // Non-breaking space
      evidence.add('Non-breaking space character detected');
    }
    
    if (ssid.contains('\u2000')) { // En quad
      evidence.add('Unusual whitespace character detected (en quad)');
    }
    
    // Check for zero-width characters
    if (ssid.contains('\u200B') || ssid.contains('\u200C') || ssid.contains('\u200D')) {
      evidence.add('Zero-width character detected - possible steganographic attack');
    }

    return DetectionResult(
      isDetected: evidence.isNotEmpty,
      evidence: evidence,
    );
  }

  /// Detect similar SSIDs in the current scan
  DetectionResult _detectSimilarSSIDs(String targetSSID, List<String> allSSIDs) {
    final evidence = <String>[];
    
    for (final otherSSID in allSSIDs) {
      if (otherSSID == targetSSID) continue;
      
      final distance = _calculateLevenshteinDistance(targetSSID.toLowerCase(), otherSSID.toLowerCase());
      final similarity = 1.0 - (distance / math.max(targetSSID.length, otherSSID.length));
      
      // Very similar SSIDs in the same scan are suspicious
      if (similarity >= 0.85) {
        evidence.add('Very similar to nearby network "$otherSSID" (${(similarity * 100).toInt()}% match)');
      }
    }

    return DetectionResult(
      isDetected: evidence.isNotEmpty,
      evidence: evidence,
    );
  }

  /// Detect government network impersonation
  DetectionResult _detectGovernmentImpersonation(String ssid) {
    final evidence = <String>[];
    final lowerSSID = ssid.toLowerCase();
    
    final governmentPatterns = [
      'dict', 'dost', 'dilg', 'deped', 'doh', 'dti', 'dswd',
      'calabarzon', 'region4a', 'lgu', 'municipal', 'city_hall',
      'government', 'official', 'gov'
    ];
    
    for (final pattern in governmentPatterns) {
      if (lowerSSID.contains(pattern)) {
        // Check if it matches exactly a known legitimate government network
        bool isLegitimate = _legitimateNetworks
            .any((legitimate) => legitimate.toLowerCase() == lowerSSID);
        
        if (!isLegitimate) {
          evidence.add('Contains government pattern "$pattern" but not in legitimate database');
        }
      }
    }

    return DetectionResult(
      isDetected: evidence.isNotEmpty,
      evidence: evidence,
    );
  }

  /// Detect generic suspicious patterns
  DetectionResult _detectGenericSuspiciousPatterns(String ssid) {
    final evidence = <String>[];
    final lowerSSID = ssid.toLowerCase();
    
    // Too generic names
    final genericNames = ['wifi', 'internet', 'free', 'public', 'guest', 'default'];
    for (final generic in genericNames) {
      if (lowerSSID == generic) {
        evidence.add('Generic network name "$generic" - commonly used by attackers');
      }
    }
    
    // Suspicious marketing terms
    final marketingTerms = ['free_wifi', 'fast_internet', 'unlimited', 'premium'];
    for (final term in marketingTerms) {
      if (lowerSSID.contains(term.replaceAll('_', ''))) {
        evidence.add('Contains marketing term "$term" - common in malicious hotspots');
      }
    }
    
    // Check for excessive length (over 32 characters is suspicious)
    if (ssid.length > 32) {
      evidence.add('Unusually long SSID (${ssid.length} characters) - possible buffer overflow attempt');
    }
    
    // Check for all caps with numbers (common pattern in cheap routers)
    if (ssid.length > 8 && ssid == ssid.toUpperCase() && 
        RegExp(r'[0-9]').hasMatch(ssid) && 
        !RegExp(r'[a-z]').hasMatch(ssid)) {
      evidence.add('All caps with numbers pattern - common in cheap/malicious devices');
    }

    return DetectionResult(
      isDetected: evidence.isNotEmpty,
      evidence: evidence,
    );
  }

  /// Calculate Levenshtein distance between two strings
  int _calculateLevenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<List<int>> matrix = List.generate(
      s1.length + 1, 
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
        matrix[i][j] = math.min(
          math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Find legitimate networks that closely match the target SSID
  List<String> _findLegitimateMatches(String targetSSID) {
    final matches = <String>[];
    
    for (final legitimate in _legitimateNetworks) {
      final distance = _calculateLevenshteinDistance(targetSSID.toLowerCase(), legitimate.toLowerCase());
      final similarity = 1.0 - (distance / math.max(targetSSID.length, legitimate.length));
      
      if (similarity >= 0.7) {
        matches.add(legitimate);
      }
    }
    
    return matches;
  }

  /// Get analyzer statistics
  Map<String, dynamic> getAnalyzerStats() {
    return {
      'legitimate_networks': _legitimateNetworks.length,
      'typosquatting_patterns': _typosquattingPatterns.length,
      'character_substitutions': _characterSubstitutions.length,
    };
  }
}

/// Result of SSID analysis
class SSIDAnalysisResult {
  final bool isDetected;
  final double confidenceScore;
  final List<String> suspiciousFactors;
  final List<String> legitimateSSIDMatches;
  final DateTime analysisTimestamp;

  SSIDAnalysisResult({
    required this.isDetected,
    required this.confidenceScore,
    required this.suspiciousFactors,
    required this.legitimateSSIDMatches,
    required this.analysisTimestamp,
  });

  @override
  String toString() {
    return 'SSIDAnalysisResult(detected: $isDetected, confidence: $confidenceScore, factors: ${suspiciousFactors.length})';
  }
}

/// Generic detection result
class DetectionResult {
  final bool isDetected;
  final List<String> evidence;

  DetectionResult({
    required this.isDetected,
    required this.evidence,
  });
}