import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/models/network_model.dart';
import '../../../data/models/security_assessment.dart';
import '../../../providers/alert_provider.dart';
import '../../../providers/network_provider.dart';
import '../threats/manual_threat_report_screen.dart';
import 'widgets/alert_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _headerAnimationController;
  late ScrollController _scrollController;
  
  static const double _headerMaxHeight = 100.0; // Base height without threat summary
  static const double _headerMaxHeightWithThreats = 155.0; // Increased height when threat summary is shown
  static const double _headerMinHeight = 0.0; // Completely hide header when scrolled

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialize scroll hiding animation
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    // Note: We'll create the animation dynamically in build method based on threat status
    
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    const scrollThreshold = 50.0;
    if (_scrollController.hasClients) {
      final scrollOffset = _scrollController.offset;
      final progress = (scrollOffset / scrollThreshold).clamp(0.0, 1.0);
      
      if (progress > 0.5 && !_headerAnimationController.isAnimating) {
        _headerAnimationController.forward();
      } else if (progress <= 0.3 && !_headerAnimationController.isAnimating) {
        _headerAnimationController.reverse();
      }
    }
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
        // Animated Header with gradient background
        Consumer<NetworkProvider>(
          builder: (context, networkProvider, child) {
            final threatsDetected = networkProvider.threatsDetected;
            final hasThreats = threatsDetected > 0;
            
            // Create dynamic animation based on threat status
            final maxHeight = hasThreats ? _headerMaxHeightWithThreats : _headerMaxHeight;
            final currentHeaderAnimation = Tween<double>(
              begin: maxHeight,
              end: _headerMinHeight,
            ).animate(CurvedAnimation(
              parent: _headerAnimationController,
              curve: Curves.easeInOut,
            ));
            
            return AnimatedBuilder(
              animation: currentHeaderAnimation,
              builder: (context, child) {
                final isCollapsed = _headerAnimationController.value > 0.5;
                final opacity = 1.0 - _headerAnimationController.value;
                return Container(
                  constraints: BoxConstraints(
                    maxHeight: currentHeaderAnimation.value,
                    minHeight: 0,
                  ),
                  decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: opacity),
                    Colors.white.withValues(alpha: opacity * 0.95),
                    Colors.grey[50]!.withValues(alpha: opacity * 0.8),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), // Further reduced padding to prevent overflow
              child: Opacity(
                opacity: opacity,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // Prevent overflow by using minimum required size
                    children: [
                    Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: isCollapsed ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!isCollapsed) ...[
                            const SizedBox(height: 2),
                            // Last scan info moved as subtitle
                            Consumer<NetworkProvider>(
                              builder: (context, networkProvider, child) {
                                if (networkProvider.isScanning) {
                                  return const Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Scanning networks...',
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
                                
                                return Text(
                                  'No scans performed yet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                      // About button
                      IconButton(
                        onPressed: _showAboutDialog,
                        icon: const Icon(Icons.info_outline),
                        tooltip: 'About',
                        iconSize: 20,
                      ),
                    ],
                  ),
                  
                  // Threat summary (only show when expanded)
                  if (!isCollapsed) ...[
                    Consumer<NetworkProvider>(
                      builder: (context, networkProvider, child) {
                        final threatsDetected = networkProvider.threatsDetected;
                        
                        if (threatsDetected > 0) {
                          return Container(
                            margin: const EdgeInsets.only(top: 6), // Further reduced margin
                            padding: const EdgeInsets.all(8), // Further reduced padding
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: const BorderRadius.all(Radius.circular(8)),
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
                                      fontSize: 13, // Reduced font size to save space
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
                ],
                  ),
                ),
              ),
            );
              },
            );
          },
        ),
        
        // Tabs with gradient background and subtle shadow
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.white.withValues(alpha: 0.95),
                Colors.grey[50]!.withValues(alpha: 0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.15),
                offset: const Offset(0, 1),
                blurRadius: 3,
                spreadRadius: 0,
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.gray,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            dividerColor: Colors.transparent, // Remove divider line
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
                    controller: tabIndex == 0 ? _scrollController : null, // Only apply to Recent tab
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
                        borderRadius: const BorderRadius.all(Radius.circular(2)),
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
                      decoration: const BoxDecoration(
                        color: AppColors.bgGray,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
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
    
    // Handle threat reporting for reportable alerts
    if ((alert.type == AlertType.reportSuggestion || 
         alert.type == AlertType.suspiciousNetwork || 
         alert.type == AlertType.evilTwin) && 
        alert.threatReportStatus == ThreatReportStatus.pending) {
      _handleThreatReport(alert);
      return;
    }
    
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
  
  void _handleThreatReport(AlertModel alert) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Preparing threat report...'),
            ],
          ),
        ),
      );

      final networkProvider = context.read<NetworkProvider>();
      
      // Find the network associated with this alert
      NetworkModel? network;
      if (alert.networkName != null && alert.macAddress != null) {
        network = networkProvider.networks.firstWhere(
          (n) => n.name == alert.networkName && n.macAddress == alert.macAddress,
          orElse: () => NetworkModel(
            id: 'alert_network_${alert.networkName}',
            name: alert.networkName!,
            description: 'Network from security alert',
            status: NetworkStatus.suspicious,
            securityType: SecurityType.open,
            signalStrength: 0,
            macAddress: alert.macAddress ?? '00:00:00:00:00:00',
            lastSeen: DateTime.now(),
          ),
        );
      }
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Navigate to threat report screen with pre-filled data
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ManualThreatReportScreen(
              prefilledNetwork: network,
              sourceAlert: alert,
              suggestedThreatType: _getThreatTypeFromAlert(alert),
              suggestedDescription: _getDescriptionFromAlert(alert),
            ),
          ),
        );
        
        // Only show success and update status if report was actually submitted
        if (mounted && result == true) {
          final alertProvider = context.read<AlertProvider>();
          alertProvider.markAsRead(alert.id);
          alertProvider.updateThreatReportStatus(alert.id, ThreatReportStatus.reported);
          
          // Show confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Threat reported successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);
      
      // Mark threat report as failed
      if (mounted) {
        final alertProvider = context.read<AlertProvider>();
        alertProvider.updateThreatReportStatus(alert.id, ThreatReportStatus.failed);
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit threat report: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleThreatReport(alert),
            ),
          ),
        );
      }
    }
  }
  
  String _getThreatTypeFromAlert(AlertModel alert) {
    switch (alert.type) {
      case AlertType.evilTwin:
        return 'Evil Twin Attack';
      case AlertType.suspiciousNetwork:
        return 'Suspicious Network Activity';
      case AlertType.critical:
        return 'Critical Security Threat';
      case AlertType.reportSuggestion:
        return 'Security Threat Detection';
      default:
        return 'Network Security Issue';
    }
  }
  
  String _getDescriptionFromAlert(AlertModel alert) {
    // Extract description from alert message, removing the reporting instruction
    String description = alert.message;
    
    // Remove the "Tap the Report Threat button..." instruction
    final reportInstructionStart = description.indexOf('Tap the "Report Threat"');
    if (reportInstructionStart > 0) {
      description = description.substring(0, reportInstructionStart).trim();
    }
    
    // Clean up any remaining formatting
    description = description.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
    
    return description;
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'About Notifications',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Real-Time Security Monitoring',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stay protected with intelligent network security alerts. Our system continuously monitors your WiFi environment and notifies you of potential threats.',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              
              // Features section
              const Text(
                'Key Features',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              
              ...[
                _buildFeatureItem(
                  Icons.security,
                  'Threat Detection',
                  'Automatically identifies suspicious networks and security risks',
                  AppColors.danger,
                ),
                _buildFeatureItem(
                  Icons.report_problem,
                  'Community Reporting',
                  'Report threats to help protect other users in the network',
                  AppColors.warning,
                ),
                _buildFeatureItem(
                  Icons.shield_outlined,
                  'Network Verification',
                  'Verify legitimate networks against our trusted database',
                  AppColors.success,
                ),
                _buildFeatureItem(
                  Icons.history,
                  'Alert History',
                  'Keep track of all security events and your responses',
                  AppColors.primary,
                ),
              ],
              
              const SizedBox(height: 20),
              const Text(
                'Alert Types',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAlertTypeRow('🔴', 'Critical/Suspicious', 'Immediate security threats requiring action'),
                    const SizedBox(height: 6),
                    _buildAlertTypeRow('🟡', 'Warning', 'Networks that need attention or verification'),
                    const SizedBox(height: 6),
                    _buildAlertTypeRow('🔵', 'Information', 'General updates and network status changes'),
                    const SizedBox(height: 6),
                    _buildAlertTypeRow('🟢', 'Success', 'Trusted networks and positive confirmations'),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Tap on any notification to view detailed information and take appropriate security actions.',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeatureItem(IconData icon, String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
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
  
  Widget _buildAlertTypeRow(String emoji, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.grey[800], fontSize: 13),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}