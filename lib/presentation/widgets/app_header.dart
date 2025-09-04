import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class AppHeader extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool showNotificationIcon;
  final bool showSettingsIcon;
  final bool showBackButton;
  final bool showAboutIcon;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onAboutTap;

  const AppHeader({
    super.key,
    required this.title,
    this.showNotificationIcon = true,
    this.showSettingsIcon = true,
    this.showBackButton = false,
    this.showAboutIcon = false,
    this.onNotificationTap,
    this.onSettingsTap,
    this.onAboutTap,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class _AppHeaderState extends State<AppHeader> 
    with TickerProviderStateMixin {
  late AnimationController _titleController;
  late AnimationController _actionsController;
  late Animation<double> _titleFadeAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _actionsAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _actionsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _titleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _actionsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _actionsController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _startAnimations() async {
    _titleController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _actionsController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _actionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 2,
      leading: widget.showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
            )
          : null,
      automaticallyImplyLeading: false,
      title: AnimatedBuilder(
        animation: _titleController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _titleFadeAnimation,
            child: SlideTransition(
              position: _titleSlideAnimation,
              child: Row(
                children: [
                  if (widget.title == 'DisConX') ...[
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1000),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (value * 0.2),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/w_logo_png.png'),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        AnimatedBuilder(
          animation: _actionsController,
          builder: (context, child) {
            return Transform.scale(
              scale: _actionsAnimation.value,
              child: Opacity(
                opacity: _actionsAnimation.value.clamp(0.0, 1.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.showNotificationIcon)
                      _buildAnimatedActionButton(
                        icon: Icons.notifications_outlined,
                        onPressed: widget.onNotificationTap,
                        delay: 0,
                      ),
                    if (widget.showSettingsIcon)
                      _buildAnimatedActionButton(
                        icon: Icons.menu,
                        onPressed: widget.onSettingsTap,
                        delay: 100,
                      ),
                    if (widget.showAboutIcon)
                      _buildAnimatedActionButton(
                        icon: Icons.info_outline,
                        onPressed: widget.onAboutTap,
                        delay: 200,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 10),
          child: IconButton(
            icon: Icon(icon),
            onPressed: onPressed != null ? () {
              HapticFeedback.lightImpact();
              onPressed();
            } : null,
            color: Colors.white,
            iconSize: 22 + (value * 2),
            splashRadius: 20,
          ),
        );
      },
    );
  }
}