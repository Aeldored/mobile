import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class BottomNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Create animation controllers for each tab (4 tabs now)
    _controllers = List.generate(4, (index) => 
      AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    // Create scale animations for each tab
    _scaleAnimations = _controllers.map((controller) => 
      Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
      ),
    ).toList();

    // Create fade animations for each tab
    _fadeAnimations = _controllers.map((controller) => 
      Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      ),
    ).toList();

    // Animate the currently selected tab
    if (widget.currentIndex < _controllers.length) {
      _controllers[widget.currentIndex].forward();
    }
  }

  @override
  void didUpdateWidget(BottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update animations when currentIndex changes
    if (oldWidget.currentIndex != widget.currentIndex) {
      // Reset previous tab animation
      if (oldWidget.currentIndex < _controllers.length) {
        _controllers[oldWidget.currentIndex].reverse();
      }
      // Animate new tab
      if (widget.currentIndex < _controllers.length) {
        _controllers[widget.currentIndex].forward();
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.search,
                label: 'Scan',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.notifications,
                label: 'Alerts',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.menu_book,
                label: 'Learn',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = widget.currentIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.gray;

    return Expanded(
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimations[index], _fadeAnimations[index]]),
        builder: (context, child) {
          return Transform.scale(
              scale: _scaleAnimations[index].value,
              child: Opacity(
                opacity: isSelected ? 1.0 : (_fadeAnimations[index].value).clamp(0.0, 1.0),
                child: InkWell(
                onTap: () {
                  // Add haptic feedback for better user experience
                  HapticFeedback.lightImpact();
                  widget.onTabSelected(index);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.all(isSelected ? 6 : 4),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: isSelected ? 24 : 22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: color,
                          fontSize: isSelected ? 11 : 10,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          height: 1.0,
                        ),
                        child: Text(label),
                      ),
                    ],
                  ),
                ),
              ),
            )
            );
        },
      ),
    );
  }
}