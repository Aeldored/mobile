import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/threat_report_model.dart';
import '../../../../data/models/scan_history_model.dart';
import '../../../../data/models/alert_model.dart';

class ThreatConfirmationDialog extends StatefulWidget {
  final ThreatAlert alert;
  final ScanHistoryEntry scanContext;
  final Function(String? userNotes) onConfirm;
  
  const ThreatConfirmationDialog({
    super.key,
    required this.alert,
    required this.scanContext,
    required this.onConfirm,
  });

  @override
  State<ThreatConfirmationDialog> createState() => _ThreatConfirmationDialogState();
}

class _ThreatConfirmationDialogState extends State<ThreatConfirmationDialog> {
  final TextEditingController _notesController = TextEditingController();
  bool _includeNotes = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildContent(),
            _buildActions(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getSeverityColor(widget.alert.severity),
            _getSeverityColor(widget.alert.severity).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.report_problem,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          const Text(
            'Report Security Threat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Help protect our network infrastructure',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildThreatSummary(),
          const SizedBox(height: 20),
          _buildWhatHappensNext(),
          const SizedBox(height: 20),
          _buildNotesSection(),
        ],
      ),
    );
  }
  
  Widget _buildThreatSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getSeverityColor(widget.alert.severity).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getThreatIcon(widget.alert.type),
                  color: _getSeverityColor(widget.alert.severity),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.alert.threatTypeDisplayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.alert.severity.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getSeverityColor(widget.alert.severity),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Network: ${widget.alert.networkName ?? 'Unknown'}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.alert.location != null) ...[
            const SizedBox(height: 4),
            Text(
              'Location: ${widget.alert.location}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (widget.alert.confidenceScore != null) ...[
            const SizedBox(height: 4),
            Text(
              'Confidence: ${(widget.alert.confidenceScore! * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildWhatHappensNext() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What happens next?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildStepItem(
          icon: Icons.send,
          title: 'Report Submitted',
          description: 'Your threat report will be sent to the security team',
        ),
        _buildStepItem(
          icon: Icons.security,
          title: 'Investigation Begins',
          description: 'Security experts will analyze the threat',
        ),
        _buildStepItem(
          icon: Icons.verified_user,
          title: 'Action Taken',
          description: 'Appropriate security measures will be implemented',
        ),
      ],
    );
  }
  
  Widget _buildStepItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppColors.primary,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _includeNotes,
              onChanged: (value) {
                setState(() {
                  _includeNotes = value ?? false;
                  if (!_includeNotes) {
                    _notesController.clear();
                  }
                });
              },
              activeColor: AppColors.primary,
            ),
            const Text(
              'Add additional information (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (_includeNotes) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe what you observed or any additional context...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _getSeverityColor(widget.alert.severity),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Report Threat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _handleConfirm() {
    Navigator.of(context).pop();
    widget.onConfirm(
      _includeNotes && _notesController.text.isNotEmpty 
          ? _notesController.text.trim() 
          : null
    );
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
        return Colors.red.shade600;
      case AlertSeverity.high:
        return Colors.orange.shade600;
      case AlertSeverity.medium:
        return Colors.yellow.shade700;
      case AlertSeverity.low:
        return Colors.blue.shade600;
    }
  }
}