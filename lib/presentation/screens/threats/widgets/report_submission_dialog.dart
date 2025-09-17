import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/threat_report_model.dart';
import '../../../../data/models/scan_history_model.dart';
import '../../../../data/services/threat_reporting_service.dart';

class ReportSubmissionDialog extends StatefulWidget {
  final ThreatAlert alert;
  final ScanHistoryEntry scanContext;
  final String? userNotes;
  final ThreatReportingService reportingService;
  final Function(ThreatReportResult) onSubmissionComplete;
  
  const ReportSubmissionDialog({
    super.key,
    required this.alert,
    required this.scanContext,
    this.userNotes,
    required this.reportingService,
    required this.onSubmissionComplete,
  });

  @override
  State<ReportSubmissionDialog> createState() => _ReportSubmissionDialogState();
}

class _ReportSubmissionDialogState extends State<ReportSubmissionDialog>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late AnimationController _progressController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;
  
  SubmissionState _state = SubmissionState.preparing;
  String? _reportId;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _startSubmission();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _progressController.dispose();
    super.dispose();
  }
  
  Future<void> _startSubmission() async {
    // Start progress animation
    _progressController.forward();
    
    try {
      await Future.delayed(const Duration(seconds: 1)); // Show progress animation
      
      setState(() {
        _state = SubmissionState.submitting;
      });
      
      // Submit the threat report
      final reportId = await widget.reportingService.submitThreatReport(
        alert: widget.alert,
        scanContext: widget.scanContext,
        userNotes: widget.userNotes,
        reportReason: 'app_suggested',
      );
      
      setState(() {
        _state = SubmissionState.success;
        _reportId = reportId;
      });
      
      // Wait a moment before closing
      await Future.delayed(const Duration(seconds: 2));
      widget.onSubmissionComplete(ThreatReportResult.success(reportId));
      
    } catch (e) {
      setState(() {
        _state = SubmissionState.error;
        _errorMessage = e.toString();
      });
      
      // Wait a moment before allowing user action
      await Future.delayed(const Duration(seconds: 1));
      widget.onSubmissionComplete(ThreatReportResult.failure(_errorMessage!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state == SubmissionState.error,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 350),
                child: _buildContent(),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildContent() {
    switch (_state) {
      case SubmissionState.preparing:
        return _buildPreparingView();
      case SubmissionState.submitting:
        return _buildSubmittingView();
      case SubmissionState.success:
        return _buildSuccessView();
      case SubmissionState.error:
        return _buildErrorView();
    }
  }
  
  Widget _buildPreparingView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _progressAnimation.value,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const Icon(
                    Icons.description,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Preparing Report',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gathering scan data and location information...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSubmittingView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                ),
              ),
              Icon(
                Icons.cloud_upload,
                size: 32,
                color: Colors.orange.shade600,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Submitting Report',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sending threat report to security team...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 48,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Report Submitted Successfully!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Thank you for helping secure our network infrastructure.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (_reportId != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Report ID:',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _reportId!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error,
              size: 48,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Submission Failed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Unable to submit threat report. Please check your connection and try again.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade800,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    widget.onSubmissionComplete(
                      ThreatReportResult.failure(_errorMessage ?? 'Unknown error'),
                    );
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _state = SubmissionState.preparing;
                      _errorMessage = null;
                    });
                    _progressController.reset();
                    _startSubmission();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum SubmissionState {
  preparing,
  submitting,
  success,
  error,
}