import 'dart:developer' as developer;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../models/network_model.dart';
import '../models/scan_history_model.dart';
import '../models/alert_model.dart';
import '../models/threat_report_model.dart';
import 'geocoding_service.dart';

/// Service for reporting security threats to the central monitoring system
class ThreatReportingService {
  static final ThreatReportingService _instance = ThreatReportingService._internal();
  factory ThreatReportingService() => _instance;
  ThreatReportingService._internal();

  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  final GeocodingService _geocodingService = GeocodingService();

  /// Check if Firebase is initialized
  bool get _isFirebaseInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Lazy getter for Firestore instance
  FirebaseFirestore get firestore {
    if (_firestore == null) {
      if (!_isFirebaseInitialized) {
        throw Exception('Firebase not initialized yet for threat reporting service');
      }
      try {
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        developer.log('⚠️ Firebase not initialized yet for threat reporting service');
        rethrow;
      }
    }
    return _firestore!;
  }

  /// Lazy getter for FirebaseAuth instance  
  FirebaseAuth get auth {
    if (_auth == null) {
      if (!_isFirebaseInitialized) {
        throw Exception('Firebase not initialized yet for threat reporting service');
      }
      try {
        _auth = FirebaseAuth.instance;
      } catch (e) {
        developer.log('⚠️ Firebase Auth not initialized yet');
        rethrow;
      }
    }
    return _auth!;
  }
  
  /// Submit a threat report based on user action and scan history
  Future<String> submitThreatReport({
    required ThreatAlert alert,
    required ScanHistoryEntry scanContext,
    String? userNotes,
    String reportReason = 'app_suggested',
    bool followUpContact = false,
  }) async {
    try {
      developer.log('🚨 Submitting threat report for: ${alert.networkName}');
      
      // Ensure user is authenticated before submitting
      await _ensureAuthenticated();
      
      // Generate unique report ID
      final reportId = _generateReportId();
      
      // Build comprehensive threat report
      final reportData = await _buildThreatReportData(
        reportId: reportId,
        alert: alert,
        scanContext: scanContext,
        userNotes: userNotes,
        reportReason: reportReason,
        followUpContact: followUpContact,
      );
      
      // Submit to Firestore
      await firestore.collection('threat_reports').doc(reportId).set(reportData);
      
      // Update local scan history with report reference
      await _linkScanToReport(scanContext.id, reportId);
      
      // Log analytics event
      await _logThreatReportEvent(alert.type, alert.severity);
      
      developer.log('✅ Threat report submitted successfully: $reportId');
      return reportId;
      
    } catch (e) {
      developer.log('❌ Failed to submit threat report: $e');
      rethrow;
    }
  }
  
