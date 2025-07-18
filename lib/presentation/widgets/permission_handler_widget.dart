import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/permission_service.dart';

class PermissionHandlerWidget extends StatefulWidget {
  final Widget child;
  final Function()? onPermissionsGranted;
  final Function()? onPermissionsDenied;

  const PermissionHandlerWidget({
    super.key,
    required this.child,
    this.onPermissionsGranted,
    this.onPermissionsDenied,
  });

  @override
  State<PermissionHandlerWidget> createState() => _PermissionHandlerWidgetState();
}

class _PermissionHandlerWidgetState extends State<PermissionHandlerWidget> with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();
  PermissionState _permissionState = PermissionState.checking;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Re-check permissions when app comes back from background
    if (state == AppLifecycleState.resumed && _permissionState != PermissionState.granted) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      setState(() {
        _permissionState = PermissionState.checking;
        _errorMessage = '';
      });

      final status = await _permissionService.checkAllPermissions();
      developer.log('Permission check result: $status');

      if (mounted) {
        setState(() {
          switch (status) {
            case PermissionStatus.granted:
              _permissionState = PermissionState.granted;
              widget.onPermissionsGranted?.call();
              break;
            case PermissionStatus.denied:
              _permissionState = PermissionState.denied;
              widget.onPermissionsDenied?.call();
              break;
            case PermissionStatus.permanentlyDenied:
              _permissionState = PermissionState.permanentlyDenied;
              widget.onPermissionsDenied?.call();
              break;
            default:
              _permissionState = PermissionState.denied;
              widget.onPermissionsDenied?.call();
          }
        });
      }
    } catch (e) {
      developer.log('Error checking permissions: $e');
      if (mounted) {
        setState(() {
          _permissionState = PermissionState.error;
          _errorMessage = 'Failed to check permissions: $e';
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    try {
      setState(() {
        _permissionState = PermissionState.requesting;
      });

      final results = await _permissionService.requestAllPermissions();
      developer.log('Permission request results: $results');
      
      final allGranted = results.values.every((status) => status == PermissionStatus.granted);
      final anyPermanentlyDenied = results.values.any((status) => status == PermissionStatus.permanentlyDenied);

      if (mounted) {
        setState(() {
          if (allGranted) {
            _permissionState = PermissionState.granted;
            widget.onPermissionsGranted?.call();
          } else if (anyPermanentlyDenied) {
            _permissionState = PermissionState.permanentlyDenied;
            widget.onPermissionsDenied?.call();
          } else {
            _permissionState = PermissionState.denied;
            widget.onPermissionsDenied?.call();
          }
        });
      }
    } catch (e) {
      developer.log('Error requesting permissions: $e');
      if (mounted) {
        setState(() {
          _permissionState = PermissionState.error;
          _errorMessage = 'Failed to request permissions: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_permissionState) {
      case PermissionState.checking:
        return _buildCheckingWidget();
      case PermissionState.requesting:
        return _buildRequestingWidget();
      case PermissionState.granted:
        return widget.child;
      case PermissionState.denied:
        return _buildPermissionDeniedWidget();
      case PermissionState.permanentlyDenied:
        return _buildPermanentlyDeniedWidget();
      case PermissionState.error:
        return _buildErrorWidget();
    }
  }

  Widget _buildCheckingWidget() {
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.security,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Checking Permissions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verifying app permissions...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestingWidget() {
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on,
                size: 48,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Requesting Permissions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please grant permissions in the system dialog...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedWidget() {
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_off,
                  size: 48,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Permissions Required',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'DisConX needs location and Wi-Fi permissions to scan for nearby networks and protect you from security threats.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Required for evil twin attack detection and network security verification',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _requestPermissions,
                      icon: const Icon(Icons.location_on),
                      label: const Text('Grant Permissions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _permissionState = PermissionState.granted;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Continue Without Permissions (Limited Functionality)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermanentlyDeniedWidget() {
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.settings,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Settings Required',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Permissions have been permanently denied. Please enable them manually in your device settings.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Go to: Settings > Apps > DisConX > Permissions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enable: Location & Nearby Devices',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await openAppSettings();
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Open Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _checkPermissions,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Check Again'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Permission Error',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage.isNotEmpty 
                    ? _errorMessage 
                    : 'An error occurred while checking permissions.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _checkPermissions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum PermissionState {
  checking,
  requesting, 
  granted,
  denied,
  permanentlyDenied,
  error,
}