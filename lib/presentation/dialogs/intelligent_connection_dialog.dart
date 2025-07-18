import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../../data/models/network_model.dart';

/// Intelligent connection dialog that shows security analysis and provides enhanced connection options
class IntelligentConnectionDialog {
  static Future<ConnectionDialogResult?> show(
    BuildContext context, 
    NetworkModel network,
    Map<String, dynamic> securityAnalysis,
  ) async {
    if (!context.mounted) return null;

    try {
      final result = await showDialog<ConnectionDialogResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _IntelligentConnectionDialogWidget(
          network: network,
          securityAnalysis: securityAnalysis,
        ),
      );
      return result;
    } catch (e) {
      developer.log('Error showing intelligent connection dialog: $e');
      return null;
    }
  }
}

class _IntelligentConnectionDialogWidget extends StatefulWidget {
  final NetworkModel network;
  final Map<String, dynamic> securityAnalysis;

  const _IntelligentConnectionDialogWidget({
    required this.network,
    required this.securityAnalysis,
  });

  @override
  State<_IntelligentConnectionDialogWidget> createState() => _IntelligentConnectionDialogWidgetState();
}

class _IntelligentConnectionDialogWidgetState extends State<_IntelligentConnectionDialogWidget> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final analysis = widget.securityAnalysis;
    final securityScore = analysis['securityScore'] as int? ?? 50;
    final securityRecommendation = analysis['securityRecommendation'] as String? ?? 'Proceed with caution';
    final signalQuality = analysis['signalQuality'] as String? ?? 'Unknown';
    final encryptionType = analysis['encryptionType'] as String? ?? 'Unknown';
    final evilTwinSuspicion = analysis['evilTwinSuspicion'] as bool? ?? false;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.security,
              color: Colors.blue[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'DisConX Enhanced Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Network Info Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi, color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.network.name,
                          style: const TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip('Security', encryptionType, _getSecurityColor(encryptionType)),
                      const SizedBox(width: 8),
                      _buildInfoChip('Signal', signalQuality, _getSignalColor(signalQuality)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Security Analysis
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getRecommendationColor(securityScore).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getRecommendationColor(securityScore).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getRecommendationIcon(securityScore),
                        color: _getRecommendationColor(securityScore),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'DisConX Security Analysis',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(securityRecommendation),
                  
                  if (evilTwinSuspicion) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange[700], size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Multiple networks with same name detected',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Security Score Bar
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Security Score: ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: securityScore / 100.0,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getRecommendationColor(securityScore),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$securityScore/100',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Advanced Details (Collapsible)
            if (_showAdvanced) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Technical Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('BSSID', analysis['bssid'] ?? 'Unknown'),
                    _buildDetailRow('Frequency', '${analysis['frequency'] ?? 'Unknown'} MHz'),
                    _buildDetailRow('Signal Strength', '${analysis['signalStrength'] ?? 'Unknown'} dBm'),
                    if (analysis['similarNetworkCount'] != null)
                      _buildDetailRow('Similar Networks', '${analysis['similarNetworkCount']}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Advanced Toggle
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAdvanced = !_showAdvanced;
                });
              },
              icon: Icon(
                _showAdvanced ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
              label: Text(
                _showAdvanced ? 'Hide Details' : 'Show Details',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(ConnectionDialogResult.cancel);
          },
          child: const Text('Cancel'),
        ),
        if (securityScore >= 60) ...[
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(ConnectionDialogResult.connectSecurely);
            },
            icon: const Icon(Icons.security, size: 16),
            label: const Text('Connect Securely'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(ConnectionDialogResult.guidedSettings);
            },
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Guided Setup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSecurityColor(String security) {
    switch (security.toLowerCase()) {
      case 'wpa3':
        return Colors.green;
      case 'wpa2':
        return Colors.blue;
      case 'wpa':
        return Colors.orange;
      case 'wep':
        return Colors.red;
      case 'open':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getSignalColor(String signal) {
    switch (signal.toLowerCase()) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.blue;
      case 'fair':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getRecommendationColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getRecommendationIcon(int score) {
    if (score >= 80) return Icons.check_circle;
    if (score >= 60) return Icons.warning;
    return Icons.error;
  }
}

enum ConnectionDialogResult {
  cancel,
  connectSecurely,
  guidedSettings,
}