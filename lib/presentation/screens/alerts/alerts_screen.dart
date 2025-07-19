import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/models/network_model.dart';
import '../../../providers/alert_provider.dart';
import '../../../providers/network_provider.dart';
import 'widgets/alert_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<AlertModel> _getFilteredAlerts(AlertProvider alertProvider, int tabIndex) {
    switch (tabIndex) {
      case 0: // Recent
        return alertProvider.recentAlerts;
      case 1: // All
        return alertProvider.alerts;
      case 2: // Archived
        return alertProvider.archivedAlerts;
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Title and scan status
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Security Alerts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Consumer<NetworkProvider>(
                    builder: (context, networkProvider, child) {
                      if (networkProvider.isScanning) {
                        return Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Scanning...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        );
                      }
                      
                      if (networkProvider.hasPerformedScan && networkProvider.lastScanTime != null) {
                        return Text(
                          'Last scan: ${_formatLastScanTime(networkProvider.lastScanTime!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        );
                      }
                      
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
              
              // Threat summary
              Consumer<NetworkProvider>(
                builder: (context, networkProvider, child) {
                  final threatsDetected = networkProvider.threatsDetected;
                  // Track suspicious networks for potential UI enhancements
                  
                  if (threatsDetected > 0) {
                    return Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: Colors.red[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$threatsDetected potential threats detected in last scan',
                              style: TextStyle(
                                color: Colors.red[800],
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
        
        // Tabs
        Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.lightGray, width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.gray,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            tabs: const [
              Tab(text: 'Recent'),
              Tab(text: 'All'),
              Tab(text: 'Archived'),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: Consumer<AlertProvider>(
            builder: (context, alertProvider, child) {
              return TabBarView(
                controller: _tabController,
                children: List.generate(3, (tabIndex) {
                  final alerts = _getFilteredAlerts(alertProvider, tabIndex);
                  
                  if (alerts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No alerts',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AlertCard(
                          alert: alerts[index],
                          onDetails: () => _showAlertDetails(alerts[index]),
                          onAction: () => _handleAlertAction(alerts[index]),
                          onDismiss: () => _dismissAlert(alertProvider, alerts[index]),
                        ),
                      );
                    },
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAlertDetails(AlertModel alert) {
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
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
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
                  
                  // Alert details
                  Text(
                    alert.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTimestamp(alert.timestamp),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    alert.message,
                    style: const TextStyle(fontSize: 16),
                  ),
                  
                  if (alert.networkName != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgGray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Network Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow('Network Name', alert.networkName!),
                          if (alert.securityType != null) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('Security', alert.securityType!),
                          ],
                          if (alert.macAddress != null) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('MAC Address', alert.macAddress!),
                          ],
                          if (alert.location != null) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('Location', alert.location!),
                          ],
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                      if (alert.type == AlertType.critical) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _handleAlertAction(alert);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                            ),
                            child: const Text('Block Network'),
                          ),
                        ),
                      ],
                    ],
                  ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _handleAlertAction(AlertModel alert) {
    final networkProvider = context.read<NetworkProvider>();
    
    // If this is a network-related alert, allow blocking the network
    if (alert.networkName != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Network Actions'),
          content: Text('What would you like to do about "${alert.networkName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (alert.type == AlertType.critical || alert.type == AlertType.evilTwin || alert.type == AlertType.suspiciousNetwork) ...[
              TextButton(
                onPressed: () async {
                  // Extract context references before async operation
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  
                  // Find the network and trust it
                  final network = networkProvider.networks.firstWhere(
                    (n) => n.name == alert.networkName,
                    orElse: () => NetworkModel(
                      id: 'alert_network_${alert.networkName}',
                      name: alert.networkName!,
                      description: 'Network from alert',
                      status: NetworkStatus.suspicious,
                      securityType: SecurityType.open,
                      signalStrength: 0,
                      macAddress: alert.macAddress ?? '00:00:00:00:00:00',
                      lastSeen: DateTime.now(),
                    ),
                  );
                  
                  await networkProvider.trustNetwork(network.id);
                  if (mounted) {
                    navigator.pop();
                    
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('"${alert.networkName}" has been trusted'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: Text('Trust', style: TextStyle(color: Colors.green[600])),
              ),
              TextButton(
                onPressed: () async {
                  // Extract context references before async operation
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  
                  // Find the network and flag it
                  final network = networkProvider.networks.firstWhere(
                    (n) => n.name == alert.networkName,
                    orElse: () => NetworkModel(
                      id: 'alert_network_${alert.networkName}',
                      name: alert.networkName!,
                      description: 'Network from alert',
                      status: NetworkStatus.suspicious,
                      securityType: SecurityType.open,
                      signalStrength: 0,
                      macAddress: alert.macAddress ?? '00:00:00:00:00:00',
                      lastSeen: DateTime.now(),
                    ),
                  );
                  
                  await networkProvider.flagNetwork(network.id);
                  if (mounted) {
                    navigator.pop();
                    
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('"${alert.networkName}" has been flagged'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: Text('Flag', style: TextStyle(color: Colors.orange[600])),
              ),
            ],
            ElevatedButton(
              onPressed: () async {
                // Extract context references before async operation
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                // Find the network and block it
                final network = networkProvider.networks.firstWhere(
                  (n) => n.name == alert.networkName,
                  orElse: () => NetworkModel(
                    id: 'alert_network_${alert.networkName}',
                    name: alert.networkName!,
                    description: 'Network from alert',
                    status: NetworkStatus.suspicious,
                    securityType: SecurityType.open,
                    signalStrength: 0,
                    macAddress: alert.macAddress ?? '00:00:00:00:00:00',
                    lastSeen: DateTime.now(),
                  ),
                );
                
                await networkProvider.blockNetwork(network.id);
                if (mounted) {
                  navigator.pop();
                  
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('"${alert.networkName}" has been blocked'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Block Network'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action taken for ${alert.title}'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _dismissAlert(AlertProvider alertProvider, AlertModel alert) {
    // Mark alert as read and archive it through the provider
    alertProvider.markAsRead(alert.id);
    alertProvider.archiveAlert(alert.id);
  }
  
  String _formatLastScanTime(DateTime lastScan) {
    final now = DateTime.now();
    final difference = now.difference(lastScan);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}