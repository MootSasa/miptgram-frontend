import 'package:flutter/material.dart';

/// Enum representing different screen types for responsive design.
enum ScreenType { mobile, tablet, desktop }

/// Returns the current screen type based on the context's width.
ScreenType getScreenType(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < 600) {
    return ScreenType.mobile;
  } else if (width < 1200) {
    return ScreenType.tablet;
  } else {
    return ScreenType.desktop;
  }
}

/// Extension on BuildContext to easily get screen type.
extension ScreenTypeExtension on BuildContext {
  ScreenType get screenType => getScreenType(this);

  bool get isMobile => screenType == ScreenType.mobile;
  bool get isTablet => screenType == ScreenType.tablet;
  bool get isDesktop => screenType == ScreenType.desktop;
}

/// A widget that builds different layouts based on screen size.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    Key? key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  }) : super(key: key);

  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return mobile;
        } else if (constraints.maxWidth < 1200) {
          return tablet;
        } else {
          return desktop;
        }
      },
    );
  }
}

/// A widget that provides the current screen size information to a builder.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

  final Widget Function(BuildContext, ScreenType) builder;

  @override
  Widget build(BuildContext context) {
    final screenType = getScreenType(context);
    return builder(context, screenType);
  }
}

/// Default breakpoints for responsive design.
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1200;
  static const double desktop = double.infinity;
}

/// Helper to check if the current width is within a range.
bool isWidthInRange(double width, double min, double max) {
  return width >= min && width < max;
}