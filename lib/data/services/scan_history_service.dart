import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/scan_history_model.dart';
import '../models/network_model.dart';

class ScanHistoryService {
  static const String _historyKey = 'scan_history';
  static const String _maxEntriesKey = 'scan_history_max_entries';
  static const int _defaultMaxEntries = 100;

  late SharedPreferences _prefs;
  List<ScanHistoryEntry> _history = [];
  int _maxEntries = _defaultMaxEntries;

  List<ScanHistoryEntry> get history => List.unmodifiable(_history);
  int get maxEntries => _maxEntries;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _maxEntries = _prefs.getInt(_maxEntriesKey) ?? _defaultMaxEntries;
      await _loadHistory();
      developer.log('📚 ScanHistoryService initialized with ${_history.length} entries');
    } catch (e) {
      developer.log('❌ Error initializing ScanHistoryService: $e');
    }
  }

  /// Add a new scan entry to history
  Future<void> addScanEntry({
    required ScanType scanType,
    required Duration scanDuration,
    required int networksFound,
    required int verifiedNetworks,
    required int suspiciousNetworks,
    required int threatsDetected,
    required List<NetworkModel> networks,
    String? location,
    bool wasSuccessful = true,
    String? errorMessage,
  }) async {
    try {
      final entry = ScanHistoryEntry(
        id: _generateId(),
        timestamp: DateTime.now(),
        scanType: scanType,
        scanDuration: scanDuration,
        networksFound: networksFound,
        verifiedNetworks: verifiedNetworks,
        suspiciousNetworks: suspiciousNetworks,
        threatsDetected: threatsDetected,
        networkSummaries: networks.map((n) => NetworkSummary.fromNetworkModel(n)).toList(),
        location: location,
        wasSuccessful: wasSuccessful,
        errorMessage: errorMessage,
      );

      // Add to the beginning of the list (newest first)
      _history.insert(0, entry);

      // Maintain max entries limit
      if (_history.length > _maxEntries) {
        _history = _history.take(_maxEntries).toList();
      }

      await _saveHistory();
      developer.log('📝 Added scan entry: ${entry.networksFound} networks, ${entry.threatsDetected} threats');
    } catch (e) {
      developer.log('❌ Error adding scan entry: $e');
    }
  }

  /// Get scan history for a specific date range
  List<ScanHistoryEntry> getHistoryForDateRange(DateTime start, DateTime end) {
    return _history.where((entry) {
      return entry.timestamp.isAfter(start) && entry.timestamp.isBefore(end);
    }).toList();
  }

  /// Get scan history for today
  List<ScanHistoryEntry> getTodayHistory() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getHistoryForDateRange(startOfDay, endOfDay);
  }

  /// Get scan history for the last N days
  List<ScanHistoryEntry> getRecentHistory(int days) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    return _history.where((entry) => entry.timestamp.isAfter(cutoff)).toList();
  }

  /// Filter history by scan type
  List<ScanHistoryEntry> getHistoryByScanType(ScanType scanType) {
    return _history.where((entry) => entry.scanType == scanType).toList();
  }

  /// Search history by network SSID
  List<ScanHistoryEntry> searchByNetworkSSID(String ssid) {
    return _history.where((entry) {
      return entry.networkSummaries.any((network) => 
        network.ssid.toLowerCase().contains(ssid.toLowerCase())
      );
    }).toList();
  }

  /// Get statistics for all scans
  ScanHistoryStats getOverallStats() {
    if (_history.isEmpty) {
      return ScanHistoryStats(
        totalScans: 0,
        totalNetworksFound: 0,
        totalThreatsDetected: 0,
        totalVerifiedNetworks: 0,
        averageScanDuration: Duration.zero,
        mostCommonScanType: null,
        successRate: 0.0,
      );
    }

    final totalScans = _history.length;
    
    // Get unique networks by SSID across all scan entries
    final uniqueNetworkSSIDs = <String>{};
    for (final entry in _history) {
      for (final network in entry.networkSummaries) {
        uniqueNetworkSSIDs.add(network.ssid);
      }
    }
    final totalNetworks = uniqueNetworkSSIDs.length;
    
    final totalThreats = _history.fold<int>(0, (sum, entry) => sum + entry.threatsDetected);
    final totalVerified = _history.fold<int>(0, (sum, entry) => sum + entry.verifiedNetworks);
    final totalDuration = _history.fold<Duration>(Duration.zero, (sum, entry) => sum + entry.scanDuration);
    final successfulScans = _history.where((entry) => entry.wasSuccessful).length;

    // Find most common scan type
    final scanTypeCounts = <ScanType, int>{};
    for (final entry in _history) {
      scanTypeCounts[entry.scanType] = (scanTypeCounts[entry.scanType] ?? 0) + 1;
    }
    final mostCommonScanType = scanTypeCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b).key;

    return ScanHistoryStats(
      totalScans: totalScans,
      totalNetworksFound: totalNetworks,
      totalThreatsDetected: totalThreats,
      totalVerifiedNetworks: totalVerified,
      averageScanDuration: Duration(milliseconds: totalDuration.inMilliseconds ~/ totalScans),
      mostCommonScanType: mostCommonScanType,
      successRate: successfulScans / totalScans,
    );
  }

  /// Clear all history
  Future<void> clearHistory() async {
    try {
      _history.clear();
      await _prefs.remove(_historyKey);
      developer.log('🗑️ Scan history cleared');
    } catch (e) {
      developer.log('❌ Error clearing history: $e');
    }
  }

  /// Set maximum number of entries to keep
  Future<void> setMaxEntries(int maxEntries) async {
    try {
      _maxEntries = maxEntries;
      await _prefs.setInt(_maxEntriesKey, _maxEntries);
      
      // Trim current history if needed
      if (_history.length > _maxEntries) {
        _history = _history.take(_maxEntries).toList();
        await _saveHistory();
      }
      
      developer.log('📊 Max history entries set to $_maxEntries');
    } catch (e) {
      developer.log('❌ Error setting max entries: $e');
    }
  }

  /// Export history as JSON string
  String exportHistoryAsJson() {
    try {
      final stats = getOverallStats();
      final data = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalEntries': _history.length,
        'statistics': {
          'totalScans': stats.totalScans,
          'totalNetworksFound': stats.totalNetworksFound,
          'totalThreatsDetected': stats.totalThreatsDetected,
          'totalVerifiedNetworks': stats.totalVerifiedNetworks,
          'averageScanDuration': stats.averageScanDuration.inSeconds,
          'successRate': stats.successRate,
          'formattedSuccessRate': stats.formattedSuccessRate,
          'formattedAverageDuration': stats.formattedAverageDuration,
          'mostCommonScanType': stats.mostCommonScanType?.name,
        },
        'history': _history.map((entry) => entry.toJson()).toList(),
      };
      return jsonEncode(data);
    } catch (e) {
      developer.log('❌ Error exporting scan history: $e');
      rethrow; // Re-throw to allow UI to handle the error properly
    }
  }

  /// Export scan history as CSV string
  String exportHistoryAsCsv() {
    try {
      final buffer = StringBuffer();
      
      // CSV Header for scan entries
      buffer.writeln('Date,Time,Scan Type,Networks Found,Verified Networks,Threats Detected,Duration (seconds),Duration (formatted),Success,Error Message');
      
      // Data rows for scan entries
      for (final entry in _history) {
        final date = DateFormat('yyyy-MM-dd').format(entry.timestamp);
        final time = DateFormat('HH:mm:ss').format(entry.timestamp);
        final errorMsg = entry.errorMessage?.replaceAll('"', '""') ?? '';
        
        buffer.writeln([
          date,
          time,
          '"${entry.scanType.name.toUpperCase()}"',
          entry.networksFound,
          entry.verifiedNetworks,
          entry.threatsDetected,
          entry.scanDuration.inSeconds,
          '"${entry.formattedDuration}"',
          entry.wasSuccessful ? 'YES' : 'NO',
          '"$errorMsg"'
        ].join(','));
      }
      
      // Add networks summary
      buffer.writeln();
      buffer.writeln('NETWORKS DISCOVERED');
      buffer.writeln('SSID,Signal Strength (%),Security Type,Status,MAC Address');
      
      final allNetworks = <String, NetworkSummary>{};
      for (final entry in _history) {
        for (final network in entry.networkSummaries) {
          // Keep the most recent occurrence of each network
          if (!allNetworks.containsKey(network.ssid)) {
            allNetworks[network.ssid] = network;
          }
        }
      }
      
      for (final network in allNetworks.values) {
        buffer.writeln([
          '"${network.ssid}"',
          network.signalStrength,
          '"${network.securityType}"',
          '"${network.status.name.toUpperCase()}"',
          '"${network.macAddress ?? 'N/A'}"'
        ].join(','));
      }
      
      return buffer.toString();
    } catch (e) {
      developer.log('❌ Error exporting scan history as CSV: $e');
      rethrow;
    }
  }

  /// Export summary report as text
  String exportSummaryReport() {
    try {
      final stats = getOverallStats();
      final buffer = StringBuffer();
      
      buffer.writeln('DISCONX SCAN HISTORY SUMMARY REPORT');
      buffer.writeln('=' * 50);
      buffer.writeln('Generated: ${DateFormat('MMM dd, yyyy • HH:mm:ss').format(DateTime.now())}');
      buffer.writeln();
      
      // Overall Statistics
      buffer.writeln('SCAN STATISTICS');
      buffer.writeln('-' * 30);
      buffer.writeln('Total Scans: ${stats.totalScans}');
      buffer.writeln('Networks Found: ${stats.totalNetworksFound}');
      buffer.writeln('Verified Networks: ${stats.totalVerifiedNetworks}');
      buffer.writeln('Threats Detected: ${stats.totalThreatsDetected}');
      buffer.writeln('Success Rate: ${stats.formattedSuccessRate}');
      buffer.writeln('Average Scan Duration: ${stats.formattedAverageDuration}');
      buffer.writeln('Most Common Scan Type: ${stats.mostCommonScanType?.name.toUpperCase() ?? 'N/A'}');
      buffer.writeln();
      
      // Network Analysis
      final allNetworks = <String, NetworkSummary>{};
      final securityTypes = <String, int>{};
      final statusCounts = <NetworkStatus, int>{};
      
      for (final entry in _history) {
        for (final network in entry.networkSummaries) {
          allNetworks[network.ssid] = network;
          securityTypes[network.securityType] = (securityTypes[network.securityType] ?? 0) + 1;
          statusCounts[network.status] = (statusCounts[network.status] ?? 0) + 1;
        }
      }
      
      buffer.writeln('NETWORK ANALYSIS');
      buffer.writeln('-' * 30);
      buffer.writeln('Unique Networks Discovered: ${allNetworks.length}');
      buffer.writeln();
      
      // Security Types
      buffer.writeln('Security Types:');
      for (final entry in securityTypes.entries) {
        final percentage = entry.value / securityTypes.values.reduce((a, b) => a + b) * 100;
        buffer.writeln('  ${entry.key}: ${entry.value} (${percentage.toStringAsFixed(1)}%)');
      }
      buffer.writeln();
      
      // Network Status
      buffer.writeln('Network Status Distribution:');
      for (final entry in statusCounts.entries) {
        final percentage = entry.value / statusCounts.values.reduce((a, b) => a + b) * 100;
        buffer.writeln('  ${entry.key.name.toUpperCase()}: ${entry.value} (${percentage.toStringAsFixed(1)}%)');
      }
      buffer.writeln();
      
      // Security Recommendations
      buffer.writeln('SECURITY RECOMMENDATIONS');
      buffer.writeln('-' * 30);
      
      final openNetworks = statusCounts[NetworkStatus.unknown] ?? 0;
      final suspicious = statusCounts[NetworkStatus.suspicious] ?? 0;
      final blocked = statusCounts[NetworkStatus.blocked] ?? 0;
      
      if (openNetworks > 0) {
        buffer.writeln('• Found $openNetworks unverified networks - verify their security');
      }
      if (suspicious > 0) {
        buffer.writeln('• $suspicious suspicious networks detected - avoid connecting to these');
      }
      if (blocked > 0) {
        buffer.writeln('• $blocked blocked networks found - these are flagged as dangerous');
      }
      if (stats.totalThreatsDetected > 0) {
        buffer.writeln('• ${stats.totalThreatsDetected} total threats detected across all scans');
      }
      
      buffer.writeln('• Regularly scan for new networks in your area');
      buffer.writeln('• Only connect to verified, secure networks');
      buffer.writeln('• Report suspicious networks to network administrators');
      
      return buffer.toString();
    } catch (e) {
      developer.log('❌ Error creating scan summary report: $e');
      rethrow;
    }
  }

  /// Load history from storage
  Future<void> _loadHistory() async {
    try {
      final historyJson = _prefs.getString(_historyKey);
      if (historyJson != null) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        _history = historyList.map((json) => ScanHistoryEntry.fromJson(json)).toList();
        
        // Sort by timestamp (newest first)
        _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      developer.log('❌ Error loading history: $e');
      _history = [];
    }
  }

  /// Save history to storage
  Future<void> _saveHistory() async {
    try {
      final historyJson = jsonEncode(_history.map((entry) => entry.toJson()).toList());
      await _prefs.setString(_historyKey, historyJson);
    } catch (e) {
      developer.log('❌ Error saving history: $e');
    }
  }

  /// Generate unique ID for scan entry
  String _generateId() {
    return 'scan_${DateTime.now().millisecondsSinceEpoch}';
  }
}

class ScanHistoryStats {
  final int totalScans;
  final int totalNetworksFound;
  final int totalThreatsDetected;
  final int totalVerifiedNetworks;
  final Duration averageScanDuration;
  final ScanType? mostCommonScanType;
  final double successRate;

  ScanHistoryStats({
    required this.totalScans,
    required this.totalNetworksFound,
    required this.totalThreatsDetected,
    required this.totalVerifiedNetworks,
    required this.averageScanDuration,
    required this.mostCommonScanType,
    required this.successRate,
  });

  String get formattedAverageDuration {
    if (averageScanDuration.inMinutes > 0) {
      return '${averageScanDuration.inMinutes}m ${averageScanDuration.inSeconds % 60}s';
    }
    return '${averageScanDuration.inSeconds}s';
  }

  String get formattedSuccessRate => '${(successRate * 100).toStringAsFixed(1)}%';
}