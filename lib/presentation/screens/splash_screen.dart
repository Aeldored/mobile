import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/permission_handler_widget.dart';
import 'permission_acknowledgment_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late AnimationController _pulseController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  
  final List<String> _loadingSteps = [
    'Initializing security modules...',
    'Loading network scanner...',
    'Configuring threat detection...',
    'Preparing Wi-Fi analyzer...',
    'Ready to secure your connection!'
  ];
  
  int _currentStep = 0;
  String _currentMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _startSplashSequence();
  }

  void _initializeAnimation() {
    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Progress animation controller
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    // Pulse animation controller (repeating)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Listen to progress updates
    _progressController.addListener(() {
      final step = (_progressAnimation.value * _loadingSteps.length).floor();
      if (step != _currentStep && step < _loadingSteps.length) {
        setState(() {
          _currentStep = step;
          _currentMessage = _loadingSteps[step];
        });
      }
    });
  }

  Future<void> _startSplashSequence() async {
    try {
      // Start logo animation
      _logoController.forward();
      
      // Start pulse animation (repeating)
      _pulseController.repeat(reverse: true);
      
      // Wait for logo animation to complete
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Start progress animation
      _progressController.forward();
      
      // Wait for loading to complete
      await _progressController.forward();
      
      // Wait a bit more to show completion
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check if permissions have been acknowledged
      await _checkPermissionAcknowledgment();
      
    } catch (e) {
      // If anything fails, navigate to permission screen
      if (mounted) {
        _navigateToPermissionScreen();
      }
    }
  }

  Future<void> _checkPermissionAcknowledgment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAcknowledged = prefs.getBool('permissions_acknowledged') ?? false;
      
      if (!mounted) return;
      
      if (hasAcknowledged) {
        // Skip permission screen, go directly to main app
        _navigateToMainApp();
      } else {
        // Show permission acknowledgment screen
        _navigateToPermissionScreen();
      }
    } catch (e) {
      // If SharedPreferences fails, show permission screen to be safe
      if (mounted) {
        _navigateToPermissionScreen();
      }
    }
  }

  void _navigateToPermissionScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PermissionAcknowledgmentScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _navigateToMainApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PermissionHandlerWidget(
              child: const MainScreen(),
              onPermissionsGranted: () {
                // Permissions granted, app is ready
              },
              onPermissionsDenied: () {
                // Handle permission denial - app can still work with limited functionality
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildAppIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
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
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
              ),
            );
          },
        ),
        // Main logo container
        Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Main logo
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/logo_png.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // Small security badge
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              Color(0xFF1D4ED8),
              Color(0xFF1E40AF),
              Color(0xFF1E3A8A),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_logoController, _progressController]),
            builder: (context, child) {
              return Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildAppIcon(),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'DisConX',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 3,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                  color: Colors.black26,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'DICT Secure Connect',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white.withValues(alpha: 0.9),
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Protecting your Wi-Fi connections from threats',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),
                          
                          // Enhanced loading section
                          Column(
                            children: [
                              Container(
                                width: 280,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Stack(
                                  children: [
                                    AnimatedBuilder(
                                      animation: _progressAnimation,
                                      builder: (context, child) {
                                        return Container(
                                          width: 280 * _progressAnimation.value,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Colors.white, Colors.cyan],
                                            ),
                                            borderRadius: BorderRadius.circular(3),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white.withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 0),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  _currentMessage,
                                  key: ValueKey(_currentMessage),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Department of Information and\nCommunications Technology',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'CALABARZON',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.6),
                              letterSpacing: 2,
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}