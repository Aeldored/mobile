import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/threat_report_model.dart';
import '../../../data/models/scan_history_model.dart';
import '../../../data/models/network_model.dart';
import '../../../data/models/security_assessment.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/services/threat_reporting_service.dart';
import '../../../data/services/scan_history_service.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/demo_mode_banner.dart';
import 'widgets/threat_confirmation_dialog.dart';
import 'widgets/report_submission_dialog.dart';
import 'widgets/threat_evidence_widget.dart';

class ThreatReportScreen extends StatefulWidget {
  final ThreatAlert alert;
  
  const ThreatReportScreen({
    super.key,
    required this.alert,
  });

  @override
  State<ThreatReportScreen> createState() => _ThreatReportScreenState();
}

class _ThreatReportScreenState extends State<ThreatReportScreen> {
  final ThreatReportingService _reportingService = ThreatReportingService();
  final ScanHistoryService _scanHistoryService = ScanHistoryService();
  
  ScanHistoryEntry? _scanContext;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadScanContext();
  }

  Future<void> _loadScanContext() async {
    try {
      final scanHistory = _scanHistoryService.history;
      final scanContext = scanHistory.firstWhere(
        (scan) => scan.id == widget.alert.scanHistoryId,
        orElse: () => scanHistory.isNotEmpty ? scanHistory.first : _createDefaultScanContext(),
      );
      
      setState(() {
        _scanContext = scanContext;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load scan context: $e';
        _isLoading = false;
      });
    }
  }
  
  ScanHistoryEntry _createDefaultScanContext() {
    return ScanHistoryEntry(
      id: 'default_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      scanType: ScanType.manual,
      scanDuration: const Duration(seconds: 30),
      networksFound: 1,
      verifiedNetworks: 0,
      suspiciousNetworks: 1,
      threatsDetected: 1,
      networkSummaries: [
        NetworkSummary.fromNetworkModel(
          widget.alert.suspiciousNetwork ?? _createDefaultNetwork(),
        ),
      ],
      location: widget.alert.location,
      wasSuccessful: true,
    );
  }
  
  NetworkModel _createDefaultNetwork() {
    return NetworkModel(
      id: 'default_network',
      name: widget.alert.networkName ?? 'Unknown Network',
      description: widget.alert.message,
      status: NetworkStatus.suspicious,
      securityType: SecurityType.open,
      signalStrength: 50,
      macAddress: widget.alert.macAddress ?? 'unknown',
      lastSeen: DateTime.now(),
      isConnected: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Report Security Threat',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
          ? const LoadingSpinner(message: 'Loading scan data...')
          : _error != null
              ? _buildErrorView()
              : _buildReportView(),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load Report Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReportView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DemoModeBanner(),
          const SizedBox(height: 16),
          _buildThreatSummaryCard(),
          const SizedBox(height: 16),
          if (widget.alert.suspiciousNetwork != null)
            ThreatEvidenceWidget(
              alert: widget.alert,
              scanContext: _scanContext!,
            ),
          const SizedBox(height: 16),
          _buildLocationCard(),
          const SizedBox(height: 16),
          _buildScanContextCard(),
          const SizedBox(height: 24),
          _buildActionButtons(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  Widget _buildThreatSummaryCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(widget.alert.severity).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getThreatIcon(widget.alert.type),
                    color: _getSeverityColor(widget.alert.severity),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.alert.threatTypeDisplayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getSeverityColor(widget.alert.severity),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.alert.severity.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.alert.message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (widget.alert.confidenceScore != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Confidence Level: ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${(widget.alert.confidenceScore! * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Detection Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.alert.location ?? 'Location not available',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScanContextCard() {
    if (_scanContext == null) return const SizedBox.shrink();
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.radar,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Scan Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildScanStatRow('Networks Found', _scanContext!.networksFound.toString()),
            _buildScanStatRow('Scan Duration', _scanContext!.formattedDuration),
            _buildScanStatRow('Threats Detected', _scanContext!.threatsDetected.toString()),
            _buildScanStatRow('Scan Type', _scanContext!.scanTypeDisplayName),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScanStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.alert.isSuitableForReporting ? _showReportConfirmation : null,
            icon: const Icon(Icons.report_problem),
            label: const Text(
              'Report This Threat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.alert.isSuitableForReporting 
                  ? Colors.red.shade600 
                  : Colors.grey.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: const Text('Not Now'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
  
  void _showReportConfirmation() {
    if (_scanContext == null) return;
    
    showDialog(
      context: context,
      builder: (context) => ThreatConfirmationDialog(
        alert: widget.alert,
        scanContext: _scanContext!,
        onConfirm: _handleReportConfirmation,
      ),
    );
  }
  
  void _handleReportConfirmation(String? userNotes) {
    if (_scanContext == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReportSubmissionDialog(
        alert: widget.alert,
        scanContext: _scanContext!,
        userNotes: userNotes,
        reportingService: _reportingService,
        onSubmissionComplete: _handleSubmissionComplete,
      ),
    );
  }
  
  void _handleSubmissionComplete(ThreatReportResult result) {
    Navigator.of(context).pop(); // Close submission dialog
    
    if (result.success) {
      // Show success message and return to previous screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Threat report submitted successfully! Report ID: ${result.reportId}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.of(context).pop();
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: ${result.errorMessage}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
  
  IconData _getThreatIcon(AlertType type) {
    switch (type) {
      case AlertType.evilTwin:
        return Icons.content_copy;
      case AlertType.suspiciousNetwork:
        return Icons.warning;
      case AlertType.networkBlocked:
        return Icons.block;
      default:
        return Icons.security;
    }
  }
  
  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Colors.red.shade700;
      case AlertSeverity.high:
        return Colors.orange.shade600;
      case AlertSeverity.medium:
        return Colors.yellow.shade700;
      case AlertSeverity.low:
        return Colors.blue.shade600;
    }
  }
}