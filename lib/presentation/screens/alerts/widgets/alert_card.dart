import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/alert_model.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onDetails;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  const AlertCard({
    super.key,
    required this.alert,
    this.onDetails,
    this.onAction,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            color: _getHeaderColor(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _getAlertIcon(),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getAlertTypeString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  _formatTimestamp(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          InkWell(
            onTap: onDetails,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!alert.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4, right: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          alert.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alert.message,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  if (alert.networkName != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgGray,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Network Name: ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.gray,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        alert.networkName!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (alert.securityType != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Text(
                                        'Security: ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.gray,
                                        ),
                                      ),
                                      Text(
                                        alert.securityType!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (alert.location != null) ...[
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Location:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gray,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  alert.location!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onDetails,
                        child: Text(
                          'Details',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      if (alert.type == AlertType.critical && onAction != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: onAction,
                          child: const Text(
                            'Block Network',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ] else if (alert.type == AlertType.warning && onAction != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: onAction,
                          child: const Text(
                            'Add to Safe List',
                            style: TextStyle(color: AppColors.warning),
                          ),
                        ),
                      ] else if (onDismiss != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: onDismiss,
                          child: Text(
                            'Dismiss',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getHeaderColor() {
    switch (alert.type) {
      case AlertType.critical:
      case AlertType.evilTwin:
        return AppColors.danger;
      case AlertType.warning:
      case AlertType.suspiciousNetwork:
        return AppColors.warning;
      case AlertType.info:
      case AlertType.networkBlocked:
        return AppColors.primary;
      case AlertType.networkTrusted:
        return AppColors.success;
    }
  }

  IconData _getAlertIcon() {
    switch (alert.type) {
      case AlertType.critical:
      case AlertType.evilTwin:
        return Icons.warning;
      case AlertType.warning:
      case AlertType.suspiciousNetwork:
        return Icons.error_outline;
      case AlertType.info:
      case AlertType.networkBlocked:
        return Icons.info_outline;
      case AlertType.networkTrusted:
        return Icons.shield;
    }
  }

  String _getAlertTypeString() {
    switch (alert.type) {
      case AlertType.critical:
        return 'Critical Alert';
      case AlertType.warning:
        return 'Warning Alert';
      case AlertType.info:
        return 'Information';
      case AlertType.evilTwin:
        return 'Evil Twin Detected';
      case AlertType.suspiciousNetwork:
        return 'Suspicious Network';
      case AlertType.networkBlocked:
        return 'Network Blocked';
      case AlertType.networkTrusted:
        return 'Network Trusted';
    }
  }

  String _formatTimestamp() {
    final now = DateTime.now();
    final difference = now.difference(alert.timestamp);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return 'Today, ${DateFormat('h:mm a').format(alert.timestamp)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(alert.timestamp)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE, h:mm a').format(alert.timestamp);
    } else {
      return DateFormat('MMM d, y').format(alert.timestamp);
    }
  }
}