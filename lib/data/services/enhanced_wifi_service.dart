import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../models/network_model.dart';
import '../models/security_assessment.dart';
import '../models/wifi_connection_result.dart';
import 'security_analyzer.dart';
import 'wifi_scanning_service.dart';
import 'wifi_connection_service.dart';
import 'native_wifi_controller.dart';

/// Enhanced Wi-Fi service that provides comprehensive security-focused network management
/// Integrates with existing DisConX architecture while adding advanced Evil Twin detection
class EnhancedWiFiService {
  static final EnhancedWiFiService _instance = EnhancedWiFiService._internal();
  factory EnhancedWiFiService() => _instance;
  EnhancedWiFiService._internal();

  // Core services integration
  final WiFiScanningService _scanningService = WiFiScanningService();
  final WiFiConnectionService _connectionService = WiFiConnectionService();
  final NativeWiFiController _nativeController = NativeWiFiController();
  final SecurityAnalyzer _securityAnalyzer = SecurityAnalyzer();

  // Platform channel for additional native functionality
  static const MethodChannel _platform = MethodChannel('com.dict.disconx/enhanced_wifi');

  // Real-time monitoring
  Timer? _securityMonitorTimer;
  final StreamController<List<NetworkModel>> _enhancedNetworkStream = 
      StreamController<List<NetworkModel>>.broadcast();
  final StreamController<List<SecurityAssessment>> _securityAssessmentStream = 
      StreamController<List<SecurityAssessment>>.broadcast();

  // Security state
  final Map<String, SecurityAssessment> _networkAssessments = {};
  final Set<String> _monitoredNetworks = {};
  bool _isMonitoringActive = false;
  DateTime _lastSecurityScan = DateTime.now();

  /// Initialize the enhanced Wi-Fi service
  Future<bool> initialize() async {
    try {
      developer.log('🛡️ Initializing EnhancedWiFiService with Evil Twin detection');
      
      // Initialize core services
      final scanServiceReady = await _scanningService.initialize();
      if (!scanServiceReady) {
        developer.log('❌ WiFiScanningService failed to initialize');
        return false;
      }

      await _connectionService.initialize();
      await _nativeController.initialize();
      
      // Initialize security analyzer
      await _securityAnalyzer.initialize();

      // Set up platform channel
      _platform.setMethodCallHandler(_handleMethodCall);

      developer.log('✅ EnhancedWiFiService initialized successfully');
      return true;

    } catch (e) {
      developer.log('❌ Failed to initialize EnhancedWiFiService: $e');
      return false;
    }
  }

