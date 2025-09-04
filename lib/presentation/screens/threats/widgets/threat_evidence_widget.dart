import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/threat_report_model.dart';
import '../../../../data/models/scan_history_model.dart';
import '../../../../data/models/network_model.dart';
import '../../../../data/models/alert_model.dart';

class ThreatEvidenceWidget extends StatelessWidget {
  final ThreatAlert alert;
  final ScanHistoryEntry scanContext;
  
  const ThreatEvidenceWidget({
    super.key,
    required this.alert,
    required this.scanContext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.fact_check,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Threat Evidence',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Suspicious Network Details
            _buildNetworkCard(
              title: 'Suspicious Network',
              network: alert.suspiciousNetwork,
              isWrapNetwork: true,
            ),
            
            // Legitimate Network Comparison (for Evil Twin)
            if (alert.type == AlertType.evilTwin && alert.legitimateNetwork != null) ...[
              const SizedBox(height: 12),
              _buildNetworkCard(
                title: 'Legitimate Network',
                network: alert.legitimateNetwork,
                isLegitimate: true,
              ),
              const SizedBox(height: 12),
              _buildComparisonIndicators(),
            ],
            
            // Threat Indicators
            if (alert.threatIndicators != null && alert.threatIndicators!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildThreatIndicators(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildNetworkCard({
    required String title,
    required NetworkModel? network,
    bool isLegitimate = false,
    bool isWrapNetwork = false,
  }) {
    if (network == null) return const SizedBox.shrink();
    
    final cardColor = isLegitimate 
        ? Colors.green.shade50
        : isWrapNetwork 
            ? Colors.red.shade50
            : Colors.grey.shade50;
    
    final borderColor = isLegitimate 
        ? Colors.green.shade200
        : isWrapNetwork 
            ? Colors.red.shade200
            : Colors.grey.shade200;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLegitimate ? Icons.verified_user : Icons.warning,
                size: 16,
                color: isLegitimate 
                    ? Colors.green.shade600
                    : isWrapNetwork 
                        ? Colors.red.shade600
                        : Colors.orange.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isLegitimate 
                      ? Colors.green.shade800
                      : isWrapNetwork 
                          ? Colors.red.shade800
                          : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildNetworkDetail('SSID', network.name),
          _buildNetworkDetail('MAC Address', network.macAddress),
          _buildNetworkDetail('Security', network.securityTypeString),
          _buildNetworkDetail('Signal', '${network.signalStrength}%'),
          if (network.status != NetworkStatus.unknown)
            _buildNetworkDetail('Status', network.status.name.toUpperCase()),
        ],
      ),
    );
  }
  
  Widget _buildNetworkDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildComparisonIndicators() {
    if (alert.suspiciousNetwork == null || alert.legitimateNetwork == null) {
      return const SizedBox.shrink();
    }
    
    final suspicious = alert.suspiciousNetwork!;
    final legitimate = alert.legitimateNetwork!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.compare_arrows,
                size: 16,
                color: Colors.orange.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'Evil Twin Indicators',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // SSID Comparison
          if (suspicious.name == legitimate.name)
            _buildIndicator(
              'Identical SSID',
              'Both networks use the same name: "${suspicious.name}"',
              Icons.content_copy,
              Colors.red.shade600,
            ),
          
          // MAC Address Comparison
          if (suspicious.macAddress != legitimate.macAddress)
            _buildIndicator(
              'Different MAC Addresses',
              'Suspicious: ${suspicious.macAddress}\nLegitimate: ${legitimate.macAddress}',
              Icons.fingerprint,
              Colors.orange.shade600,
            ),
          
          // Signal Strength Comparison
          if (suspicious.signalStrength > legitimate.signalStrength)
            _buildIndicator(
              'Stronger Signal',
              'Suspicious network has ${suspicious.signalStrength}% vs ${legitimate.signalStrength}%',
              Icons.signal_wifi_4_bar,
              Colors.red.shade600,
            ),
        ],
      ),
    );
  }
  
  Widget _buildThreatIndicators() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.bug_report,
              color: Colors.red.shade600,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Threat Indicators',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...alert.threatIndicators!.map((indicator) => _buildIndicatorChip(indicator)),
      ],
    );
  }
  
  Widget _buildIndicator(String title, String description, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildIndicatorChip(String indicator) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          _formatIndicator(indicator),
          style: TextStyle(
            fontSize: 11,
            color: Colors.red.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
  
  String _formatIndicator(String indicator) {
    // Convert snake_case to human readable
    return indicator
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ');
  }
}