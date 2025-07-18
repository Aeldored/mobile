import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class QuickActionsWidget extends StatelessWidget {
  final VoidCallback onViewAll;
  final VoidCallback onViewAlerts;
  final VoidCallback onViewHistory;
  final int networksCount;
  final int alertsCount;

  const QuickActionsWidget({
    super.key,
    required this.onViewAll,
    required this.onViewAlerts,
    required this.onViewHistory,
    required this.networksCount,
    required this.alertsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.list,
                  label: 'View All',
                  subtitle: '$networksCount networks',
                  color: AppColors.primary,
                  onTap: onViewAll,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.warning,
                  label: 'Alerts',
                  subtitle: '$alertsCount threats',
                  color: alertsCount > 0 ? Colors.red : Colors.grey,
                  onTap: onViewAlerts,
                  enabled: alertsCount > 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.history,
                  label: 'History',
                  subtitle: 'Past scans',
                  color: Colors.blue,
                  onTap: onViewHistory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? color.withValues(alpha: 0.3) : Colors.grey[300]!,
          ),
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: enabled ? color : Colors.grey[400],
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? color : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: enabled ? Colors.grey[600] : Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}