  /// Handle platform method calls
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNetworkStateChange':
        await _handleNetworkStateChange(call.arguments);
        break;
      case 'onSecurityAlert':
        await _handleSecurityAlert(call.arguments);
        break;
      default:
        developer.log('Unknown method call: ${call.method}');
    }
  }

  /// Perform enhanced network scan with security analysis
  Future<List<NetworkModel>> scanNetworksWithSecurityAnalysis() async {
    try {
      developer.log('🔍 Starting enhanced network scan with security analysis');
      
      _lastSecurityScan = DateTime.now();

      // Perform base network scan
      final networks = await _scanningService.performScan();
      
      if (networks.isEmpty) {
        developer.log('⚠️ No networks found in scan');
        return networks;
      }

      // Get raw scan results for security analysis
      final rawScanResults = await WiFiScan.instance.getScannedResults();
      
      // Update security analyzer with latest data
      _securityAnalyzer.updateHistoricalData(rawScanResults);

      // Perform security analysis on each network
      final enhancedNetworks = <NetworkModel>[];
      final assessments = <SecurityAssessment>[];

      for (int i = 0; i < networks.length && i < rawScanResults.length; i++) {
        final network = networks[i];
        final rawAP = rawScanResults[i];

        try {
          // Perform comprehensive security analysis
          final assessment = await _securityAnalyzer.analyzeNetwork(rawAP, rawScanResults);
          assessments.add(assessment);
          _networkAssessments[network.id] = assessment;

          // Update network status based on security analysis
          final enhancedNetwork = _enhanceNetworkWithSecurityData(network, assessment);
          enhancedNetworks.add(enhancedNetwork);

          developer.log('🛡️ ${network.name}: ${assessment.threatLevel.displayName} (${assessment.detectedThreats.length} threats)');

        } catch (e) {
          developer.log('❌ Security analysis failed for ${network.name}: $e');
          enhancedNetworks.add(network); // Add without enhancement
        }
      }

      // Emit security assessments
      _securityAssessmentStream.add(assessments);

      // Emit enhanced networks
      _enhancedNetworkStream.add(enhancedNetworks);

      developer.log('✅ Enhanced scan completed: ${enhancedNetworks.length} networks analyzed');
      return enhancedNetworks;

    } catch (e) {
      developer.log('❌ Enhanced network scan failed: $e');
      return [];
    }
  }

  /// Start continuous security monitoring
  Stream<List<NetworkModel>> startSecurityMonitoring({
    Duration scanInterval = const Duration(seconds: 15),
    Duration alertCheckInterval = const Duration(seconds: 5),
  }) {
    try {
      developer.log('🔄 Starting continuous security monitoring');
      
      if (_isMonitoringActive) {
        developer.log('⚠️ Security monitoring already active');
        return _enhancedNetworkStream.stream;
      }

      _isMonitoringActive = true;

      // Start periodic security scans
      _securityMonitorTimer = Timer.periodic(scanInterval, (timer) async {
        try {
          await scanNetworksWithSecurityAnalysis();
          await _checkForSecurityAlerts();
        } catch (e) {
          developer.log('❌ Security monitoring error: $e');
        }
      });

      // Perform initial scan
      scanNetworksWithSecurityAnalysis();

      return _enhancedNetworkStream.stream;

    } catch (e) {
      developer.log('❌ Failed to start security monitoring: $e');
      return _enhancedNetworkStream.stream;
    }
  }

  /// Stop continuous security monitoring
  void stopSecurityMonitoring() {
    try {
      developer.log('🛑 Stopping security monitoring');
      
      _securityMonitorTimer?.cancel();
      _securityMonitorTimer = null;
      _isMonitoringActive = false;
      _monitoredNetworks.clear();
      
    } catch (e) {
      developer.log('❌ Error stopping security monitoring: $e');
    }
  }

  /// Connect to network with security verification
  Future<WiFiConnectionResult> connectToNetworkSecurely({
    required NetworkModel network,
    String? password,
    bool performPreConnectionAnalysis = true,
  }) async {
    try {
      developer.log('🔐 Attempting secure connection to: ${network.name}');

      // Perform pre-connection security analysis if requested
      if (performPreConnectionAnalysis) {
        final assessment = await getNetworkSecurityAssessment(network.id);
        
        if (assessment != null && assessment.shouldAvoidConnection) {
          developer.log('🚨 Connection blocked due to security assessment: ${assessment.threatLevel.displayName}');
          return WiFiConnectionResult.error;
        }
      }

      // Use existing connection service for actual connection
      final result = await _connectionService.connectToNetwork(
        // We need a BuildContext here - this would need to be passed in or handled differently
        // For now, we'll use the native controller directly
        null as dynamic, // This needs to be fixed in real implementation
        network,
        password: password,
        autoConnect: false,
      );

      // Monitor connection for security after successful connection
      if (result == WiFiConnectionResult.success) {
        _startPostConnectionMonitoring(network);
      }

      return result;

    } catch (e) {
      developer.log('❌ Secure connection failed: $e');
      return WiFiConnectionResult.error;
    }
  }

  /// Get security assessment for a specific network
  Future<SecurityAssessment?> getNetworkSecurityAssessment(String networkId) async {
    try {
      // Return cached assessment if available and recent
      final cached = _networkAssessments[networkId];
      if (cached != null && cached.isRecent) {
        return cached;
      }

      // If not cached or outdated, trigger a new scan
      await scanNetworksWithSecurityAnalysis();
      return _networkAssessments[networkId];

    } catch (e) {
      developer.log('❌ Failed to get security assessment: $e');
      return null;
    }
  }

  /// Get all current security assessments
  List<SecurityAssessment> getCurrentSecurityAssessments() {
    return _networkAssessments.values.toList();
  }

  /// Get security assessments stream
  Stream<List<SecurityAssessment>> get securityAssessmentStream => _securityAssessmentStream.stream;

  /// Get enhanced networks stream
  Stream<List<NetworkModel>> get enhancedNetworkStream => _enhancedNetworkStream.stream;

  /// Check if security monitoring is active
  bool get isMonitoringActive => _isMonitoringActive;

  /// Get time since last security scan
  Duration get timeSinceLastScan => DateTime.now().difference(_lastSecurityScan);

  /// Force security analysis refresh
  Future<void> refreshSecurityAnalysis() async {
    try {
      developer.log('🔄 Forcing security analysis refresh');
      await scanNetworksWithSecurityAnalysis();
    } catch (e) {
      developer.log('❌ Security refresh failed: $e');
    }
  }

  /// Get high-risk networks from current assessments
  List<SecurityAssessment> getHighRiskNetworks() {
    return _networkAssessments.values
        .where((assessment) => 
            assessment.threatLevel == ThreatLevel.high || 
            assessment.threatLevel == ThreatLevel.critical)
        .toList();
  }

  /// Get networks with evil twin threats
  List<SecurityAssessment> getEvilTwinThreats() {
    return _networkAssessments.values
        .where((assessment) => 
            assessment.detectedThreats.any((threat) => 
                threat.type == ThreatType.evilTwin))
        .toList();
  }

  /// Private methods

  /// Enhance network model with security data
  NetworkModel _enhanceNetworkWithSecurityData(NetworkModel network, SecurityAssessment assessment) {
    // Update network status based on security assessment
    NetworkStatus newStatus = network.status;
    
    switch (assessment.threatLevel) {
      case ThreatLevel.critical:
      case ThreatLevel.high:
        newStatus = NetworkStatus.blocked;
        break;
      case ThreatLevel.medium:
        newStatus = NetworkStatus.suspicious;
        break;
      case ThreatLevel.low:
        if (assessment.isKnownLegitimate) {
          newStatus = NetworkStatus.verified;
        } else {
          newStatus = NetworkStatus.unknown;
        }
        break;
    }

    // Create enhanced network model
    return NetworkModel(
      id: network.id,
      name: network.name,
      description: _generateSecurityDescription(network, assessment),
      status: newStatus,
      securityType: network.securityType,
      signalStrength: network.signalStrength,
      macAddress: network.macAddress,
      latitude: network.latitude,
      longitude: network.longitude,
      lastSeen: network.lastSeen,
      isConnected: network.isConnected,
      cityName: network.cityName,
      address: network.address,
      ipAddress: network.ipAddress,
      isUserManaged: network.isUserManaged,
      lastActionDate: network.lastActionDate,
      isSaved: network.isSaved,
    );
  }

  /// Generate security-enhanced description
  String _generateSecurityDescription(NetworkModel network, SecurityAssessment assessment) {
    var description = network.description ?? 'Network detected';
    
    if (assessment.detectedThreats.isNotEmpty) {
      final threatCount = assessment.detectedThreats.length;
      description += ' • $threatCount security ${threatCount == 1 ? 'threat' : 'threats'} detected';
    }
    
    if (assessment.isKnownLegitimate) {
      description += ' • Verified legitimate network';
    }
    
    description += ' • Security Score: ${assessment.securityScore}/100';
    
    return description;
  }

  /// Check for security alerts
  Future<void> _checkForSecurityAlerts() async {
    try {
      final highRiskNetworks = getHighRiskNetworks();
      final evilTwinThreats = getEvilTwinThreats();

      if (highRiskNetworks.isNotEmpty) {
        developer.log('🚨 ${highRiskNetworks.length} high-risk networks detected');
      }

      if (evilTwinThreats.isNotEmpty) {
        developer.log('🎭 ${evilTwinThreats.length} potential Evil Twin attacks detected');
      }

    } catch (e) {
      developer.log('❌ Security alert check failed: $e');
    }
  }

  /// Start post-connection monitoring
  void _startPostConnectionMonitoring(NetworkModel network) {
    try {
      developer.log('🔍 Starting post-connection monitoring for ${network.name}');
      _monitoredNetworks.add(network.id);
      
      // In a full implementation, this would:
      // - Monitor for DNS hijacking
      // - Verify SSL certificates
      // - Analyze traffic patterns
      // - Check for suspicious network behavior
      
    } catch (e) {
      developer.log('❌ Post-connection monitoring setup failed: $e');
    }
  }

  /// Handle network state changes from native layer
  Future<void> _handleNetworkStateChange(dynamic arguments) async {
    try {
      developer.log('📌 Network state change detected');
      // Trigger security reassessment
      await refreshSecurityAnalysis();
    } catch (e) {
      developer.log('❌ Network state change handling failed: $e');
    }
  }

  /// Handle security alerts from native layer
  Future<void> _handleSecurityAlert(dynamic arguments) async {
    try {
      developer.log('🚨 Security alert received from native layer');
      // Process security alert and update assessments
      await refreshSecurityAnalysis();
    } catch (e) {
      developer.log('❌ Security alert handling failed: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    try {
      stopSecurityMonitoring();
      _enhancedNetworkStream.close();
      _securityAssessmentStream.close();
      _networkAssessments.clear();
      _securityAnalyzer.dispose();
    } catch (e) {
      developer.log('❌ EnhancedWiFiService disposal failed: $e');
    }
  }
}