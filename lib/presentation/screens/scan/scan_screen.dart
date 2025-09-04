import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/network_model.dart';
import '../../../providers/network_provider.dart';
import 'widgets/scan_status_widget.dart';
import 'widgets/quick_actions_widget.dart';
import 'widgets/scan_result_item.dart' show ScanResult, ScanStatus, ScanResultItem;
import 'scan_history_screen.dart';
import '../main_screen.dart';
import '../../widgets/demo_mode_banner.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Start scanning using the centralized provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NetworkProvider>();
      if (!provider.hasPerformedScan || provider.networks.isEmpty) {
        // Auto-scan when entering the screen (not manual)
        provider.startNetworkScan(forceRescan: false, isManualScan: false);
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startScanning() {
    final provider = context.read<NetworkProvider>();
    provider.startNetworkScan(forceRescan: true, isManualScan: true);
  }

  List<ScanResult> _convertNetworksToScanResults(List<NetworkModel> networks) {
    // Blocked networks are already filtered out in NetworkProvider's filteredNetworks
    return networks.map((network) {
      ScanStatus status;
      String description;
      
      switch (network.status) {
        case NetworkStatus.verified:
        case NetworkStatus.trusted:
          status = ScanStatus.verified;
          description = network.status == NetworkStatus.trusted 
              ? 'Trusted by user' 
              : (network.description ?? 'Verified network');
          break;
        case NetworkStatus.suspicious:
          status = ScanStatus.suspicious;
          description = 'Suspicious - potential threat detected';
          break;
        case NetworkStatus.flagged:
          status = ScanStatus.suspicious;
          description = 'Flagged as suspicious by user';
          break;
        case NetworkStatus.blocked:
          // This case should never occur since blocked networks are filtered out in NetworkProvider
          status = ScanStatus.suspicious;
          description = 'Blocked network';
          break;
        default:
          status = ScanStatus.unknown;
          description = network.description ?? 'Unknown network';
      }
      
      final timeAgo = _formatTimeAgo(network.lastSeen);
      
      return ScanResult(
        networkName: network.name,
        status: status,
        description: description,
        timeAgo: timeAgo,
      );
    }).toList();
  }
  
  String _formatTimeAgo(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _stopScanning() {
    final provider = context.read<NetworkProvider>();
    provider.stopNetworkScan();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, networkProvider, child) {
        final scanResults = _convertNetworksToScanResults(networkProvider.filteredNetworks);
        final isScanning = networkProvider.isScanning;
        final scanProgress = networkProvider.scanProgress;
        final networksFound = networkProvider.totalNetworksFound;
        final verifiedNetworks = networkProvider.verifiedNetworksFound;
        final threatsDetected = networkProvider.threatsDetected;
        
        return Column(
          children: [
            // Demo mode banner
            if (!networkProvider.wifiScanningEnabled)
              const DemoModeBanner(
                customMessage: 'Demo Mode - Simulated Wi-Fi scanning for demonstration',
              ),
            
            // Main content with floating scan button
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Header section with status and scan button
                      _buildHeaderSection(
                        isScanning: isScanning,
                        scanProgress: scanProgress,
                        networksFound: networksFound,
                        threatsDetected: threatsDetected,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Statistics dashboard
                      _buildStatsDashboard(
                        networksFound: networksFound,
                        verifiedNetworks: verifiedNetworks,
                        threatsDetected: threatsDetected,
                        scanProgress: scanProgress,
                        isScanning: isScanning,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Quick actions
                      QuickActionsWidget(
                        onViewAll: () => _navigateToHome(),
                        onViewAlerts: () => _navigateToAlerts(),
                        onViewHistory: () => _showScanHistory(),
                        networksCount: networksFound,
                        alertsCount: threatsDetected,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Evil twin detection summary
                      if (!isScanning && networksFound > 0) ...[
                        _buildEvilTwinSummary(networkProvider.networks),
                        const SizedBox(height: 16),
                      ],
                      
                      // Recent findings (limited to 3 items to keep it concise)
                      if (scanResults.isNotEmpty) ...[
                        _buildRecentFindings(scanResults.take(3).toList()),
                        const SizedBox(height: 16),
                      ],
                      
                      // Last scan info
                      if (networkProvider.lastScanTime != null && !isScanning)
                        _buildLastScanInfo(networkProvider.lastScanTime!),
                      
                      const SizedBox(height: 80), // Space for floating button
                    ],
                  ),
                ),
              ),
            ),
            
            // Floating scan button at bottom
            _buildFloatingScanButton(isScanning, threatsDetected),
          ],
        );
      },
    );
  }
  
  void _navigateToAlerts() {
    // Navigate directly to the Alerts tab (index 2)
    MainScreen.navigateToTab(context, 2);
    
    // Show a brief confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Viewing security alerts'),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _navigateToHome() {
    // Navigate to Home tab to view all networks
    MainScreen.navigateToTab(context, 0);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Viewing all detected networks'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  void _showScanHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScanHistoryScreen(),
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildEvilTwinSummary(List<NetworkModel> networks) {
    final duplicateNetworks = _findDuplicateSSIDs(networks);
    
    if (duplicateNetworks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.security, color: Colors.green[600], size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No duplicate SSIDs detected - Evil twin risk low',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[600], size: 16),
              const SizedBox(width: 8),
              Text(
                'Potential Evil Twins Detected',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...duplicateNetworks.map((group) => Text(
            '• ${group.length} networks named "${group.first}"',
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange[600],
            ),
          )),
        ],
      ),
    );
  }
  
  List<List<String>> _findDuplicateSSIDs(List<NetworkModel> networks) {
    final ssidMap = <String, List<String>>{};
    
    for (final network in networks) {
      final normalizedSSID = network.name.toLowerCase().trim();
      if (normalizedSSID.isNotEmpty) {
        ssidMap.putIfAbsent(normalizedSSID, () => []).add(network.name);
      }
    }
    
    // Return groups with more than one network
    return ssidMap.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => entry.value.toSet().toList())
        .toList();
  }
  
  Widget _buildHeaderSection({
    required bool isScanning,
    required double scanProgress,
    required int networksFound,
    required int threatsDetected,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Status widget
          ScanStatusWidget(
            isScanning: isScanning,
            progress: scanProgress,
            networksFound: networksFound,
            threatsDetected: threatsDetected,
          ),
          
          const SizedBox(width: 20),
          
          // Info section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isScanning ? 'Scanning Networks' : 'Scan Status',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isScanning
                      ? 'Detecting nearby Wi-Fi networks and analyzing security threats'
                      : networksFound > 0
                          ? 'Found $networksFound networks${threatsDetected > 0 ? ', $threatsDetected threats detected' : ''}'
                          : 'Tap the scan button below to start scanning',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                if (isScanning) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${(scanProgress * 100).toInt()}% Complete',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDashboard({
    required int networksFound,
    required int verifiedNetworks,
    required int threatsDetected,
    required double scanProgress,
    required bool isScanning,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Networks Found',
            '$networksFound',
            Icons.wifi,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Verified',
            '$verifiedNetworks',
            Icons.verified,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Threats',
            '$threatsDetected',
            Icons.warning,
            threatsDetected > 0 ? Colors.red : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentFindings(List<ScanResult> scanResults) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Findings',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              if (scanResults.length >= 3)
                GestureDetector(
                  onTap: _navigateToHome,
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...scanResults.map((result) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ScanResultItem(result: result),
          )),
        ],
      ),
    );
  }

  Widget _buildLastScanInfo(DateTime lastScanTime) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Last scan: ${_formatScanTime(lastScanTime)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingScanButton(bool isScanning, int threatsDetected) {
    return Container(
      margin: const EdgeInsets.all(0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Main scan button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: isScanning ? _stopScanning : _startScanning,
                icon: Icon(
                  isScanning ? Icons.stop : Icons.play_arrow,
                  size: 24,
                ),
                label: Text(
                  isScanning ? 'Stop Scan' : 'Start Scan',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isScanning 
                      ? Colors.red 
                      : (threatsDetected > 0 ? Colors.orange : AppColors.primary),
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            
            // Quick action button (alerts or view all)
            if (threatsDetected > 0 && !isScanning) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _navigateToAlerts,
                  icon: const Icon(Icons.warning, size: 20),
                  label: const Text('Alerts'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      side: BorderSide(color: Colors.red[300]!),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ] else if (!isScanning && threatsDetected == 0) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _navigateToHome,
                  icon: const Icon(Icons.list, size: 20),
                  label: const Text('View All'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatScanTime(DateTime scanTime) {
    final now = DateTime.now();
    final difference = now.difference(scanTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m ago';
    } else {
      return '${scanTime.day}/${scanTime.month} ${scanTime.hour}:${scanTime.minute.toString().padLeft(2, '0')}';
    }
  }
}