import 'package:flutter/material.dart';
import '../../core/constants/ui_constants.dart';

class CommonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? borderRadius;
  final List<BoxShadow>? boxShadow;

  const CommonCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderRadius,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: UIConstants.spaceMD),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? UIConstants.radiusLG),
        boxShadow: boxShadow ?? UIConstants.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        elevation: UIConstants.elevationNone,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius ?? UIConstants.radiusLG),
          splashColor: Theme.of(context).primaryColor.withValues(alpha: UIConstants.opacityPressed),
          highlightColor: Theme.of(context).primaryColor.withValues(alpha: UIConstants.opacityHover),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(UIConstants.spaceLG),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: UIConstants.spaceMD),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: UIConstants.heading4,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: UIConstants.spaceXS),
                  Text(
                    subtitle!,
                    style: UIConstants.bodySmall.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}