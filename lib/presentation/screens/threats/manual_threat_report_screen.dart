import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/models/threat_report_model.dart';
import '../../../data/models/scan_history_model.dart';
import '../../../data/models/network_model.dart';
import '../../../data/models/security_assessment.dart';
import '../../../data/services/threat_reporting_service.dart';
import 'widgets/threat_type_helper.dart';

class ManualThreatReportScreen extends StatefulWidget {
  final NetworkModel? prefilledNetwork;
  final AlertModel? sourceAlert;
  final String? suggestedThreatType;
  final String? suggestedDescription;
  
  const ManualThreatReportScreen({
    super.key,
    this.prefilledNetwork,
    this.sourceAlert,
    this.suggestedThreatType,
    this.suggestedDescription,
  });

  @override
  State<ManualThreatReportScreen> createState() => _ManualThreatReportScreenState();
}

class _ManualThreatReportScreenState extends State<ManualThreatReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _networkNameController = TextEditingController();
  final _macAddressController = TextEditingController();
  final _locationController = TextEditingController();
  final _additionalNotesController = TextEditingController();
  
  AlertType _selectedThreatType = AlertType.suspiciousNetwork;
  AlertSeverity _selectedSeverity = AlertSeverity.medium;
  bool _isSubmitting = false;
  Position? _currentPosition;
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _prefillFromProvidedData();
  }
  
  void _prefillFromProvidedData() {
    if (widget.prefilledNetwork != null) {
      final network = widget.prefilledNetwork!;
      
      // Pre-fill network details
      _networkNameController.text = network.name;
      _macAddressController.text = network.macAddress;
      
      // Set location if available
      if (network.latitude != null && network.longitude != null) {
        _locationController.text = '${network.latitude!.toStringAsFixed(6)}, ${network.longitude!.toStringAsFixed(6)}';
      } else if (network.displayLocation != 'Unknown location') {
        _locationController.text = network.displayLocation;
      }
      
      // Set threat type based on network status
      if (network.status == NetworkStatus.suspicious) {
        _selectedThreatType = AlertType.suspiciousNetwork;
        _selectedSeverity = AlertSeverity.high;
      }
    }
    
    if (widget.sourceAlert != null) {
      final alert = widget.sourceAlert!;
      
      // Use alert title as report title
      _titleController.text = alert.title.replaceAll(' - Report Recommended', '').replaceAll('Report Suggestion: ', '');
      
      // Extract threat description from alert message
      final alertMessage = alert.message;
      if (alertMessage.contains('Threat Details:')) {
        final threatStart = alertMessage.indexOf('Threat Details:') + 'Threat Details:'.length;
        final threatEnd = alertMessage.indexOf('Tap the "Report Threat"');
        if (threatEnd > threatStart) {
          final threatDetails = alertMessage.substring(threatStart, threatEnd).trim();
          _descriptionController.text = threatDetails.replaceAll('•', '-');
        }
      }
      
      // Set severity based on alert severity
      _selectedSeverity = alert.severity;
      _selectedThreatType = alert.type == AlertType.reportSuggestion ? AlertType.suspiciousNetwork : alert.type;
    }
    
    if (widget.suggestedThreatType != null) {
      _titleController.text = widget.suggestedThreatType!;
    }
    
    if (widget.suggestedDescription != null && _descriptionController.text.isEmpty) {
      _descriptionController.text = widget.suggestedDescription!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _networkNameController.dispose();
    _macAddressController.dispose();
    _locationController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        _locationController.text = 'GPS: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}';
      }
    } catch (e) {
      if (mounted) {
        _locationController.text = 'Location unavailable';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Report Security Threat'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important Notice',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[800],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This report will be sent to DICT-CALABARZON for investigation. Only report genuine security threats.',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Threat Type Selection
              const Text(
                'Threat Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.lightGray),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AlertType>(
                    value: _selectedThreatType,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: AlertType.suspiciousNetwork,
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange[600], size: 20),
                            const SizedBox(width: 8),
                            const Text('Suspicious Network'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: AlertType.evilTwin,
                        child: Row(
                          children: [
                            Icon(Icons.content_copy, color: Colors.red[600], size: 20),
                            const SizedBox(width: 8),
                            const Text('Evil Twin Network'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: AlertType.networkBlocked,
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            const Text('Malicious Network'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: AlertType.critical,
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red[800], size: 20),
                            const SizedBox(width: 8),
                            const Text('Critical Security Issue'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedThreatType = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Threat Type Helper
              const ThreatTypeHelper(),
              
              const SizedBox(height: 16),
              
              // Severity Selection
              const Text(
                'Severity Level',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: AlertSeverity.values.map((severity) {
                  final isSelected = _selectedSeverity == severity;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSeverity = severity;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? _getSeverityColor(severity) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? _getSeverityColor(severity) : AppColors.lightGray,
                          ),
                        ),
                        child: Text(
                          severity.name.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Threat Title*',
                  hintText: 'Brief description of the threat',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Detailed Description*',
                  hintText: 'Describe what you observed and why it seems suspicious',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a detailed description';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Network Information Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.wifi,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Network Information (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Network Name
                    TextFormField(
                      controller: _networkNameController,
                      decoration: InputDecoration(
                        labelText: 'Network Name (SSID)',
                        hintText: 'e.g. FREE_WIFI, MyNetwork',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.network_wifi),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // MAC Address
                    TextFormField(
                      controller: _macAddressController,
                      decoration: InputDecoration(
                        labelText: 'MAC Address (BSSID)',
                        hintText: 'e.g. AA:BB:CC:DD:EE:FF',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.device_hub),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Location Field
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  hintText: 'Where did you observe this threat?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: _getCurrentLocation,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Additional Notes
              TextFormField(
                controller: _additionalNotesController,
                decoration: InputDecoration(
                  labelText: 'Additional Notes',
                  hintText: 'Any additional information that might be helpful',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.note_add),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: 32),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitThreatReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Submitting Report...'),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Submit Threat Report',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Disclaimer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'By submitting this report, you confirm that the information provided is accurate to the best of your knowledge. False reports may result in restricted access to this feature.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitThreatReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create a manual threat alert
      final manualAlert = ThreatAlert(
        id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        type: _selectedThreatType,
        title: _titleController.text.trim(),
        message: _descriptionController.text.trim(),
        severity: _selectedSeverity,
        timestamp: DateTime.now(),
        scanHistoryId: 'manual_report',
        networkName: _networkNameController.text.trim().isNotEmpty 
            ? _networkNameController.text.trim() 
            : null,
        macAddress: _macAddressController.text.trim().isNotEmpty 
            ? _macAddressController.text.trim() 
            : null,
        location: _locationController.text.trim().isNotEmpty 
            ? _locationController.text.trim() 
            : null,
        confidenceScore: 1.0, // Manual reports have full confidence
        threatIndicators: ['user_reported'],
        canReport: true,
        reportSuggestion: 'User-initiated manual threat report',
        suspiciousNetwork: _networkNameController.text.trim().isNotEmpty
            ? NetworkModel(
                id: 'manual_network',
                name: _networkNameController.text.trim(),
                status: NetworkStatus.suspicious,
                securityType: SecurityType.open,
                signalStrength: 0,
                macAddress: _macAddressController.text.trim().isNotEmpty 
                    ? _macAddressController.text.trim() 
                    : 'unknown',
                lastSeen: DateTime.now(),
              )
            : null,
        legitimateNetwork: null,
        contextNetworks: [],
      );

      // Create a minimal scan context for manual reports
      final networkSummaries = <NetworkSummary>[];
      if (_networkNameController.text.trim().isNotEmpty) {
        networkSummaries.add(NetworkSummary(
          ssid: _networkNameController.text.trim(),
          status: NetworkStatus.suspicious,
          securityType: 'Unknown',
          signalStrength: 0,
          isCurrentNetwork: false,
          macAddress: _macAddressController.text.trim().isNotEmpty 
              ? _macAddressController.text.trim() 
              : null,
        ));
      }
      
      final scanContext = ScanHistoryEntry(
        id: 'manual_scan',
        scanType: ScanType.manual,
        timestamp: DateTime.now(),
        scanDuration: const Duration(seconds: 0),
        networksFound: networkSummaries.length,
        suspiciousNetworks: networkSummaries.length,
        threatsDetected: networkSummaries.length,
        verifiedNetworks: 0,
        networkSummaries: networkSummaries,
        location: _currentPosition != null
            ? '${_currentPosition!.latitude},${_currentPosition!.longitude}'
            : _locationController.text.trim(),
        wasSuccessful: true,
      );

      // Submit the threat report
      final reportingService = ThreatReportingService();
      final reportId = await reportingService.submitThreatReport(
        alert: manualAlert,
        scanContext: scanContext,
        userNotes: _additionalNotesController.text.trim().isNotEmpty 
            ? _additionalNotesController.text.trim() 
            : null,
        reportReason: 'user_initiated',
        followUpContact: false,
      );

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 48,
            ),
            title: const Text('Report Submitted'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your threat report has been successfully submitted to DICT-CALABARZON for investigation.',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Report ID: ${reportId.substring(0, 8)}...',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(true); // Return to previous screen with success result
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _submitThreatReport,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Colors.red[600]!;
      case AlertSeverity.high:
        return Colors.orange[600]!;
      case AlertSeverity.medium:
        return Colors.yellow[700]!;
      case AlertSeverity.low:
        return Colors.blue[600]!;
    }
  }
}