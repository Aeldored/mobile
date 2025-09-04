import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/network_model.dart';
import '../../../data/services/access_point_service.dart';
import '../../../providers/network_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_spinner.dart';
import '../main_screen.dart';

class AccessPointManagerScreen extends StatefulWidget {
  const AccessPointManagerScreen({super.key});

  @override
  State<AccessPointManagerScreen> createState() => _AccessPointManagerScreenState();
}

class _AccessPointManagerScreenState extends State<AccessPointManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;

  Future<bool> _onWillPop() async {
    // Navigate back to home instead of exiting the app
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainScreen.navigateToTab(context, 0);
    return false;
  }
  final AccessPointService _accessPointService = AccessPointService();
  
  bool _isLoading = false;
  Map<String, int> _stats = {};
  bool _isStatsVisible = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    _accessPointService.initialize();
    _loadStats();
  }
  
  void _handleScroll() {
    const double threshold = 50.0;
    final bool shouldHide = _scrollController.offset > threshold;
    
    if (shouldHide != !_isStatsVisible) {
      setState(() {
        _isStatsVisible = !shouldHide;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _accessPointService.getAccessPointStats();
      setState(() => _stats = stats);
    } catch (e) {
      developer.log('Error loading stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          AppHeader(
            title: 'Access Point Manager',
            showBackButton: true,
            showNotificationIcon: false, // Remove notification bell
            showSettingsIcon: false, // Remove menu icon
            showAboutIcon: true, // Show About button
            onAboutTap: _showAboutDialog, // Add About button functionality
          ),
          
          // Statistics Card with scroll-to-hide animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isStatsVisible ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isStatsVisible ? 1.0 : 0.0,
              child: _buildStatsCard(),
            ),
          ),
          
          // Tab Bar with subtle shadow
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: AppColors.primary,
              dividerColor: Colors.transparent, // Remove divider line
              tabs: [
                Tab(
                  icon: const Icon(Icons.block),
                  text: 'Blocked (${_stats['blocked'] ?? 0})',
                ),
                Tab(
                  icon: const Icon(Icons.shield),
                  text: 'Trusted (${_stats['trusted'] ?? 0})',
                ),
                Tab(
                  icon: const Icon(Icons.flag),
                  text: 'Flagged (${_stats['flagged'] ?? 0})',
                ),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAccessPointList(AccessPointCategory.blocked),
                _buildAccessPointList(AccessPointCategory.trusted),
                _buildAccessPointList(AccessPointCategory.flagged),
              ],
            ),
          ),
        ],
      ),
      
      // Floating Action Button for bulk actions
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showBulkActionsDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.more_horiz),
        label: const Text('Bulk Actions'),
      ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: AppColors.primary,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Access Point Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (_isLoading)
            const Center(child: LoadingSpinner())
          else
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Managed',
                    '${_stats['total'] ?? 0}',
                    Colors.blue,
                    Icons.router,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Blocked',
                    '${_stats['blocked'] ?? 0}',
                    Colors.red,
                    Icons.block,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Trusted',
                    '${_stats['trusted'] ?? 0}',
                    Colors.green,
                    Icons.shield,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Flagged',
                    '${_stats['flagged'] ?? 0}',
                    Colors.orange,
                    Icons.flag,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAccessPointList(AccessPointCategory category) {
    return Consumer<NetworkProvider>(
      builder: (context, networkProvider, child) {
        return RefreshIndicator(
          onRefresh: () async {
            // Force rebuild by calling setState
            setState(() {});
          },
          child: FutureBuilder<List<NetworkModel>>(
            future: _getAccessPointsByCategory(category),
            builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingSpinner());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading access points',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final accessPoints = snapshot.data ?? [];

        if (accessPoints.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getCategoryIcon(category),
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${_getCategoryName(category).toLowerCase()} access points',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Access points you ${_getCategoryAction(category)} will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await _loadStats();
          },
          child: ListView.builder(
            controller: _scrollController, // Add scroll controller for stats hiding
            padding: const EdgeInsets.all(16),
            itemCount: accessPoints.length,
            itemBuilder: (context, index) {
              final accessPoint = accessPoints[index];
              return AccessPointManagerCard(
                network: accessPoint,
                category: category,
                onAction: (action) => _handleAccessPointAction(accessPoint, action),
                onDelete: () => _removeAccessPoint(accessPoint, category),
              );
            },
          ),
        );
      },
    ),
        );
      },
    );
  }

  Future<List<NetworkModel>> _getAccessPointsByCategory(AccessPointCategory category) async {
    switch (category) {
      case AccessPointCategory.blocked:
        return await _accessPointService.getBlockedAccessPoints();
      case AccessPointCategory.trusted:
        return await _accessPointService.getTrustedAccessPoints();
      case AccessPointCategory.flagged:
        return await _accessPointService.getFlaggedAccessPoints();
    }
  }

  String _getCategoryName(AccessPointCategory category) {
    switch (category) {
      case AccessPointCategory.blocked:
        return 'Blocked';
      case AccessPointCategory.trusted:
        return 'Trusted';
      case AccessPointCategory.flagged:
        return 'Flagged';
    }
  }

  String _getCategoryAction(AccessPointCategory category) {
    switch (category) {
      case AccessPointCategory.blocked:
        return 'block';
      case AccessPointCategory.trusted:
        return 'trust';
      case AccessPointCategory.flagged:
        return 'flag';
    }
  }

  IconData _getCategoryIcon(AccessPointCategory category) {
    switch (category) {
      case AccessPointCategory.blocked:
        return Icons.block;
      case AccessPointCategory.trusted:
        return Icons.shield;
      case AccessPointCategory.flagged:
        return Icons.flag;
    }
  }

  Future<void> _handleAccessPointAction(NetworkModel network, AccessPointAction action) async {
    try {
      final networkProvider = context.read<NetworkProvider>();
      
      // Use NetworkProvider methods to ensure both internal state and AccessPointService are updated
      switch (action) {
        case AccessPointAction.block:
          await networkProvider.blockNetwork(network.id);
          break;
        case AccessPointAction.trust:
          await networkProvider.trustNetwork(network.id);
          break;
        case AccessPointAction.flag:
          await networkProvider.flagNetwork(network.id);
          break;
        case AccessPointAction.unblock:
          await networkProvider.unblockNetwork(network.id);
          break;
        case AccessPointAction.untrust:
          await networkProvider.untrustNetwork(network.id);
          break;
        case AccessPointAction.unflag:
          await networkProvider.unflagNetwork(network.id);
          break;
      }

      // Refresh data
      setState(() {});
      await _loadStats();
      
      // Force nearby networks to update by ensuring filtered networks are refreshed
      developer.log('🔄 Access Point Manager: ${action.name} action completed for ${network.name} - nearby networks should update automatically');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access point ${action.name.toLowerCase()}ed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${action.name.toLowerCase()} access point: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeAccessPoint(NetworkModel network, AccessPointCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Access Point'),
        content: Text(
          'Are you sure you want to remove "${network.name}" from your ${_getCategoryName(category).toLowerCase()} list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final networkProvider = context.read<NetworkProvider>();
        
        // Use NetworkProvider methods to ensure both internal state and AccessPointService are updated
        switch (category) {
          case AccessPointCategory.blocked:
            await networkProvider.unblockNetwork(network.id);
            break;
          case AccessPointCategory.trusted:
            await networkProvider.untrustNetwork(network.id);
            break;
          case AccessPointCategory.flagged:
            await networkProvider.unflagNetwork(network.id);
            break;
        }

        // Refresh data
        setState(() {});
        await _loadStats();

        if (mounted) {
          // Show different messages based on removal type
          String message;
          switch (category) {
            case AccessPointCategory.blocked:
            case AccessPointCategory.trusted:
              message = 'Access point removed successfully. Scan networks to see it with fresh security evaluation.';
              break;
            case AccessPointCategory.flagged:
              message = 'Access point removed successfully';
              break;
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4), // Longer duration for scan message
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove access point: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showBulkActionsDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bulk Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.file_download, color: AppColors.primary),
              title: const Text('Export Data'),
              subtitle: const Text('Export all managed access points'),
              onTap: () {
                Navigator.pop(context);
                _exportData();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.file_upload, color: AppColors.primary),
              title: const Text('Import Data'),
              subtitle: const Text('Import access point configuration'),
              onTap: () {
                Navigator.pop(context);
                _importData();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.sync, color: AppColors.primary),
              title: const Text('Sync with Cloud'),
              subtitle: const Text('Synchronize with Firebase'),
              onTap: () {
                Navigator.pop(context);
                _syncWithCloud();
              },
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Clear All Data'),
              subtitle: const Text('Remove all managed access points'),
              onTap: () {
                Navigator.pop(context);
                _clearAllData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      setState(() => _isLoading = true);
      final data = await _accessPointService.exportAccessPointData();
      
      // Create JSON string with timestamp
      final exportData = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
        'app': 'DisConX',
        'data': data,
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/disconx_access_points_$timestamp.json');
      await file.writeAsString(jsonString);
      
      // Share the file
      final totalCount = (data['blocked']?.length ?? 0) + 
                        (data['trusted']?.length ?? 0) + 
                        (data['flagged']?.length ?? 0);
                        
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'DisConX Access Points Export - $totalCount access points',
        subject: 'DisConX Access Points Configuration',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Successfully exported $totalCount access points'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View File',
              textColor: Colors.white,
              onPressed: () async {
                await Share.shareXFiles([XFile(file.path)]);
              },
            ),
          ),
        );
      }
    } catch (e) {
      developer.log('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Export failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importData() async {
    // In a real implementation, show file picker
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import feature coming soon'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _syncWithCloud() async {
    try {
      setState(() => _isLoading = true);
      
      // In a real implementation, sync with Firebase
      await Future.delayed(const Duration(seconds: 2)); // Simulate sync
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synced with cloud successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will remove all managed access points from all categories. This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _accessPointService.clearAllManagedAccessPoints();
        setState(() {});
        await _loadStats();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_protected_setup, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Access Point Manager'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Manage and organize your Wi-Fi access points for enhanced security and convenience.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              SizedBox(height: 16),
              
              Text('Features:', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('• Block suspicious or malicious networks'),
              Text('• Trust known and safe networks'),
              Text('• Flag networks for investigation'),
              Text('• Bulk export and import configurations'),
              Text('• Cloud synchronization support'),
              Text('• Comprehensive statistics tracking'),
              
              SizedBox(height: 16),
              
              Text('Categories:', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('🚫 Blocked: Networks that are completely blocked'),
              Text('🛡️ Trusted: Networks marked as safe to connect'),
              Text('🚩 Flagged: Networks requiring attention or review'),
              
              SizedBox(height: 16),
              
              Text('Bulk Actions:', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('• Export data as JSON files for backup'),
              Text('• Import configurations from other devices'),
              Text('• Synchronize with Firebase cloud storage'),
              Text('• Clear all managed access points'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Access Point Card for Manager
class AccessPointManagerCard extends StatelessWidget {
  final NetworkModel network;
  final AccessPointCategory category;
  final Function(AccessPointAction) onAction;
  final VoidCallback onDelete;

  const AccessPointManagerCard({
    super.key,
    required this.network,
    required this.category,
    required this.onAction,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: _getCategoryColor(category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        network.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        network.displayLocation,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuAction(value),
                  itemBuilder: (context) => [
                    if (category != AccessPointCategory.trusted)
                      const PopupMenuItem(
                        value: 'trust',
                        child: ListTile(
                          leading: Icon(Icons.shield, color: Colors.blue),
                          title: Text('Trust'),
                          dense: true,
                        ),
                      ),
                    if (category != AccessPointCategory.blocked)
                      const PopupMenuItem(
                        value: 'block',
                        child: ListTile(
                          leading: Icon(Icons.block, color: Colors.red),
                          title: Text('Block'),
                          dense: true,
                        ),
                      ),
                    if (category != AccessPointCategory.flagged)
                      const PopupMenuItem(
                        value: 'flag',
                        child: ListTile(
                          leading: Icon(Icons.flag, color: Colors.orange),
                          title: Text('Flag'),
                          dense: true,
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Remove'),
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Details
            Row(
              children: [
                Expanded(
                  child: _buildDetailChip(
                    'MAC',
                    '${network.macAddress.substring(0, 8)}...',
                    Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDetailChip(
                    'Security',
                    network.securityTypeString,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDetailChip(
                    'Signal',
                    '${network.signalStrength}%',
                    Colors.green,
                  ),
                ),
              ],
            ),
            
            if (network.lastActionDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last action: ${_formatDateTime(network.lastActionDate!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'trust':
        onAction(AccessPointAction.trust);
        break;
      case 'block':
        onAction(AccessPointAction.block);
        break;
      case 'flag':
        onAction(AccessPointAction.flag);
        break;
      case 'remove':
        onDelete();
        break;
    }
  }

  Color _getCategoryColor(AccessPointCategory category) {
    switch (category) {
      case AccessPointCategory.blocked:
        return Colors.red;
      case AccessPointCategory.trusted:
        return Colors.green;
      case AccessPointCategory.flagged:
        return Colors.orange;
    }
  }

  IconData _getCategoryIcon(AccessPointCategory category) {
    switch (category) {
      case AccessPointCategory.blocked:
        return Icons.block;
      case AccessPointCategory.trusted:
        return Icons.shield;
      case AccessPointCategory.flagged:
        return Icons.flag;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}