  /// Build comprehensive threat report data structure
  Future<Map<String, dynamic>> _buildThreatReportData({
    required String reportId,
    required ThreatAlert alert,
    required ScanHistoryEntry scanContext,
    String? userNotes,
    String reportReason = 'app_suggested',
    bool followUpContact = false,
  }) async {
    // Get device and app information
    final deviceInfo = await _getDeviceInfo();
    final packageInfo = await PackageInfo.fromPlatform();
    final currentLocation = await _getCurrentLocation();
    
    // Find suspicious network from scan context
    NetworkSummary? suspiciousNetwork;
    if (scanContext.networkSummaries.isNotEmpty) {
      suspiciousNetwork = scanContext.networkSummaries.firstWhere(
        (network) => network.ssid == alert.networkName,
        orElse: () => scanContext.networkSummaries.first,
      );
    } else if (alert.networkName != null) {
      // Create a minimal network summary for cases where scan context is empty
      suspiciousNetwork = NetworkSummary(
        ssid: alert.networkName!,
        status: NetworkStatus.suspicious,
        securityType: 'Unknown',
        signalStrength: 0,
        macAddress: alert.macAddress,
      );
    }
    
    // Try to find legitimate network for comparison (evil twin cases)
    NetworkSummary? legitimateNetwork;
    if (alert.type == AlertType.evilTwin) {
      legitimateNetwork = scanContext.networkSummaries
          .where((n) => n.ssid == alert.networkName && n.macAddress != alert.macAddress)
          .firstOrNull;
    }
    
    return {
      'id': reportId,
      
      // Report Metadata
      'reportMetadata': {
        'reportedAt': FieldValue.serverTimestamp(),
        'reportedBy': deviceInfo['deviceId'],
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'deviceInfo': deviceInfo,
      },
      
      // Threat Details
      'threat': {
        'type': _mapAlertTypeToThreatType(alert.type),
        'severity': alert.severity.name,
        'confidence': alert.confidenceScore ?? 0.75,
        'description': _generateThreatDescription(alert),
        'detectionMethod': 'system_detected',
        'indicators': alert.threatIndicators ?? [],
        'alertId': alert.id,
      },
      
      // Suspicious Network Information
      if (suspiciousNetwork != null) 'suspiciousNetwork': {
        'ssid': suspiciousNetwork.ssid,
        'bssid': alert.macAddress ?? suspiciousNetwork.macAddress ?? 'unknown',
        'securityType': suspiciousNetwork.securityType,
        'signalStrength': suspiciousNetwork.signalStrength,
        'frequency': 2.4, // Default, could be enhanced
        'capabilities': [],
        'firstSeen': scanContext.timestamp,
        'lastSeen': scanContext.timestamp,
        'isCurrentNetwork': suspiciousNetwork.isCurrentNetwork,
      },
      
      // Legitimate Network (for comparison)
      if (legitimateNetwork != null) 'legitimateNetwork': {
        'ssid': legitimateNetwork.ssid,
        'bssid': legitimateNetwork.macAddress ?? 'unknown',
        'securityType': legitimateNetwork.securityType,
        'signalStrength': legitimateNetwork.signalStrength,
        'isVerified': legitimateNetwork.status == NetworkStatus.verified,
        'isCurrentNetwork': legitimateNetwork.isCurrentNetwork,
      },
      
      // Location Information
      'location': {
        'coordinates': {
          'latitude': currentLocation?.latitude ?? 0.0,
          'longitude': currentLocation?.longitude ?? 0.0,
        },
        'address': await _getLocationAddress(currentLocation),
        'city': _geocodingService.getCityName(
          currentLocation?.latitude ?? 0.0, 
          currentLocation?.longitude ?? 0.0
        ) ?? 'Unknown',
        'province': 'CALABARZON', // Default for this region
        'accuracy': currentLocation?.accuracy ?? 0.0,
        'source': currentLocation != null ? 'gps' : 'unknown',
      },
      
      // Scan Context
      'scanContext': {
        'scanId': scanContext.id,
        'scanType': scanContext.scanType.name,
        'scanDuration': scanContext.scanDuration.inMilliseconds,
        'totalNetworksFound': scanContext.networksFound,
        'verifiedNetworksFound': scanContext.verifiedNetworks,
        'suspiciousNetworksFound': scanContext.suspiciousNetworks,
        'threatsDetected': scanContext.threatsDetected,
        'wasSuccessful': scanContext.wasSuccessful,
        'nearbyNetworks': scanContext.networkSummaries.take(10).map((n) => {
          'ssid': n.ssid,
          'bssid': n.macAddress ?? 'unknown',
          'signalStrength': n.signalStrength,
          'securityType': n.securityType,
        }).toList(),
      },
      
      // Investigation Tracking (initial state)
      'investigation': {
        'status': 'pending',
        'priority': _calculatePriority(alert.severity),
        'assignedTo': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'notes': [],
        'actions': [],
        'resolution': null,
        'resolvedAt': null,
      },
      
      // User Feedback
      'userFeedback': {
        'reportReason': reportReason,
        'additionalNotes': userNotes ?? '',
        'followUpContact': followUpContact,
        'attachments': [], // Future enhancement
      },
    };
  }
  
