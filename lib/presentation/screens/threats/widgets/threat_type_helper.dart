import 'package:flutter/material.dart';
import '../../../../data/models/alert_model.dart';
import '../../../../core/theme/app_colors.dart';

class ThreatTypeHelper extends StatelessWidget {
  const ThreatTypeHelper({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline,
                color: Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Not sure which type to choose?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildThreatTypeDescription(
            AlertType.suspiciousNetwork,
            'Suspicious Network',
            'A network that appears unusual or potentially harmful but not confirmed as malicious.',
            Icons.warning,
            Colors.orange,
          ),
          const SizedBox(height: 8),
          _buildThreatTypeDescription(
            AlertType.evilTwin,
            'Evil Twin Network',
            'A fake network that mimics a legitimate one to steal user data.',
            Icons.content_copy,
            Colors.red,
          ),
          const SizedBox(height: 8),
          _buildThreatTypeDescription(
            AlertType.networkBlocked,
            'Malicious Network',
            'A confirmed harmful network that should be avoided.',
            Icons.block,
            Colors.red.shade700,
          ),
          const SizedBox(height: 8),
          _buildThreatTypeDescription(
            AlertType.critical,
            'Critical Security Issue',
            'Urgent security threat requiring immediate attention.',
            Icons.error,
            Colors.red.shade800,
          ),
        ],
      ),
    );
  }

  Widget _buildThreatTypeDescription(
    AlertType type,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}