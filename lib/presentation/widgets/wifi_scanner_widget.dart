import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../../data/models/network_model.dart';
import '../../data/models/security_assessment.dart';
import '../../data/services/enhanced_wifi_service.dart';

/// Enhanced Wi-Fi scanner widget with real-time security analysis and threat visualization
class WiFiScannerWidget extends StatefulWidget {
  final Function(NetworkModel)? onNetworkTap;
  final Function(NetworkModel)? onConnectTap;
  final Function(SecurityAssessment)? onSecurityDetailsTap;
  final bool showSecurityIndicators;
  final bool enableContinuousScanning;

  const WiFiScannerWidget({
    super.key,
    this.onNetworkTap,
    this.onConnectTap,
    this.onSecurityDetailsTap,
    this.showSecurityIndicators = true,
    this.enableContinuousScanning = true,
  });

  @override
  State<WiFiScannerWidget> createState() => _WiFiScannerWidgetState();
}

class _WiFiScannerWidgetState extends State<WiFiScannerWidget> 
    with TickerProviderStateMixin {
  final EnhancedWiFiService _wifiService = EnhancedWiFiService();
  
  late AnimationController _scanAnimationController;
  late AnimationController _listAnimationController;
  
  List<NetworkModel> _networks = [];
  final Map<String, SecurityAssessment> _securityAssessments = {};
  bool _isScanning = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _initializeService();
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      setState(() {
        _isScanning = true;
      });

      final initialized = await _wifiService.initialize();
      
      if (!initialized) {
        setState(() {
          _errorMessage = 'Failed to initialize Wi-Fi service';
          _isScanning = false;
        });
        return;
      }

      // Service initialized successfully

      // Listen to network updates
      if (widget.enableContinuousScanning) {
        _wifiService.enhancedNetworkStream.listen((networks) {
          if (mounted) {
            setState(() {
              _networks = networks;
              _isScanning = false;
            });
            _listAnimationController.forward();
          }
        });

        // Listen to security assessments
        _wifiService.securityAssessmentStream.listen((assessments) {
          if (mounted) {
            setState(() {
              _securityAssessments.clear();
              for (final assessment in assessments) {
                _securityAssessments[assessment.networkId] = assessment;
              }
            });
          }
        });

        // Start continuous monitoring
        _wifiService.startSecurityMonitoring();
      } else {
        // Perform single scan
        await _performSingleScan();
      }

    } catch (e) {
      developer.log('WiFi scanner initialization failed: $e');
      setState(() {
        _errorMessage = 'Initialization failed: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _performSingleScan() async {
    try {
      setState(() {
        _isScanning = true;
        _errorMessage = null;
      });

      _scanAnimationController.repeat();

      final networks = await _wifiService.scanNetworksWithSecurityAnalysis();
      final assessments = _wifiService.getCurrentSecurityAssessments();

      if (mounted) {
        setState(() {
          _networks = networks;
          _securityAssessments.clear();
          for (final assessment in assessments) {
            _securityAssessments[assessment.networkId] = assessment;
          }
          _isScanning = false;
        });
        
        _listAnimationController.forward();
      }

    } catch (e) {
      developer.log('Wi-Fi scan failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Scan failed: $e';
          _isScanning = false;
        });
      }
    } finally {
      _scanAnimationController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (_errorMessage != null) _buildErrorMessage(),
          if (_isScanning) _buildScanningIndicator(),
          if (_networks.isNotEmpty) _buildNetworkList(),
          if (_networks.isEmpty && !_isScanning && _errorMessage == null)
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _scanAnimationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _scanAnimationController.value * 2 * 3.14159,
                child: const Icon(
                  Icons.wifi_find,
                  color: Colors.white,
                  size: 24,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wi-Fi Networks',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.showSecurityIndicators)
                  const Text(
                    'Security analysis enabled',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${_networks.length} found',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isScanning ? null : _performSingleScan,
            icon: Icon(
              Icons.refresh,
              color: _isScanning ? Colors.white54 : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.red.shade50,
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scanning for networks with security analysis...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkList() {
    return AnimatedBuilder(
      animation: _listAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _listAnimationController.value)),
          child: Opacity(
            opacity: _listAnimationController.value,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _networks.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final network = _networks[index];
                final assessment = _securityAssessments[network.id];
                return _buildNetworkItem(network, assessment);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildNetworkItem(NetworkModel network, SecurityAssessment? assessment) {
    return InkWell(
      onTap: () => widget.onNetworkTap?.call(network),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Signal strength indicator
            _buildSignalStrengthIndicator(network.signalStrength),
            const SizedBox(width: 12),
            
            // Network info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          network.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.showSecurityIndicators && assessment != null)
                        _buildSecurityBadge(assessment),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildSecurityTypeChip(network.securityType),
                      const SizedBox(width: 8),
                      if (assessment != null)
                        _buildThreatIndicator(assessment),
                    ],
                  ),
                  if (assessment != null && assessment.detectedThreats.isNotEmpty)
                    _buildThreatSummary(assessment),
                ],
              ),
            ),
            
            // Action buttons
            Column(
              children: [
                if (widget.onConnectTap != null)
                  IconButton(
                    onPressed: assessment?.shouldAvoidConnection == true 
                        ? null 
                        : () => widget.onConnectTap?.call(network),
                    icon: Icon(
                      Icons.wifi_protected_setup,
                      color: assessment?.shouldAvoidConnection == true 
                          ? Colors.grey 
                          : Colors.blue,
                    ),
                  ),
                if (widget.showSecurityIndicators && 
                    assessment != null && 
                    widget.onSecurityDetailsTap != null)
                  IconButton(
                    onPressed: () => widget.onSecurityDetailsTap?.call(assessment),
                    icon: Icon(
                      Icons.security,
                      color: _getSecurityIconColor(assessment.threatLevel),
                      size: 20,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalStrengthIndicator(int strength) {
    final bars = (strength / 25).ceil().clamp(1, 4);
    final color = strength > 70 ? Colors.green : 
                  strength > 40 ? Colors.orange : Colors.red;
    
    return SizedBox(
      width: 24,
      height: 20,
      child: Row(
        children: List.generate(4, (index) {
          return Container(
            width: 4,
            height: 4 + (index * 4).toDouble(),
            margin: const EdgeInsets.only(right: 1),
            decoration: BoxDecoration(
              color: index < bars ? color : Colors.grey.shade300,
              borderRadius: const BorderRadius.all(Radius.circular(1)),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSecurityTypeChip(SecurityType type) {
    final colors = {
      SecurityType.open: Colors.red,
      SecurityType.wep: Colors.orange,
      SecurityType.wpa2: Colors.blue,
      SecurityType.wpa3: Colors.green,
    };

    final labels = {
      SecurityType.open: 'Open',
      SecurityType.wep: 'WEP',
      SecurityType.wpa2: 'WPA2',
      SecurityType.wpa3: 'WPA3',
    };

    final color = colors[type] ?? Colors.grey;
    final label = labels[type] ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSecurityBadge(SecurityAssessment assessment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getSecurityBadgeColor(assessment.threatLevel).withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        border: Border.all(
          color: _getSecurityBadgeColor(assessment.threatLevel).withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Text(
        assessment.securityGrade,
        style: TextStyle(
          color: _getSecurityBadgeColor(assessment.threatLevel),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThreatIndicator(SecurityAssessment assessment) {
    if (assessment.detectedThreats.isEmpty) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 12),
          SizedBox(width: 4),
          Text(
            'Safe',
            style: TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final threatCount = assessment.detectedThreats.length;
    final color = _getThreatLevelColor(assessment.threatLevel);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_getThreatIcon(assessment.threatLevel), color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          '$threatCount ${threatCount == 1 ? 'threat' : 'threats'}',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildThreatSummary(SecurityAssessment assessment) {
    final mostCritical = assessment.mostCriticalThreat;
    if (mostCritical == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getThreatSeverityColor(mostCritical.severity).withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Row(
        children: [
          Text(
            mostCritical.type.icon,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              mostCritical.type.displayName,
              style: TextStyle(
                color: _getThreatSeverityColor(mostCritical.severity),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.wifi_off,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No networks found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap refresh to scan again',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for colors and icons

  Color _getThreatLevelColor(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.low:
        return Colors.green;
      case ThreatLevel.medium:
        return Colors.orange;
      case ThreatLevel.high:
        return Colors.red;
      case ThreatLevel.critical:
        return Colors.purple;
    }
  }

  Color _getThreatSeverityColor(ThreatSeverity severity) {
    switch (severity) {
      case ThreatSeverity.low:
        return Colors.blue;
      case ThreatSeverity.medium:
        return Colors.orange;
      case ThreatSeverity.high:
        return Colors.red;
      case ThreatSeverity.critical:
        return Colors.purple;
    }
  }

  Color _getSecurityBadgeColor(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.low:
        return Colors.green;
      case ThreatLevel.medium:
        return Colors.orange;
      case ThreatLevel.high:
        return Colors.red;
      case ThreatLevel.critical:
        return Colors.purple;
    }
  }

  Color _getSecurityIconColor(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.low:
        return Colors.green;
      case ThreatLevel.medium:
        return Colors.orange;
      case ThreatLevel.high:
        return Colors.red;
      case ThreatLevel.critical:
        return Colors.purple;
    }
  }

  IconData _getThreatIcon(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.low:
        return Icons.check_circle;
      case ThreatLevel.medium:
        return Icons.warning;
      case ThreatLevel.high:
        return Icons.error;
      case ThreatLevel.critical:
        return Icons.dangerous;
    }
  }
}