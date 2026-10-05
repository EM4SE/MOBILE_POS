import 'package:flutter/material.dart';
import '../../app/theme/app_dimensions.dart';

/// Helper to handle responsive layouts for 1280x720 POS terminals down to smaller Android devices
class ResponsiveHelper {
  ResponsiveHelper._();

  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;
  static Size screenSize(BuildContext context) => MediaQuery.of(context).size;
  static Orientation orientation(BuildContext context) => MediaQuery.of(context).orientation;

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  static bool isSmallScreen(BuildContext context) {
    return screenWidth(context) < AppDimensions.breakpointMobile;
  }

  static bool isTablet(BuildContext context) {
    final width = screenWidth(context);
    return width >= AppDimensions.breakpointMobile && width < AppDimensions.breakpointDesktop;
  }

  static bool isLargeScreen(BuildContext context) {
    return screenWidth(context) >= AppDimensions.breakpointDesktop;
  }

  /// True if running on primary 1280x720 landscape or similar wide screen
  static bool isStandardPosTerminal(BuildContext context) {
    final width = screenWidth(context);
    final height = screenHeight(context);
    return isLandscape(context) && width >= 1000 && height >= 600;
  }

  /// Dynamic scale factor to smoothly adapt touch elements between 800x480, 1024x600, and 1280x720+
  static double scaleFactor(BuildContext context) {
    final width = screenWidth(context);
    if (width >= 1280) return 1.0;
    if (width >= 1024) return 0.92;
    if (width >= 800) return 0.82;
    return 0.75;
  }
}
