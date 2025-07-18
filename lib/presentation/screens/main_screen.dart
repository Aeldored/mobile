import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform, exit;
import '../widgets/app_header.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/settings_drawer.dart';
import 'home/home_screen.dart';
import 'scan/scan_screen.dart';
import 'alerts/alerts_screen.dart';
import 'education/education_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
  
  // Static method to find and navigate to tab from anywhere in the app
  static void navigateToTab(BuildContext context, int tabIndex) {
    final mainScreenState = context.findAncestorStateOfType<_MainScreenState>();
    mainScreenState?._onTabSelected(tabIndex);
  }
}

class _MainScreenState extends State<MainScreen> 
    with AutomaticKeepAliveClientMixin {
  int _currentIndex = 0;
  late List<Widget> _screens;
  DateTime? _lastBackPressed;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late PageController _pageController;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize page controller
    _pageController = PageController(initialPage: _currentIndex);
    
    // Initialize screens with unique keys to preserve state (4 tabs now)
    _screens = [
      HomeScreen(key: PageStorageKey('home_screen')),
      ScanScreen(key: PageStorageKey('scan_screen')),
      AlertsScreen(key: PageStorageKey('alerts_screen')),
      EducationScreen(key: PageStorageKey('education_screen')),
    ];
  }

  final List<String> _titles = [
    'DisConX',
    'Network Scan',
    'Security Alerts',
    'Cybersecurity Education',
  ];

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    
    // Animate to the page
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  
  void _onPageChanged(int index) {
    // Update current index when page changes via swipe
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _onNotificationTap() {
    // Navigate to alerts page
    _onTabSelected(2);
  }

  void _onSettingsTap() {
    // Open settings drawer from right side
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<bool> _onWillPop() async {
    // Check if settings drawer is open and close it first
    if (_scaffoldKey.currentState?.isEndDrawerOpen == true) {
      _scaffoldKey.currentState?.closeEndDrawer();
      return false; // Don't exit the app, just close drawer
    }
    
    // If not on home screen, navigate to home screen
    if (_currentIndex != 0) {
      _onTabSelected(0);
      return false; // Don't exit the app
    }

    // If on home screen, implement double-tap to exit
    final now = DateTime.now();
    if (_lastBackPressed == null || now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      
      // Show snackbar with exit instruction
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Press back again to exit'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return false; // Don't exit the app
    }

    // Double-tap detected, exit the app cleanly
    await _cleanAppExit();
    return false; // This line won't be reached, but required for bool return type
  }

  /// Clean app termination with proper resource cleanup
  Future<void> _cleanAppExit() async {
    try {
      // Clear any pending timers or background processes
      // (Add any other cleanup here as needed)
      
      // Hide any visible snackbars
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
      
      // Add a brief delay to ensure UI cleanup
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Exit the app properly based on platform
      if (Platform.isAndroid) {
        // On Android, use SystemNavigator.pop() for clean exit
        await SystemNavigator.pop();
      } else if (Platform.isIOS) {
        // On iOS, exit() is generally not recommended, but can be used
        // Note: iOS apps should generally not exit programmatically
        exit(0);
      } else {
        // Fallback for other platforms
        exit(0);
      }
    } catch (e) {
      // Fallback exit if cleanup fails
      exit(0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: const SettingsDrawer(),
        body: Column(
          children: [
            AppHeader(
              title: _titles[_currentIndex],
              showNotificationIcon: _currentIndex != 2, // Hide on alerts page
              showSettingsIcon: true, // Show hamburger menu on right side
              onNotificationTap: _onNotificationTap,
              onSettingsTap: _onSettingsTap,
            ),
            Expanded(
              child: PageStorage(
                bucket: PageStorageBucket(),
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: _screens,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigation(
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),
      ),
    );
  }
}