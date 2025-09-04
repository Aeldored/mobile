import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/network_model.dart';
import '../../../../data/models/security_assessment.dart';
import '../../../../data/services/wifi_connection_manager.dart';
import '../../../widgets/status_badge.dart';
import '../../../widgets/connection_status_widget.dart';

class NetworkCard extends StatelessWidget {
  final NetworkModel network;
  final VoidCallback? onConnect;
  final VoidCallback? onReview;
  final Function(AccessPointAction)? onAccessPointAction;
  final WiFiConnectionManager? connectionManager;
  final SecurityAssessment? securityAssessment;
  final bool showSecurityInfo;

  const NetworkCard({
    super.key,
    required this.network,
    this.onConnect,
    this.onReview,
    this.onAccessPointAction,
    this.connectionManager,
    this.securityAssessment,
    this.showSecurityInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showNetworkDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (network.isSaved) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.bookmark,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ],
                          ],
                        ),
                        if (network.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            network.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status: network.status),
                      if (showSecurityInfo && securityAssessment != null) ...[
                        const SizedBox(height: 4),
                        _buildSecurityBadge(securityAssessment!),
                      ],
                      if (connectionManager != null) ...[
                        const SizedBox(height: 4),
                        ConnectionStatusWidget(
                          networkId: network.id,
                          connectionManager: connectionManager!,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              
              // Location info
              if (network.displayLocation != 'Unknown location') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        network.displayLocation,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Alert if needed
              if (network.status == NetworkStatus.suspicious) ...[
                const SizedBox(height: 12),
                _buildAlert(
                  icon: Icons.shield,
                  message: 'Potential evil twin attack detected! Avoid connecting to this network.',
                  type: AlertType.danger,
                ),
              ] else if (network.status == NetworkStatus.unknown) ...[
                const SizedBox(height: 12),
                _buildAlert(
                  icon: Icons.warning_amber_rounded,
                  message: 'This network is not on DICT\'s verified list. Use with caution.',
                  type: AlertType.warning,
                ),
              ] else if (network.status == NetworkStatus.blocked) ...[
                const SizedBox(height: 12),
                _buildAlert(
                  icon: Icons.block,
                  message: 'This network has been blocked by you.',
                  type: AlertType.danger,
                ),
              ] else if (network.status == NetworkStatus.flagged) ...[
                const SizedBox(height: 12),
                _buildAlert(
                  icon: Icons.flag,
                  message: 'You have flagged this network as suspicious.',
                  type: AlertType.warning,
                ),
              ],
              
              // Security assessment alerts
              if (showSecurityInfo && securityAssessment != null) ...[
                ..._buildSecurityAlerts(securityAssessment!),
              ],
              
              const SizedBox(height: 12),
              
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Network info
                  Row(
                    children: [
                      Icon(
                        network.securityType == SecurityType.open
                            ? Icons.lock_open
                            : Icons.lock,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        network.securityTypeString,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.signal_cellular_4_bar,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        network.signalStrengthString,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  // Action button
                  _buildActionButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlert({
    required IconData icon,
    required String message,
    required AlertType type,
  }) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (type) {
      case AlertType.danger:
        bgColor = AppColors.alertDangerBg;
        textColor = AppColors.alertDangerText;
        borderColor = AppColors.alertDangerBorder;
        break;
      case AlertType.warning:
        bgColor = AppColors.alertWarningBg;
        textColor = AppColors.alertWarningText;
        borderColor = AppColors.alertWarningBorder;
        break;
      case AlertType.success:
        bgColor = AppColors.alertSuccessBg;
        textColor = AppColors.alertSuccessText;
        borderColor = AppColors.alertSuccessBorder;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: borderColor,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    switch (network.status) {
      case NetworkStatus.verified:
      case NetworkStatus.trusted:
        return ElevatedButton(
          onPressed: onConnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(80, 32),
          ),
          child: Text(
            network.isSaved ? 'Auto-Connect' : 'Connect',
            style: const TextStyle(fontSize: 14),
          ),
        );
      case NetworkStatus.blocked:
        return ElevatedButton(
          onPressed: () => onAccessPointAction?.call(AccessPointAction.unblock),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(80, 32),
          ),
          child: const Text('Unblock', style: TextStyle(fontSize: 14)),
        );
      case NetworkStatus.flagged:
        return PopupMenuButton<AccessPointAction>(
          onSelected: (action) => onAccessPointAction?.call(action),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: AccessPointAction.unflag,
              child: Row(
                children: [
                  Icon(Icons.outlined_flag, size: 16),
                  SizedBox(width: 8),
                  Text('Unflag'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: AccessPointAction.block,
              child: Row(
                children: [
                  Icon(Icons.block, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Block'),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Actions', style: TextStyle(color: Colors.white, fontSize: 14)),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
              ],
            ),
          ),
        );
      default:
        return PopupMenuButton<AccessPointAction>(
          onSelected: (action) => onAccessPointAction?.call(action),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: AccessPointAction.trust,
              child: Row(
                children: [
                  Icon(Icons.shield, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Trust'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: AccessPointAction.flag,
              child: Row(
                children: [
                  Icon(Icons.flag, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Flag'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: AccessPointAction.block,
              child: Row(
                children: [
                  Icon(Icons.block, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Block'),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Actions', style: TextStyle(color: Colors.white, fontSize: 14)),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
              ],
            ),
          ),
        );
    }
  }

  void _showUnverifiedConnectionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.warning,
              color: Colors.blue,
              size: 24,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Unverified Network',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This network is not on the verified list. Use caution when connecting. Continue?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Network: ${network.name}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
                onConnect?.call();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Connect Anyway'),
          ),
        ],
      ),
    );
  }

  void _showNetworkDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Network name and status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          network.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      StatusBadge(status: network.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Details grid
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Network Name', network.name),
                        const SizedBox(height: 12),
                        _buildDetailRow('Security', network.securityTypeString),
                        const SizedBox(height: 12),
                        _buildDetailRow('MAC Address', network.macAddress),
                        const SizedBox(height: 12),
                        _buildDetailRow('Signal Strength', '${network.signalStrength}% (${network.signalStrengthString})'),
                        const SizedBox(height: 12),
                        _buildDetailRow('Location', network.displayLocation),
                        if (network.description != null) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow('Description', network.description!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action buttons for detail sheet
                  _buildDetailSheetActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSheetActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Show different actions based on status
        if (network.status == NetworkStatus.blocked) ...[
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onAccessPointAction?.call(AccessPointAction.unblock);
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('Unblock Network'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ] else if (network.status == NetworkStatus.trusted) ...[
          ElevatedButton.icon(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
                onAccessPointAction?.call(AccessPointAction.untrust);
              }
            },
            icon: const Icon(Icons.remove_circle),
            label: const Text('Remove from Trusted'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
                onAccessPointAction?.call(AccessPointAction.block);
              }
            },
            icon: const Icon(Icons.block),
            label: const Text('Block Network'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ] else if (network.status == NetworkStatus.flagged) ...[
          ElevatedButton.icon(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
                onAccessPointAction?.call(AccessPointAction.unflag);
              }
            },
            icon: const Icon(Icons.outlined_flag),
            label: const Text('Remove Flag'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
                onAccessPointAction?.call(AccessPointAction.block);
              }
            },
            icon: const Icon(Icons.block),
            label: const Text('Block Network'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ] else ...[
          // Default actions for unknown/suspicious/verified networks
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (context.mounted) {
                      Navigator.pop(context);
                      onAccessPointAction?.call(AccessPointAction.trust);
                    }
                  },
                  icon: const Icon(Icons.shield),
                  label: const Text('Trust'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (context.mounted) {
                      Navigator.pop(context);
                      onAccessPointAction?.call(AccessPointAction.flag);
                    }
                  },
                  icon: const Icon(Icons.flag),
                  label: const Text('Flag'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
                onAccessPointAction?.call(AccessPointAction.block);
              }
            },
            icon: const Icon(Icons.block),
            label: const Text('Block Network'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
        
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('Close'),
        ),
        
        // Add connection button if network is not blocked
        if (network.status != NetworkStatus.blocked) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (context.mounted) {
                  Navigator.pop(context);
                  if (network.status == NetworkStatus.verified ||
                      network.status == NetworkStatus.trusted) {
                    onConnect?.call();
                  } else {
                    // Show connection warning for unverified networks
                    _showUnverifiedConnectionDialog(context);
                  }
                }
              },
              icon: const Icon(Icons.wifi),
              label: const Text('Connect to Network'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Build security grade badge
  Widget _buildSecurityBadge(SecurityAssessment assessment) {
    final color = _getSecurityGradeColor(assessment.securityGrade);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getSecurityIcon(assessment.threatLevel),
            size: 10,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            assessment.securityGrade,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build security alerts for detected threats
  List<Widget> _buildSecurityAlerts(SecurityAssessment assessment) {
    final alerts = <Widget>[];
    
    // Show high-priority threats
    if (assessment.shouldAvoidConnection) {
      alerts.add(const SizedBox(height: 12));
      alerts.add(_buildAlert(
        icon: Icons.dangerous,
        message: assessment.primaryRecommendation,
        type: AlertType.danger,
      ));
    } else if (assessment.threatLevel == ThreatLevel.medium) {
      alerts.add(const SizedBox(height: 12));
      alerts.add(_buildAlert(
        icon: Icons.warning,
        message: assessment.primaryRecommendation,
        type: AlertType.warning,
      ));
    }
    
    return alerts;
  }

  /// Get color for security grade
  Color _getSecurityGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.lightGreen;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.deepOrange;
      case 'F':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get icon for threat level
  IconData _getSecurityIcon(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.low:
        return Icons.security;
      case ThreatLevel.medium:
        return Icons.warning;
      case ThreatLevel.high:
        return Icons.error;
      case ThreatLevel.critical:
        return Icons.dangerous;
    }
  }

}

enum AlertType { danger, warning, success }