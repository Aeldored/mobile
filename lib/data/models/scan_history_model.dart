import 'package:flutter/material.dart';
import 'network_model.dart';

enum ScanType { 
  manual, 
  background, 
  scheduled,
  startup
}

class ScanHistoryEntry {
  final String id;
  final DateTime timestamp;
  final ScanType scanType;
  final Duration scanDuration;
  final int networksFound;
  final int verifiedNetworks;
  final int suspiciousNetworks;
  final int threatsDetected;
  final List<NetworkSummary> networkSummaries;
  final String? location;
  final bool wasSuccessful;
  final String? errorMessage;

  ScanHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.scanType,
    required this.scanDuration,
    required this.networksFound,
    required this.verifiedNetworks,
    required this.suspiciousNetworks,
    required this.threatsDetected,
    required this.networkSummaries,
    this.location,
    this.wasSuccessful = true,
    this.errorMessage,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'scanType': scanType.name,
      'scanDuration': scanDuration.inMilliseconds,
      'networksFound': networksFound,
      'verifiedNetworks': verifiedNetworks,
      'suspiciousNetworks': suspiciousNetworks,
      'threatsDetected': threatsDetected,
      'networkSummaries': networkSummaries.map((n) => n.toJson()).toList(),
      'location': location,
      'wasSuccessful': wasSuccessful,
      'errorMessage': errorMessage,
    };
  }

  // Create from JSON
  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ScanHistoryEntry(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      scanType: ScanType.values.firstWhere(
        (e) => e.name == json['scanType'],
        orElse: () => ScanType.manual,
      ),
      scanDuration: Duration(milliseconds: json['scanDuration']),
      networksFound: json['networksFound'],
      verifiedNetworks: json['verifiedNetworks'],
      suspiciousNetworks: json['suspiciousNetworks'],
      threatsDetected: json['threatsDetected'],
      networkSummaries: (json['networkSummaries'] as List<dynamic>)
          .map((n) => NetworkSummary.fromJson(n))
          .toList(),
      location: json['location'],
      wasSuccessful: json['wasSuccessful'] ?? true,
      errorMessage: json['errorMessage'],
    );
  }

  String get formattedDuration {
    if (scanDuration.inMinutes > 0) {
      return '${scanDuration.inMinutes}m ${scanDuration.inSeconds % 60}s';
    }
    return '${scanDuration.inSeconds}s';
  }

  String get scanTypeDisplayName {
    switch (scanType) {
      case ScanType.manual:
        return 'Manual Scan';
      case ScanType.background:
        return 'Background Scan';
      case ScanType.scheduled:
        return 'Scheduled Scan';
      case ScanType.startup:
        return 'Startup Scan';
    }
  }

  IconData get scanTypeIcon {
    switch (scanType) {
      case ScanType.manual:
        return Icons.touch_app;
      case ScanType.background:
        return Icons.schedule;
      case ScanType.scheduled:
        return Icons.event_repeat;
      case ScanType.startup:
        return Icons.power_settings_new;
    }
  }

  Color get scanTypeColor {
    switch (scanType) {
      case ScanType.manual:
        return Colors.blue;
      case ScanType.background:
        return Colors.green;
      case ScanType.scheduled:
        return Colors.orange;
      case ScanType.startup:
        return Colors.purple;
    }
  }
}

class NetworkSummary {
  final String ssid;
  final NetworkStatus status;
  final String securityType;
  final int signalStrength;
  final bool isCurrentNetwork;
  final String? macAddress;

  NetworkSummary({
    required this.ssid,
    required this.status,
    required this.securityType,
    required this.signalStrength,
    this.isCurrentNetwork = false,
    this.macAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'ssid': ssid,
      'status': status.name,
      'securityType': securityType,
      'signalStrength': signalStrength,
      'isCurrentNetwork': isCurrentNetwork,
      'macAddress': macAddress,
    };
  }

  factory NetworkSummary.fromJson(Map<String, dynamic> json) {
    return NetworkSummary(
      ssid: json['ssid'],
      status: NetworkStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => NetworkStatus.unknown,
      ),
      securityType: json['securityType'],
      signalStrength: json['signalStrength'],
      isCurrentNetwork: json['isCurrentNetwork'] ?? false,
      macAddress: json['macAddress'],
    );
  }

  factory NetworkSummary.fromNetworkModel(NetworkModel network) {
    return NetworkSummary(
      ssid: network.name,
      status: network.status,
      securityType: network.securityTypeString,
      signalStrength: network.signalStrength,
      isCurrentNetwork: network.isConnected,
      macAddress: network.macAddress,
    );
  }
}