  /// Generate unique report ID
  String _generateReportId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'TR-${DateTime.now().year}-$timestamp';
  }
  
  /// Get device information for report metadata
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        return {
          'platform': 'android',
          'deviceId': androidInfo.id,
          'deviceModel': '${androidInfo.brand} ${androidInfo.model}',
          'osVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'manufacturer': androidInfo.manufacturer,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        return {
          'platform': 'ios',
          'deviceId': iosInfo.identifierForVendor ?? 'unknown',
          'deviceModel': '${iosInfo.name} ${iosInfo.model}',
          'osVersion': iosInfo.systemVersion,
          'manufacturer': 'Apple',
        };
      }
    } catch (e) {
      developer.log('Failed to get device info: $e');
    }
    
    return {
      'platform': 'unknown',
      'deviceId': 'unknown',
      'deviceModel': 'Unknown Device',
      'osVersion': 'Unknown',
      'manufacturer': 'Unknown',
    };
  }
  
  /// Get current location for threat report
  Future<Position?> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        return null;
      }
      
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      developer.log('Failed to get location: $e');
      return null;
    }
  }
  
  /// Get human-readable address from coordinates
  Future<String> _getLocationAddress(Position? position) async {
    if (position == null) return 'Location unavailable';
    
    try {
      // Use geocoding service or fallback to coordinates
      final cityName = _geocodingService.getCityName(position.latitude, position.longitude);
      if (cityName != null) {
        return '$cityName, CALABARZON';
      }
    } catch (e) {
      developer.log('Failed to get address: $e');
    }
    
    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  }
  
  /// Map AlertType to threat type string
  String _mapAlertTypeToThreatType(AlertType alertType) {
    switch (alertType) {
      case AlertType.evilTwin:
        return 'evil_twin';
      case AlertType.suspiciousNetwork:
        return 'suspicious_network';
      case AlertType.networkBlocked:
        return 'unauthorized_ap';
      default:
        return 'suspicious_network';
    }
  }
  
  /// Generate human-readable threat description
  String _generateThreatDescription(ThreatAlert alert) {
    switch (alert.type) {
      case AlertType.evilTwin:
        return 'Potential Evil Twin attack detected. Suspicious network "${alert.networkName}" may be impersonating a legitimate network.';
      case AlertType.suspiciousNetwork:
        return 'Suspicious network activity detected on "${alert.networkName}". Network exhibits characteristics of potential security threat.';
      case AlertType.networkBlocked:
        return 'Unauthorized access point detected. Network "${alert.networkName}" is operating in a restricted area.';
      default:
        return 'Security threat detected on network "${alert.networkName}". Further investigation recommended.';
    }
  }
  
  /// Calculate investigation priority based on severity
  String _calculatePriority(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return 'urgent';
      case AlertSeverity.high:
        return 'high';
      case AlertSeverity.medium:
        return 'medium';
      case AlertSeverity.low:
        return 'low';
    }
  }
  
  /// Link scan history entry to threat report
  Future<void> _linkScanToReport(String scanId, String reportId) async {
    try {
      // This would update local storage to link scan with report
      // Implementation depends on your local storage strategy
      developer.log('Linking scan $scanId to report $reportId');
    } catch (e) {
      developer.log('Failed to link scan to report: $e');
    }
  }
  
  /// Log analytics event for threat reporting
  Future<void> _logThreatReportEvent(AlertType alertType, AlertSeverity severity) async {
    try {
      // Log to Firebase Analytics or your analytics service
      developer.log('Logged threat report analytics: ${alertType.name} - ${severity.name}');
    } catch (e) {
      developer.log('Failed to log analytics: $e');
    }
  }
  
  /// Get threat report status
  Future<Map<String, dynamic>?> getThreatReportStatus(String reportId) async {
    try {
      final doc = await firestore.collection('threat_reports').doc(reportId).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      developer.log('Failed to get threat report status: $e');
    }
    return null;
  }
  
  /// Get user's submitted threat reports
  Future<List<Map<String, dynamic>>> getUserThreatReports(String deviceId) async {
    try {
      final querySnapshot = await firestore
          .collection('threat_reports')
          .where('reportMetadata.reportedBy', isEqualTo: deviceId)
          .orderBy('reportMetadata.reportedAt', descending: true)
          .limit(50)
          .get();
      
      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      developer.log('Failed to get user threat reports: $e');
      return [];
    }
  }
  
  /// Ensure Firebase is properly initialized before attempting operations
  Future<void> _ensureFirebaseInitialized() async {
    try {
      // Try to access Firebase to verify it's initialized
      await Firebase.initializeApp();
      developer.log('✅ Firebase initialized for threat reporting');
    } catch (e) {
      // If already initialized, this will throw but Firebase is ready
      if (e.toString().contains('already created')) {
        developer.log('✅ Firebase already initialized');
        return;
      }
      
      developer.log('❌ Firebase initialization failed: $e');
      throw Exception('Firebase is not available. Please wait for the app to fully load and try again.');
    }
  }
  
  /// Ensure user is authenticated, sign in anonymously if needed
  Future<void> _ensureAuthenticated() async {
    try {
      // Check if Firebase is initialized first
      await _ensureFirebaseInitialized();
      
      if (auth.currentUser != null) {
        developer.log('✅ User already authenticated: ${auth.currentUser!.uid}');
        return;
      }
      
      developer.log('🔐 No authentication found, signing in anonymously...');
      final userCredential = await auth.signInAnonymously();
      developer.log('✅ Anonymous authentication successful: ${userCredential.user!.uid}');
    } catch (e) {
      developer.log('❌ Failed to authenticate anonymously: $e');
      throw Exception('Authentication required to submit threat reports. Please check your connection and try again.');
    }
  }
}

extension on Iterable<NetworkSummary> {
  NetworkSummary? get firstOrNull => isEmpty ? null : first;
}