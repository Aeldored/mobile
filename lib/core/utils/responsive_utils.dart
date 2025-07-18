import 'package:flutter/material.dart';

class ResponsiveUtils {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double getScreenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }

  static double getCardMaxWidth(BuildContext context) {
    if (isDesktop(context)) return 600;
    if (isTablet(context)) return 500;
    return double.infinity;
  }

  static int getCrossAxisCount(BuildContext context) {
    if (isDesktop(context)) return 4;
    if (isTablet(context)) return 3;
    return 2;
  }

  static double getFontSize(BuildContext context, FontSize size) {
    final baseSize = _getBaseFontSize(size);
    final scaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    
    if (isDesktop(context)) {
      return baseSize * 1.2 * scaleFactor;
    } else if (isTablet(context)) {
      return baseSize * 1.1 * scaleFactor;
    }
    return baseSize * scaleFactor;
  }

  static double _getBaseFontSize(FontSize size) {
    switch (size) {
      case FontSize.small:
        return 12;
      case FontSize.medium:
        return 14;
      case FontSize.large:
        return 16;
      case FontSize.xlarge:
        return 20;
      case FontSize.xxlarge:
        return 24;
    }
  }
}

enum FontSize { small, medium, large, xlarge, xxlarge }

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, BoxConstraints) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: builder);
  }
}

class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? ResponsiveUtils.getCardMaxWidth(context),
        ),
        padding: padding ?? ResponsiveUtils.getScreenPadding(context),
        child: child,
      ),
    );
  }
}