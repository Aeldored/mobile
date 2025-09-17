import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../models/network_model.dart';
import '../models/security_assessment.dart';
import 'native_wifi_controller.dart';

/// Service for validating real network connectivity and persistence
class ConnectionValidationService {
  static final ConnectionValidationService _instance = ConnectionValidationService._internal();
  factory ConnectionValidationService() => _instance;
  ConnectionValidationService._internal();

  final NativeWiFiController _nativeController = NativeWiFiController();
  final Connectivity _connectivity = Connectivity();
  final Dio _dio = Dio();

  /// Comprehensive connection validation
  Future<ConnectionValidationResult> validateConnection({
    required String networkName,
    bool checkInternet = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      developer.log('🔍 Starting comprehensive validation for: $networkName');
      
      final validationSteps = <ValidationStep>[];
      
      // Step 1: OS-Level Connection Check
      final osConnected = await _validateOSConnection(networkName);
      validationSteps.add(ValidationStep(
        name: 'OS Connection',
        passed: osConnected,
        description: osConnected 
          ? 'Device is connected to $networkName at OS level'
          : 'Device is NOT connected to $networkName at OS level',
      ));
      
      if (!osConnected) {
        return ConnectionValidationResult(
          isValid: false,
          networkName: networkName,
          validationSteps: validationSteps,
          failureReason: 'OS-level connection not established',
        );
      }
      
      // Step 2: Network Interface Check
      final interfaceActive = await _validateNetworkInterface();
      validationSteps.add(ValidationStep(
        name: 'Network Interface',
        passed: interfaceActive,
        description: interfaceActive 
          ? 'Wi-Fi interface is active and functional'
          : 'Wi-Fi interface is not active',
      ));
      
      // Step 3: IP Address Assignment
      final hasIpAddress = await _validateIpAssignment();
      validationSteps.add(ValidationStep(
        name: 'IP Assignment',
        passed: hasIpAddress,
        description: hasIpAddress 
          ? 'Valid IP address assigned by network'
          : 'No valid IP address assigned',
      ));
      
      // Step 4: Internet Connectivity (if requested)
      bool internetAccess = true;
      if (checkInternet) {
        internetAccess = await _validateInternetAccess(timeout);
        validationSteps.add(ValidationStep(
          name: 'Internet Access',
          passed: internetAccess,
          description: internetAccess 
            ? 'Internet connectivity verified'
            : 'No internet access through this connection',
        ));
      }
      
      // Step 5: Connection Persistence Check
      final isPersistent = await _validateConnectionPersistence(networkName);
      validationSteps.add(ValidationStep(
        name: 'Connection Persistence',
        passed: isPersistent,
        description: isPersistent 
          ? 'Connection persists across network checks'
          : 'Connection appears to be unstable',
      ));
      
      final allPassed = validationSteps.every((step) => step.passed);
      
      developer.log(allPassed 
        ? '✅ All validation steps passed for $networkName'
        : '❌ Some validation steps failed for $networkName');
      
      return ConnectionValidationResult(
        isValid: allPassed,
        networkName: networkName,
        validationSteps: validationSteps,
        failureReason: allPassed ? null : _getFailureReason(validationSteps),
      );
      
    } catch (e) {
      developer.log('❌ Connection validation error: $e');
      return ConnectionValidationResult(
        isValid: false,
        networkName: networkName,
        validationSteps: [],
        failureReason: 'Validation process failed: ${e.toString()}',
      );
    }
  }

  /// Validate OS-level connection
  Future<bool> _validateOSConnection(String networkName) async {
    try {
      // Use native controller for system-level validation
      final isConnected = await _nativeController.isActuallyConnectedTo(networkName);
      final connectionInfo = await _nativeController.getSystemCurrentConnection();
      final currentSsid = connectionInfo?['ssid'];
      
      // Connection is valid if native controller confirms
      final osConnected = isConnected && currentSsid == networkName;
      
      developer.log('✅ OS Connection Check: $osConnected');
      developer.log('   - Native: connected=$isConnected, SSID=$currentSsid');
      
      return osConnected;
    } catch (e) {
      developer.log('OS connection validation failed: $e');
      return false;
    }
  }

  /// Validate network interface is active
  Future<bool> _validateNetworkInterface() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final wifiActive = connectivityResults.contains(ConnectivityResult.wifi);
      
