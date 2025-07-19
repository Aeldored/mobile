import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum ScanStatus { verified, suspicious, unknown }

class ScanResult {
  final String networkName;
  final ScanStatus status;
  final String description;
  final String timeAgo;

  ScanResult({
    required this.networkName,
    required this.status,
    required this.description,
    required this.timeAgo,
  });
}

class ScanResultItem extends StatelessWidget {
  final ScanResult result;

  const ScanResultItem({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildStatusIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.networkName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              result.timeAgo,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    Color backgroundColor;
    Color iconColor;
    IconData icon;

    switch (result.status) {
      case ScanStatus.verified:
        backgroundColor = AppColors.success.withValues(alpha: 0.1);
        iconColor = AppColors.success;
        icon = Icons.check;
        break;
      case ScanStatus.suspicious:
        backgroundColor = AppColors.danger.withValues(alpha: 0.1);
        iconColor = AppColors.danger;
        icon = Icons.close;
        break;
      case ScanStatus.unknown:
        backgroundColor = AppColors.warning.withValues(alpha: 0.1);
        iconColor = AppColors.warning;
        icon = Icons.question_mark;
        break;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: 18,
      ),
    );
  }
}