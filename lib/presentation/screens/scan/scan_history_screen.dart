import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/scan_history_model.dart';
import '../../../data/models/network_model.dart';
import '../../../providers/network_provider.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ScanType? _filterType;
  int _selectedTimeRange = 7; // Last 7 days
  bool _isSearchVisible = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    const scrollThreshold = 80.0;
    final shouldHide = _scrollController.offset > scrollThreshold;
    
    if (shouldHide != !_isSearchVisible) {
      setState(() {
        _isSearchVisible = !shouldHide;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Scan History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 8),
        child: FloatingActionButton(
          onPressed: _showHistorySettings,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 6,
          child: const Icon(Icons.settings),
        ),
      ),
      body: Column(
        children: [
          // Subtitle header
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: const Text(
              'View your network scanning activity',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          
          // Search and filter bar with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isSearchVisible ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isSearchVisible ? 1.0 : 0.0,
              child: _buildSearchAndFilterBar(),
            ),
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
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: AppColors.primary,
              dividerColor: Colors.transparent, // Remove divider line
              tabs: const [
                Tab(text: 'Recent', icon: Icon(Icons.access_time, size: 20)),
                Tab(text: 'Statistics', icon: Icon(Icons.analytics, size: 20)),
                Tab(text: 'Details', icon: Icon(Icons.list_alt, size: 20)),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: Consumer<NetworkProvider>(
              builder: (context, networkProvider, child) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRecentTab(networkProvider),
                    _buildStatisticsTab(networkProvider),
                    _buildDetailsTab(networkProvider),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search by network name...',
              prefixIcon: const Icon(Icons.search, color: AppColors.gray),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.gray),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Last 24h', _selectedTimeRange == 1, () => setState(() => _selectedTimeRange = 1)),
                const SizedBox(width: 8),
                _buildFilterChip('Last 7 days', _selectedTimeRange == 7, () => setState(() => _selectedTimeRange = 7)),
                const SizedBox(width: 8),
                _buildFilterChip('Last 30 days', _selectedTimeRange == 30, () => setState(() => _selectedTimeRange = 30)),
                const SizedBox(width: 8),
                _buildFilterChip('Manual', _filterType == ScanType.manual, () => setState(() => _filterType = _filterType == ScanType.manual ? null : ScanType.manual)),
                const SizedBox(width: 8),
                _buildFilterChip('Background', _filterType == ScanType.background, () => setState(() => _filterType = _filterType == ScanType.background ? null : ScanType.background)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildRecentTab(NetworkProvider networkProvider) {
    final filteredHistory = _getFilteredHistory(networkProvider.scanHistory);
    
    if (filteredHistory.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Trigger a refresh of the provider data
        // The history is automatically updated when new scans complete
      },
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: filteredHistory.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = filteredHistory[index];
          return _buildHistoryCard(entry);
        },
      ),
    );
  }

  Widget _buildStatisticsTab(NetworkProvider networkProvider) {
    final stats = networkProvider.scanHistoryService.getOverallStats();
    
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview cards
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Scans', '${stats.totalScans}', Icons.search, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Networks Found', '${stats.totalNetworksFound}', Icons.wifi, Colors.green)),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _buildStatCard('Threats Detected', '${stats.totalThreatsDetected}', Icons.warning, Colors.red)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Success Rate', stats.formattedSuccessRate, Icons.check_circle, Colors.green)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Detailed statistics
          _buildStatisticsSection(networkProvider),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(NetworkProvider networkProvider) {
    final filteredHistory = _getFilteredHistory(networkProvider.scanHistory);
    
    if (filteredHistory.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: filteredHistory.length,
      itemBuilder: (context, index) {
        final entry = filteredHistory[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Icon(entry.scanTypeIcon, color: entry.scanTypeColor),
            title: Text('${entry.scanTypeDisplayName} - ${DateFormat('MMM dd, HH:mm').format(entry.timestamp)}'),
            subtitle: Text('${entry.networksFound} networks • ${entry.formattedDuration} • ${entry.threatsDetected} threats'),
            children: [
              if (entry.networkSummaries.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Networks Detected:', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...entry.networkSummaries.take(10).map((network) => _buildNetworkSummaryItem(network)),
                      if (entry.networkSummaries.length > 10)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('... and ${entry.networkSummaries.length - 10} more networks', 
                            style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(ScanHistoryEntry entry) {
    return Card(
      elevation: 2,
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
                    color: entry.scanTypeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(entry.scanTypeIcon, color: entry.scanTypeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.scanTypeDisplayName, 
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(DateFormat('MMM dd, yyyy • HH:mm:ss').format(entry.timestamp),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    ],
                  ),
                ),
                if (!entry.wasSuccessful)
                  Icon(Icons.error, color: Colors.red[600], size: 20),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Statistics
            Row(
              children: [
                _buildMiniStat(Icons.wifi, '${entry.networksFound}', 'Networks'),
                const SizedBox(width: 24),
                _buildMiniStat(Icons.verified, '${entry.verifiedNetworks}', 'Verified'),
                const SizedBox(width: 24),
                _buildMiniStat(Icons.warning, '${entry.threatsDetected}', 'Threats'),
                const Spacer(),
                Text(entry.formattedDuration, 
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
              ],
            ),
            
            if (!entry.wasSuccessful && entry.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[600], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error: ${entry.errorMessage}',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(NetworkProvider networkProvider) {
    final stats = networkProvider.scanHistoryService.getOverallStats();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detailed Statistics', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatRow('Average Scan Duration', stats.formattedAverageDuration),
                const Divider(),
                _buildStatRow('Total Verified Networks', '${stats.totalVerifiedNetworks}'),
                const Divider(),
                _buildStatRow('Most Common Scan Type', stats.mostCommonScanType?.name.toUpperCase() ?? 'N/A'),
                const Divider(),
                _buildStatRow('Success Rate', stats.formattedSuccessRate),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNetworkSummaryItem(NetworkSummary network) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            _getNetworkStatusIcon(network.status),
            color: _getNetworkStatusColor(network.status),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              network.ssid,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${network.signalStrength}%',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No scan history yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Start scanning for networks to see your history here', 
            style: TextStyle(color: Colors.grey[500]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  List<ScanHistoryEntry> _getFilteredHistory(List<ScanHistoryEntry> history) {
    var filtered = history;
    
    // Filter by time range
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: _selectedTimeRange));
    filtered = filtered.where((entry) => entry.timestamp.isAfter(cutoff)).toList();
    
    // Filter by scan type
    if (_filterType != null) {
      filtered = filtered.where((entry) => entry.scanType == _filterType).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((entry) {
        return entry.networkSummaries.any((network) =>
            network.ssid.toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }
    
    return filtered;
  }

  IconData _getNetworkStatusIcon(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.verified:
        return Icons.verified;
      case NetworkStatus.trusted:
        return Icons.shield;
      case NetworkStatus.suspicious:
        return Icons.warning;
      case NetworkStatus.blocked:
        return Icons.block;
      default:
        return Icons.wifi;
    }
  }

  Color _getNetworkStatusColor(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.verified:
        return Colors.green;
      case NetworkStatus.trusted:
        return Colors.blue;
      case NetworkStatus.suspicious:
        return Colors.orange;
      case NetworkStatus.blocked:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showHistorySettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _HistorySettingsBottomSheet(
        onShowExportOptions: () => _showExportOptions(context),
        onClearHistory: () async {
          final networkProvider = context.read<NetworkProvider>();
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          
          try {
            navigator.pop(); // Close the bottom sheet first
            
            // Show loading indicator
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 16),
                    Text('Clearing scan history...'),
                  ],
                ),
                duration: Duration(milliseconds: 800),
              ),
            );
            
            await networkProvider.clearScanHistory();
            
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Scan history cleared successfully'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
          } catch (e) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Failed to clear history: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    final networkProvider = context.read<NetworkProvider>();
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            Text('Export Format', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            
            ListTile(
              leading: const Icon(Icons.summarize, color: AppColors.primary),
              title: const Text('Summary Report'),
              subtitle: const Text('Human-readable analysis with security recommendations'),
              onTap: () {
                Navigator.pop(context);
                networkProvider.scanHistory.isNotEmpty
                    ? _exportHistory('summary', networkProvider)
                    : _showNoDataError();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('CSV Spreadsheet'),
              subtitle: const Text('Open in Excel, Google Sheets, or other spreadsheet apps'),
              onTap: () {
                Navigator.pop(context);
                networkProvider.scanHistory.isNotEmpty
                    ? _exportHistory('csv', networkProvider)
                    : _showNoDataError();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.code, color: Colors.blue),
              title: const Text('JSON Data'),
              subtitle: const Text('Raw data for developers and advanced users'),
              onTap: () {
                Navigator.pop(context);
                networkProvider.scanHistory.isNotEmpty
                    ? _exportHistory('json', networkProvider)
                    : _showNoDataError();
              },
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _exportHistory(String format, NetworkProvider networkProvider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      String exportData;
      String fileName;
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      
      switch (format.toLowerCase()) {
        case 'csv':
          exportData = networkProvider.scanHistoryService.exportHistoryAsCsv();
          fileName = 'disconx_scan_history_$timestamp.csv';
          break;
        case 'summary':
          exportData = networkProvider.scanHistoryService.exportSummaryReport();
          fileName = 'disconx_scan_summary_$timestamp.txt';
          break;
        default: // json
          exportData = networkProvider.scanHistoryService.exportHistoryAsJson();
          fileName = 'disconx_scan_history_$timestamp.json';
          break;
      }
      
      if (exportData.isEmpty) {
        throw Exception('No scan history data to export');
      }

      // Try file sharing first, fallback to dialog on error
      try {
        await _shareAsFile(exportData, fileName, format);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Scan history exported successfully as ${format.toUpperCase()}'),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (shareError) {
        // Fallback to showing data in dialog
        _showExportDialog(exportData, fileName, format);
      }
      
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to export history: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _shareAsFile(String data, String fileName, String format) async {
    // Get temporary directory and write file
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(data);
    
    // Verify file was created
    if (!await file.exists()) {
      throw Exception('Failed to create export file');
    }
    
    // Share the file
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'DisConX Scan History Export (${format.toUpperCase()}) - ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
      subject: 'DisConX Scan History',
    );
  }

  void _showExportDialog(String data, String fileName, String format) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.file_download, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Export ${format.toUpperCase()}'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File sharing is not available. Here\'s your data:',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Filename: $fileName',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      data,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: data));
              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Data copied to clipboard'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Copy to Clipboard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNoDataError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No scan history data to export'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history, color: AppColors.primary),
            SizedBox(width: 8),
            Text('About Scan History'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan History automatically saves all your network scans for easy reference and analysis.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 16),
              
              const Text('How it works:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('• Every network scan is automatically saved'),
              const Text('• View detailed network information and security status'),
              const Text('• Track network changes over time'),
              const Text('• Export scan data for external analysis'),
              
              const SizedBox(height: 16),
              
              const Text('Tabs Overview:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('• Recent: Latest scan sessions'),
              const Text('• Statistics: Overall network metrics'),
              const Text('• Details: All discovered networks'),
              
              const SizedBox(height: 16),
              
              const Text('Network Information:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.wifi, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text('Signal Strength: -30 to -90 dBm'),
                ],
              ),
              const Row(
                children: [
                  Icon(Icons.security, color: Colors.blue, size: 16),
                  SizedBox(width: 4),
                  Text('Security: WPA2/3, WEP, Open'),
                ],
              ),
              const Row(
                children: [
                  Icon(Icons.speed, color: Colors.orange, size: 16),
                  SizedBox(width: 4),
                  Text('Frequency: 2.4GHz, 5GHz bands'),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates, color: AppColors.primary, size: 16),
                        SizedBox(width: 4),
                        Text('Features:', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text('• Search through scan history'),
                    Text('• Filter by time periods'),
                    Text('• Export data as JSON/CSV'),
                    Text('• Clear old scan data'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _HistorySettingsBottomSheet extends StatelessWidget {
  final VoidCallback onClearHistory;
  final VoidCallback onShowExportOptions;

  const _HistorySettingsBottomSheet({
    required this.onClearHistory,
    required this.onShowExportOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          Text('History Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          
          ListTile(
            leading: const Icon(Icons.file_download, color: AppColors.primary),
            title: const Text('Export History'),
            subtitle: const Text('Choose export format'),
            onTap: () {
              Navigator.pop(context);
              onShowExportOptions();
            },
          ),
          
          ListTile(
            leading: Icon(Icons.delete, color: Colors.red[600]),
            title: Text('Clear History', style: TextStyle(color: Colors.red[700])),
            subtitle: const Text('Delete all scan history data'),
            onTap: () => _showClearConfirmation(context),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Scan History'),
        content: const Text('Are you sure you want to delete all scan history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              onClearHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear History'),
          ),
        ],
      ),
    );
  }
}