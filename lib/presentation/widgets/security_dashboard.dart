import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../../data/models/security_assessment.dart';
import '../../data/services/enhanced_wifi_service.dart';

/// Security dashboard widget that displays real-time threat analysis and network security status
class SecurityDashboard extends StatefulWidget {
  final bool showDetailedView;
  final VoidCallback? onRefresh;
  final Function(SecurityAssessment)? onThreatTapped;

  const SecurityDashboard({
    super.key,
    this.showDetailedView = true,
    this.onRefresh,
    this.onThreatTapped,
  });

  @override
  State<SecurityDashboard> createState() => _SecurityDashboardState();
}

class _SecurityDashboardState extends State<SecurityDashboard> with TickerProviderStateMixin {
  final EnhancedWiFiService _wifiService = EnhancedWiFiService();
  late AnimationController _scanAnimationController;
  late AnimationController _alertAnimationController;
  
  List<SecurityAssessment> _assessments = [];
  bool _isLoading = false;
  DateTime _lastUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _alertAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Listen to security assessments
    _wifiService.securityAssessmentStream.listen((assessments) {
      if (mounted) {
        setState(() {
          _assessments = assessments;
          _lastUpdate = DateTime.now();
        });
        
        // Animate alerts for high-risk networks
        final hasHighRisk = assessments.any((a) => 
            a.threatLevel == ThreatLevel.high || a.threatLevel == ThreatLevel.critical);
        if (hasHighRisk) {
          _alertAnimationController.repeat();
        } else {
          _alertAnimationController.stop();
        }
      }
    });

    // Load initial data
    _loadSecurityData();
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _alertAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadSecurityData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final assessments = _wifiService.getCurrentSecurityAssessments();
      if (mounted) {
        setState(() {
          _assessments = assessments;
          _lastUpdate = DateTime.now();
        });
      }
    } catch (e) {
      developer.log('Failed to load security data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshSecurityData() async {
    _scanAnimationController.repeat();
    
    try {
      await _wifiService.refreshSecurityAnalysis();
      widget.onRefresh?.call();
    } catch (e) {
      developer.log('Failed to refresh security data: $e');
    } finally {
      _scanAnimationController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (widget.showDetailedView) ...[
            _buildSecurityOverview(),
            const Divider(height: 1),
            _buildThreatList(),
            const Divider(height: 1),
            _buildNetworkSummary(),
          ] else ...[
            _buildCompactView(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final highRiskCount = _assessments.where((a) => 
        a.threatLevel == ThreatLevel.high || a.threatLevel == ThreatLevel.critical).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade500,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _scanAnimationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _scanAnimationController.value * 2 * 3.14159,
                child: Icon(
                  Icons.security,
                  color: Colors.white,
                  size: 28,
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
                  'DisConX Security Monitor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Last scan: ${_formatLastUpdate()}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (highRiskCount > 0)
            AnimatedBuilder(
              animation: _alertAnimationController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2 + 0.3 * _alertAnimationController.value),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$highRiskCount',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isLoading ? null : _refreshSecurityData,
            icon: Icon(
              Icons.refresh,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityOverview() {
    final threatCounts = _calculateThreatCounts();
    final networkCount = _assessments.length;
    final avgSecurityScore = _calculateAverageSecurityScore();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Security Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Networks Scanned',
                  '$networkCount',
                  Icons.wifi,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Avg Security Score',
                  '${avgSecurityScore.toInt()}/100',
                  Icons.security,
                  _getScoreColor(avgSecurityScore),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildThreatLevelIndicators(threatCounts),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildThreatLevelIndicators(Map<ThreatLevel, int> counts) {
    return Row(
      children: ThreatLevel.values.map((level) {
        final count = counts[level] ?? 0;
        final color = _getThreatLevelColor(level);
        
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  level.displayName.split(' ').first,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildThreatList() {
    final highPriorityThreats = _assessments
        .expand((a) => a.detectedThreats)
        .where((t) => t.isActionable)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    if (highPriorityThreats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            const Text('No active threats detected'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Active Threats',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ...highPriorityThreats.take(3).map((threat) => _buildThreatCard(threat)),
        if (highPriorityThreats.length > 3)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '+ ${highPriorityThreats.length - 3} more threats',
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildThreatCard(SecurityThreat threat) {
    final assessment = _assessments.firstWhere(
      (a) => a.detectedThreats.contains(threat),
      orElse: () => _assessments.first,
    );

    return InkWell(
      onTap: () => widget.onThreatTapped?.call(assessment),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getThreatSeverityColor(threat.severity).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getThreatSeverityColor(threat.severity).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Text(
              threat.type.icon,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    threat.type.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Network: ${threat.affectedSSID}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (threat.details.isNotEmpty)
                    Text(
                      threat.details.first,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getThreatSeverityColor(threat.severity),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(threat.confidenceScore * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkSummary() {
    final safeNetworks = _assessments.where((a) => a.isSafeToConnect).length;
    final riskyNetworks = _assessments.where((a) => a.shouldAvoidConnection).length;
    final unknownNetworks = _assessments.length - safeNetworks - riskyNetworks;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Network Safety Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryItem('Safe', safeNetworks, Colors.green),
              _buildSummaryItem('Risky', riskyNetworks, Colors.red),
              _buildSummaryItem('Unknown', unknownNetworks, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactView() {
    final threatCount = _assessments.fold<int>(0, (sum, a) => sum + a.detectedThreats.length);
    final avgScore = _calculateAverageSecurityScore();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_assessments.length} networks scanned',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  '$threatCount threats • Score: ${avgScore.toInt()}/100',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getScoreColor(avgScore).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getScoreIcon(avgScore),
              color: _getScoreColor(avgScore),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods

  Map<ThreatLevel, int> _calculateThreatCounts() {
    final counts = <ThreatLevel, int>{};
    for (final level in ThreatLevel.values) {
      counts[level] = _assessments.where((a) => a.threatLevel == level).length;
    }
    return counts;
  }

  double _calculateAverageSecurityScore() {
    if (_assessments.isEmpty) return 100.0;
    
    final totalScore = _assessments.fold<int>(0, (sum, a) => sum + a.securityScore);
    return totalScore / _assessments.length;
  }

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

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getScoreIcon(double score) {
    if (score >= 80) return Icons.security;
    if (score >= 60) return Icons.warning;
    return Icons.error;
  }

  String _formatLastUpdate() {
    final diff = DateTime.now().difference(_lastUpdate);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}