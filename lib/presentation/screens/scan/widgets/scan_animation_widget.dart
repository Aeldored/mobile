import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_colors.dart';

class ScanAnimationWidget extends StatefulWidget {
  final bool isScanning;

  const ScanAnimationWidget({
    super.key,
    required this.isScanning,
  });

  @override
  State<ScanAnimationWidget> createState() => _ScanAnimationWidgetState();
}

class _ScanAnimationWidgetState extends State<ScanAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _particleAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _particleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.linear,
    ));

    if (widget.isScanning) {
      _startAnimations();
    }
  }

  @override
  void didUpdateWidget(ScanAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning != oldWidget.isScanning) {
      if (widget.isScanning) {
        _startAnimations();
      } else {
        _stopAnimations();
      }
    }
  }

  void _startAnimations() {
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
    _particleController.repeat();
  }

  void _stopAnimations() {
    _pulseController.stop();
    _rotationController.stop();
    _particleController.stop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background gradient
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.05),
                  AppColors.primary.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
                stops: const [0.3, 0.7, 1.0],
              ),
            ),
          ),

          // Animated scan particles
          if (widget.isScanning) ..._buildScanParticles(),
          
          // Outer pulse ring
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.primary.withValues(alpha: 0.3),
                      ],
                      stops: const [0.7, 0.85, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Middle pulse ring
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.3 - (_pulseAnimation.value - 0.8),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.primary.withValues(alpha: 0.2),
                      ],
                      stops: const [0.8, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // Scanning arc
          if (widget.isScanning)
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: CustomPaint(
                    size: const Size(140, 140),
                    painter: ScanArcPainter(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  ),
                );
              },
            ),
          
          // Center icon with enhanced animation
          AnimatedBuilder(
            animation: Listenable.merge([_rotationAnimation, _pulseAnimation]),
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isScanning 
                    ? 1.0 + (_pulseAnimation.value - 1.0) * 0.1
                    : 1.0,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: widget.isScanning ? 20 : 10,
                        spreadRadius: widget.isScanning ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background pattern
                      Transform.rotate(
                        angle: widget.isScanning ? _rotationAnimation.value * 0.5 : 0,
                        child: Icon(
                          Icons.wifi,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 28,
                        ),
                      ),
                      // Main icon
                      Icon(
                        Icons.wifi,
                        color: Colors.white,
                        size: 36,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Signal strength indicators
          if (widget.isScanning) ..._buildSignalIndicators(),
        ],
      ),
    );
  }

  List<Widget> _buildScanParticles() {
    return List.generate(8, (index) {
      final angle = (index * math.pi * 2) / 8;
      return AnimatedBuilder(
        animation: _particleAnimation,
        builder: (context, child) {
          final distance = 80 + (_particleAnimation.value * 40);
          final x = math.cos(angle + _particleAnimation.value * math.pi * 2) * distance;
          final y = math.sin(angle + _particleAnimation.value * math.pi * 2) * distance;
          
          return Transform.translate(
            offset: Offset(x, y),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: (0.6 * (1 - _particleAnimation.value)).clamp(0.0, 1.0),
                ),
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      );
    });
  }

  List<Widget> _buildSignalIndicators() {
    return List.generate(4, (index) {
      final angle = (index * math.pi) / 2;
      return AnimatedBuilder(
        animation: _particleAnimation,
        builder: (context, child) {
          final opacity = (math.sin(_particleAnimation.value * math.pi * 2 + index) + 1) / 2;
          final distance = 100.0;
          final x = math.cos(angle) * distance;
          final y = math.sin(angle) * distance;
          
          return Transform.translate(
            offset: Offset(x, y),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: (opacity * 0.8).clamp(0.0, 1.0)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
                  width: 1,
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class ScanArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  ScanArcPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // Draw scanning arc (quarter circle)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start angle
      math.pi / 2,  // Sweep angle
      false,
      paint,
    );

    // Draw fade effect
    final gradient = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi / 6,
      false,
      gradient..strokeWidth = strokeWidth * 2..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}