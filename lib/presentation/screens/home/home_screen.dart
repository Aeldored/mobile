import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/network_model.dart';
import '../../../data/models/wifi_connection_result.dart';
import '../../../data/services/access_point_service.dart';
import '../../../data/services/wifi_connection_manager.dart';
import '../../../data/services/wifi_connection_service.dart';
import '../../../providers/network_provider.dart';
import 'widgets/network_map_widget.dart';
import 'widgets/connection_info_widget.dart';
import 'widgets/network_card.dart';
import '../main_screen.dart';
import '../../widgets/demo_mode_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AccessPointService _accessPointService = AccessPointService();
  final WiFiConnectionManager _connectionManager = WiFiConnectionManager();
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _accessPointService.initialize();
    // Load networks after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNetworks();
    });
  }

  Future<void> _loadNetworks() async {
    final provider = context.read<NetworkProvider>();
    await provider.startNetworkScan(forceRescan: false, isManualScan: false);
  }

  Future<void> _handleRefresh() async {
    final provider = context.read<NetworkProvider>();
    await provider.startNetworkScan(forceRescan: true, isManualScan: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _connectionManager.dispose();
    super.dispose();
  }

  Widget _buildScanPrompt() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600;
    
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_find,
                size: isSmallScreen ? 40 : 48,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              'No Networks Discovered',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              'Start a scan to discover nearby Wi-Fi networks and check for potential security threats.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                color: Colors.grey[600],
                height: 1.3,
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            ElevatedButton.icon(
              onPressed: _navigateToScan,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Start Network Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 20 : 24,
                  vertical: isSmallScreen ? 10 : 12,
                ),
                textStyle: TextStyle(
                  fontSize: isSmallScreen ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            TextButton(
              onPressed: () => _loadNetworks(),
              child: Text(
                'Load Sample Networks',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: isSmallScreen ? 11 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyNetworksState() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600;
    
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off,
                size: isSmallScreen ? 40 : 48,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              'No Networks Found',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              'The scan completed but no Wi-Fi networks were detected in your area. This could be due to distance from access points or network availability.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                color: Colors.grey[600],
                height: 1.3,
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            ElevatedButton.icon(
              onPressed: _navigateToScan,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Scan Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 20 : 24,
                  vertical: isSmallScreen ? 10 : 12,
                ),
                textStyle: TextStyle(
                  fontSize: isSmallScreen ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToScan() {
    // Start scanning using the shared provider
    final provider = context.read<NetworkProvider>();
    provider.startNetworkScan(forceRescan: true, isManualScan: true);
    
    // Navigate to the Scan tab (index 1)
    MainScreen.navigateToTab(context, 1);
    
    // Show a brief message indicating scan has started
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Network scan started'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _refreshConnectionInfo() async {
    final provider = context.read<NetworkProvider>();
    // Force refresh of current connection info
    await provider.refreshNetworks();
  }

  Future<void> _handleDisconnect() async {
    if (!mounted) return;

    try {
      developer.log('User requested disconnect from current network');
      
      // Show confirmation dialog for direct disconnect
      final shouldDisconnect = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.wifi_off,
                color: Colors.red[600],
                size: 24,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Disconnect from Wi-Fi?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Disconnection info card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wifi_off_outlined, color: Colors.red[700], size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Network Disconnection',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'This will disconnect you from the current Wi-Fi network.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // System settings info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.settings, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'System Settings Disconnection',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'For security, Android may require disconnection through system settings. '
                        'If automatic disconnect fails, you\'ll be guided to Wi-Fi settings.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_outlined, color: Colors.orange[700], size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'You will need to reconnect manually to use this network again',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 40),
              ),
              child: const Text('Disconnect'),
            ),
          ],
        ),
      );

      if (shouldDisconnect != true || !mounted) return;

      // Show disconnecting progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Disconnecting from Wi-Fi...'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Use native controller to disconnect directly
      final WiFiConnectionService connectionService = WiFiConnectionService();
      final disconnectResult = await connectionService.disconnectFromCurrent();
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        if (disconnectResult) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Successfully disconnected from Wi-Fi'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Refresh connection info to update UI
          await _refreshConnectionInfo();
        } else {
          // Show fallback option to open settings
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not disconnect automatically. Use Wi-Fi settings to disconnect manually.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Open Settings',
                textColor: Colors.white,
                onPressed: () => _openWiFiSettings(),
              ),
            ),
          );
        }
      }

    } catch (e) {
      developer.log('Exception in _handleDisconnect: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Open Settings',
              textColor: Colors.white,
              onPressed: () => _openWiFiSettings(),
            ),
          ),
        );
      }
    }
  }

  /// Open device WiFi settings for manual disconnect
  Future<void> _openWiFiSettings() async {
    try {
      developer.log('Opening WiFi settings for manual disconnect');
      
      // Use platform channel to open Wi-Fi settings
      const platform = MethodChannel('com.dict.disconx/wifi');
      await platform.invokeMethod('openWifiSettings', {
        'action': 'disconnect',
        'message': 'Find your current network and disconnect',
      });
      
      developer.log('Successfully opened WiFi settings');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.settings, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Wi-Fi settings opened - find your network to disconnect'),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      developer.log('Failed to open Wi-Fi settings via platform channel: $e');
      
      if (mounted) {
        // Show fallback message if platform channel fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Unable to open Wi-Fi settings automatically. Please manually open your device\'s Wi-Fi settings to disconnect.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Understood',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primary,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Demo Mode Banner (if applicable)
          SliverToBoxAdapter(
            child: Consumer<NetworkProvider>(
              builder: (context, provider, child) {
                return WiFiDemoModeBanner(
                  wifiScanningEnabled: provider.hasRequiredPermissions,
                  onTap: () async {
                    await provider.requestWiFiScanningPermissions();
                    // Refresh the scan if permissions were granted
                    if (provider.hasRequiredPermissions) {
                      await provider.startNetworkScan(forceRescan: true, isManualScan: false);
                    }
                  },
                );
              },
            ),
          ),
          
          // Map Section
          const SliverToBoxAdapter(
            child: NetworkMapWidget(),
          ),
          
          // Connection Info and Search Section
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Consumer<NetworkProvider>(
                    builder: (context, provider, child) {
                      return ConnectionInfoWidget(
                        currentNetwork: provider.currentNetwork,
                        onScanTap: () => _navigateToScan(),
                        onRefreshConnection: () => _refreshConnectionInfo(),
                        onDisconnect: () => _handleDisconnect(),
                      );
                    },
                  ),
                  
                  // Security overview (only show if security analysis is enabled and threats detected)
                  Consumer<NetworkProvider>(
                    builder: (context, provider, child) {
                      if (!provider.securityAnalysisEnabled || provider.threatsDetected == 0) {
                        return const SizedBox.shrink();
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _buildSecurityOverview(provider),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Search Bar - only show if networks exist
                  Consumer<NetworkProvider>(
                    builder: (context, provider, child) {
                      if (provider.networks.isEmpty && !provider.isLoading) {
                        return const SizedBox.shrink();
                      }
                      return TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search for Wi-Fi networks...',
                          prefixIcon: const Icon(Icons.search, color: AppColors.gray),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.lightGray),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.lightGray),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                          filled: true,
                          fillColor: AppColors.bgGray,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          context.read<NetworkProvider>().filterNetworks(value);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Nearby Networks Section with Scanning Status
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Consumer<NetworkProvider>(
                builder: (context, provider, child) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Nearby Networks',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (provider.wifiScanningEnabled) ...[
                        Icon(
                          Icons.wifi_find,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Live Scan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Demo Mode',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          
          // Network List
          Consumer<NetworkProvider>(
            builder: (context, provider, child) {
              final networks = provider.filteredNetworks.where((n) => 
                n.status != NetworkStatus.blocked && !n.isConnected
              ).toList();
              
              if (provider.isLoading && networks.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              // Show scan prompt if no scan has been performed or no networks found
              if (networks.isEmpty && !provider.isLoading && !provider.hasPerformedScan) {
                return SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenHeight = MediaQuery.of(context).size.height;
                      final isSmallScreen = screenHeight < 600;
                      final maxHeight = isSmallScreen ? 320.0 : 400.0;
                      
                      return SizedBox(
                        height: maxHeight,
                        child: _buildScanPrompt(),
                      );
                    },
                  ),
                );
              }
              
              // Show empty state if scan was performed but no networks found
              if (networks.isEmpty && !provider.isLoading && provider.hasPerformedScan) {
                return SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenHeight = MediaQuery.of(context).size.height;
                      final isSmallScreen = screenHeight < 600;
                      final maxHeight = isSmallScreen ? 320.0 : 400.0;
                      
                      return SizedBox(
                        height: maxHeight,
                        child: _buildEmptyNetworksState(),
                      );
                    },
                  ),
                );
              }
              
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final network = networks[index];
                      final provider = context.read<NetworkProvider>();
                      final securityAssessment = provider.getSecurityAssessment(network.id);
                      
                      return NetworkCard(
                        network: network,
                        onConnect: () => _handleConnect(network),
                        onReview: () => _handleReview(network),
                        onAccessPointAction: (action) => _handleAccessPointAction(network, action),
                        connectionManager: _connectionManager,
                        securityAssessment: securityAssessment,
                        showSecurityInfo: provider.securityAnalysisEnabled,
                      );
                    },
                    childCount: networks.length,
                  ),
                ),
              );
            },
          ),
          
          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConnect(NetworkModel network) async {
    if (!mounted) {
      developer.log('Widget not mounted, cannot handle connection');
      return;
    }

    try {
      developer.log('Starting connection to ${network.name}');
      
      // Show connecting snackbar immediately
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Connecting to ${network.name}...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Use the robust connection manager
      final result = await _connectionManager.connectToNetwork(
        context: context,
        network: network,
        showDialog: true,
      );

      // Handle connection result with mounted check
      if (mounted) {
        await _handleConnectionResult(result, network);
      }

    } catch (e) {
      developer.log('Exception in _handleConnect: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  Future<void> _handleConnectionResult(WiFiConnectionResult result, NetworkModel network) async {
    if (!mounted) return;

    String message = 'Unknown result';
    Color backgroundColor = Colors.grey;
    SnackBarAction? action;
    
    switch (result) {
      case WiFiConnectionResult.success:
        message = 'Successfully connected to ${network.name}';
        backgroundColor = Colors.green;
        
        // Update network provider
        try {
          final provider = context.read<NetworkProvider>();
          await provider.connectToNetwork(network.id);
          await provider.refreshCurrentConnection();
          developer.log('Network provider updated after successful connection');
        } catch (e) {
          developer.log('Error updating network provider: $e');
        }
        break;
        
      case WiFiConnectionResult.redirectedToSettings:
        message = 'Redirected to Wi-Fi settings. Find "${network.name}" to complete connection.';
        backgroundColor = AppColors.primary;
        break;
        
      case WiFiConnectionResult.failed:
        message = 'Failed to connect to ${network.name}. Please check your password and try again.';
        backgroundColor = Colors.red;
        action = SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _handleConnect(network),
        );
        break;
        
      case WiFiConnectionResult.passwordRequired:
        message = 'Password required for ${network.name}';
        backgroundColor = Colors.orange;
        action = SnackBarAction(
          label: 'Enter Password',
          textColor: Colors.white,
          onPressed: () => _handleConnect(network),
        );
        break;
        
      case WiFiConnectionResult.permissionDenied:
        message = 'Location and Wi-Fi permissions are required for network connections.';
        backgroundColor = Colors.red;
        action = SnackBarAction(
          label: 'Grant Permissions',
          textColor: Colors.white,
          onPressed: () async {
            try {
              final provider = context.read<NetworkProvider>();
              final granted = await provider.requestWiFiScanningPermissions();
              if (granted && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Permissions granted! You can now connect to networks.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              developer.log('Error requesting permissions: $e');
            }
          },
        );
        break;
        
      case WiFiConnectionResult.userCancelled:
        developer.log('User cancelled connection to ${network.name}');
        return; // Don't show message for user cancellation
        
      case WiFiConnectionResult.notSupported:
        message = 'Direct connection not supported. Use device Wi-Fi settings.';
        backgroundColor = Colors.orange;
        break;
        
      case WiFiConnectionResult.error:
        message = 'Connection error occurred. Please try again.';
        backgroundColor = Colors.red;
        action = SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _handleConnect(network),
        );
        break;
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 4),
          action: action,
        ),
      );
    }
  }

  void _handleReview(NetworkModel network) {
    // TODO: Implement review logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Network'),
        content: Text(
          'Review the security status of "${network.name}"?\n\n'
          'This will help improve our database and protect other users.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Submit review
            },
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAccessPointAction(NetworkModel network, AccessPointAction action) async {
    if (!mounted) return;
    
    final provider = context.read<NetworkProvider>();
    String actionText = '';
    Color feedbackColor = Colors.green;
    
    try {
      switch (action) {
        case AccessPointAction.block:
          await provider.blockNetwork(network.id);
          actionText = 'blocked';
          feedbackColor = Colors.red;
          break;
        case AccessPointAction.trust:
          await provider.trustNetwork(network.id);
          actionText = 'added to trusted list';
          feedbackColor = Colors.green;
          break;
        case AccessPointAction.flag:
          await provider.flagNetwork(network.id);
          actionText = 'flagged as suspicious';
          feedbackColor = Colors.orange;
          break;
        case AccessPointAction.unblock:
          await provider.unblockNetwork(network.id);
          actionText = 'unblocked';
          feedbackColor = Colors.blue;
          break;
        case AccessPointAction.untrust:
          await provider.untrustNetwork(network.id);
          actionText = 'removed from trusted list';
          feedbackColor = Colors.grey;
          break;
        case AccessPointAction.unflag:
          await provider.unflagNetwork(network.id);
          actionText = 'unflagged';
          feedbackColor = Colors.blue;
          break;
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _getActionIcon(action),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('"${network.name}" has been $actionText'),
                ),
              ],
            ),
            backgroundColor: feedbackColor,
            duration: const Duration(seconds: 3),
            action: action == AccessPointAction.block
                ? SnackBarAction(
                    label: 'Undo',
                    textColor: Colors.white,
                    onPressed: () => _handleAccessPointAction(network, AccessPointAction.unblock),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${action.name.toLowerCase()} "${network.name}": $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  IconData _getActionIcon(AccessPointAction action) {
    switch (action) {
      case AccessPointAction.trust:
        return Icons.shield;
      case AccessPointAction.flag:
        return Icons.flag;
      case AccessPointAction.block:
        return Icons.block;
      case AccessPointAction.untrust:
        return Icons.remove_circle;
      case AccessPointAction.unflag:
        return Icons.outlined_flag;
      case AccessPointAction.unblock:
        return Icons.lock_open;
    }
  }

  /// Build compact security overview widget
  Widget _buildSecurityOverview(NetworkProvider provider) {
    final safeCount = provider.safeNetworks.length;
    final riskyCount = provider.highRiskNetworks.length;
    final threatsCount = provider.threatsDetected;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: threatsCount > 0 ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: threatsCount > 0 ? Colors.red.shade200 : Colors.green.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            threatsCount > 0 ? Icons.security : Icons.verified_user,
            color: threatsCount > 0 ? Colors.red.shade700 : Colors.green.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: threatsCount > 0 ? Colors.red.shade800 : Colors.green.shade800,
                  ),
                ),
                Text(
                  '$safeCount safe • $riskyCount risky • $threatsCount threats',
                  style: TextStyle(
                    fontSize: 11,
                    color: threatsCount > 0 ? Colors.red.shade600 : Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (threatsCount > 0)
            GestureDetector(
              onTap: () => MainScreen.navigateToTab(context, 2), // Navigate to alerts
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'View Alerts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}