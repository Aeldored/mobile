import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/network_model.dart';

class StatusBadge extends StatelessWidget {
  final NetworkStatus status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String text;
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case NetworkStatus.verified:
        icon = Icons.check_circle;
        text = 'Verified';
        backgroundColor = AppColors.verifiedBg;
        textColor = AppColors.verifiedText;
        break;
      case NetworkStatus.trusted:
        icon = Icons.shield;
        text = 'Trusted';
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green.shade700;
        break;
      case NetworkStatus.suspicious:
        icon = Icons.error;
        text = 'Suspicious';
        backgroundColor = AppColors.suspiciousBg;
        textColor = AppColors.suspiciousText;
        break;
      case NetworkStatus.blocked:
        icon = Icons.block;
        text = 'Blocked';
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red.shade700;
        break;
      case NetworkStatus.flagged:
        icon = Icons.flag;
        text = 'Flagged';
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange.shade700;
        break;
      case NetworkStatus.unknown:
        icon = Icons.help;
        text = 'Unknown';
        backgroundColor = AppColors.unknownBg;
        textColor = AppColors.unknownText;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}