import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ScanStatusWidget extends StatefulWidget {
  final bool isScanning;
  final double progress;
  final int networksFound;
  final int threatsDetected;

  const ScanStatusWidget({
    super.key,
    required this.isScanning,
    required this.progress,
    required this.networksFound,
    required this.threatsDetected,
  });

  @override
  State<ScanStatusWidget> createState() => _ScanStatusWidgetState();
}

class _ScanStatusWidgetState extends State<ScanStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    
    _breatheController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _breatheAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _breatheController,
      curve: Curves.easeInOut,
    ));

    if (widget.isScanning) {
      _breatheController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ScanStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning != oldWidget.isScanning) {
      if (widget.isScanning) {
        _breatheController.repeat(reverse: true);
      } else {
        _breatheController.stop();
        _breatheController.reset();
      }
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle breathing effect (only when scanning)
          if (widget.isScanning)
            AnimatedBuilder(
              animation: _breatheAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _breatheAnimation.value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                );
              },
            ),
          
          // Main status circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Progress indicator (only when scanning)
                if (widget.isScanning)
                  CircularProgressIndicator(
                    value: widget.progress,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                
                // Center icon
                Icon(
                  _getStatusIcon(),
                  color: Colors.white,
                  size: widget.isScanning ? 28 : 32,
                ),
              ],
            ),
          ),
          
          // Status text below
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _getStatusText(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (widget.isScanning) {
      return AppColors.primary;
    } else if (widget.threatsDetected > 0) {
      return Colors.red;
    } else if (widget.networksFound > 0) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    if (widget.isScanning) {
      return Icons.radar;
    } else if (widget.threatsDetected > 0) {
      return Icons.warning;
    } else if (widget.networksFound > 0) {
      return Icons.check_circle;
    } else {
      return Icons.wifi_find;
    }
  }

  String _getStatusText() {
    if (widget.isScanning) {
      return 'Scanning...';
    } else if (widget.threatsDetected > 0) {
      return 'Threats Found';
    } else if (widget.networksFound > 0) {
      return 'Scan Complete';
    } else {
      return 'Ready';
    }
  }
}