      developer.log('Network Interface Check: $wifiActive');
      return wifiActive;
    } catch (e) {
      developer.log('Network interface validation failed: $e');
      return false;
    }
  }

  /// Validate IP address assignment
  Future<bool> _validateIpAssignment() async {
    try {
      final connectionInfo = await _nativeController.getSystemCurrentConnection();
      final ipAddress = connectionInfo?['ipAddress'];
      
      final hasValidIp = ipAddress != null && 
                        ipAddress != '0.0.0.0' && 
                        ipAddress.isNotEmpty;
      
      developer.log('IP Assignment Check: $hasValidIp (IP: $ipAddress)');
      return hasValidIp;
    } catch (e) {
      developer.log('IP assignment validation failed: $e');
      return false;
    }
  }

  /// Validate internet access
  Future<bool> _validateInternetAccess(Duration timeout) async {
    try {
      // Test multiple endpoints for reliability
      final testUrls = [
        'https://www.google.com',
        'https://www.cloudflare.com',
        'https://httpbin.org/status/200',
      ];
      
      _dio.options.connectTimeout = timeout;
      _dio.options.receiveTimeout = timeout;
      
      for (final url in testUrls) {
        try {
          final response = await _dio.head(url);
          if (response.statusCode == 200) {
            developer.log('Internet Access Check: true (via $url)');
            return true;
          }
        } catch (e) {
          developer.log('Failed to reach $url: $e');
        }
      }
      
      developer.log('Internet Access Check: false (all endpoints failed)');
      return false;
    } catch (e) {
      developer.log('Internet access validation failed: $e');
      return false;
    }
  }

  /// Validate connection persistence
  Future<bool> _validateConnectionPersistence(String networkName) async {
    try {
      // Check connection stability over multiple readings
      final checks = <bool>[];
      
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(seconds: 1));
        final isConnected = await _nativeController.isActuallyConnectedTo(networkName);
        checks.add(isConnected);
      }
      
      final persistenceRate = checks.where((check) => check).length / checks.length;
      final isPersistent = persistenceRate >= 0.8; // 80% success rate
      
      developer.log('Connection Persistence Check: $isPersistent (success rate: ${(persistenceRate * 100).toInt()}%)');
      return isPersistent;
    } catch (e) {
      developer.log('Connection persistence validation failed: $e');
      return false;
    }
  }

  /// Get failure reason from validation steps
  String _getFailureReason(List<ValidationStep> steps) {
    final failedSteps = steps.where((step) => !step.passed).toList();
    if (failedSteps.isEmpty) return 'Unknown validation failure';
    
    return 'Failed steps: ${failedSteps.map((s) => s.name).join(', ')}';
  }

  /// Test network connection before attempting to connect
  Future<NetworkReachabilityResult> testNetworkReachability(NetworkModel network) async {
    try {
      developer.log('🔍 Testing reachability for: ${network.name}');
      
      // This would typically involve:
      // 1. Scanning for the specific network
      // 2. Checking signal strength
      // 3. Verifying the network is discoverable
      
      // For now, simulate based on signal strength
      final isReachable = network.signalStrength > 30; // Minimum signal threshold
      final estimatedQuality = _calculateConnectionQuality(network);
      
      return NetworkReachabilityResult(
        isReachable: isReachable,
        networkName: network.name,
        signalStrength: network.signalStrength,
        estimatedQuality: estimatedQuality,
        recommendations: _generateRecommendations(network, estimatedQuality),
      );
    } catch (e) {
      developer.log('Network reachability test failed: $e');
      return NetworkReachabilityResult(
        isReachable: false,
        networkName: network.name,
        signalStrength: 0,
        estimatedQuality: ConnectionQuality.poor,
        recommendations: ['Network is not accessible'],
      );
    }
  }

  /// Calculate expected connection quality
  ConnectionQuality _calculateConnectionQuality(NetworkModel network) {
    final signal = network.signalStrength;
    
    if (signal >= 80) return ConnectionQuality.excellent;
    if (signal >= 60) return ConnectionQuality.good;
    if (signal >= 40) return ConnectionQuality.fair;
    return ConnectionQuality.poor;
  }

  /// Generate connection recommendations
  List<String> _generateRecommendations(NetworkModel network, ConnectionQuality quality) {
    final recommendations = <String>[];
    
    if (quality == ConnectionQuality.poor) {
      recommendations.add('Move closer to the router for better signal');
      recommendations.add('Check if there are obstacles blocking the signal');
    }
    
    if (network.status == NetworkStatus.suspicious) {
      recommendations.add('⚠️ This network has been flagged as suspicious');
      recommendations.add('Consider using a different network');
    }
    
    if (network.securityType == SecurityType.open) {
      recommendations.add('⚠️ This is an open network - your data may not be secure');
      recommendations.add('Avoid accessing sensitive information');
    }
    
    return recommendations;
  }
}

/// Validation result model
class ConnectionValidationResult {
  final bool isValid;
  final String networkName;
  final List<ValidationStep> validationSteps;
  final String? failureReason;

  ConnectionValidationResult({
    required this.isValid,
    required this.networkName,
    required this.validationSteps,
    this.failureReason,
  });

  @override
  String toString() => 'ConnectionValidationResult(valid: $isValid, network: $networkName, steps: ${validationSteps.length})';
}

/// Individual validation step
class ValidationStep {
  final String name;
  final bool passed;
  final String description;

  ValidationStep({
    required this.name,
    required this.passed,
    required this.description,
  });

  @override
  String toString() => 'ValidationStep($name: ${passed ? "✅" : "❌"})';
}

/// Network reachability result
class NetworkReachabilityResult {
  final bool isReachable;
  final String networkName;
  final int signalStrength;
  final ConnectionQuality estimatedQuality;
  final List<String> recommendations;

  NetworkReachabilityResult({
    required this.isReachable,
    required this.networkName,
    required this.signalStrength,
    required this.estimatedQuality,
    required this.recommendations,
  });
}

/// Connection quality levels
enum ConnectionQuality {
  excellent,
  good,
  fair,
  poor,
}