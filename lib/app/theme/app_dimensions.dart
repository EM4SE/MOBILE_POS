/// Standard dimension constants for touch-friendly POS terminals (1280x720 target)
class AppDimensions {
  AppDimensions._();

  // Padding and Spacing
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // Touch Target Minimums (Strict POS touch standard: >= 48dp)
  static const double minTouchTarget = 48.0;
  static const double buttonHeight = 52.0;
  static const double largeButtonHeight = 64.0;
  static const double headerHeight = 56.0;
  static const double tableHeaderHeight = 44.0;
  static const double tableRowHeight = 54.0;
  static const double keypadButtonHeight = 68.0;

  // Sharp Corners (Windows 8 style / Commercial POS aesthetic)
  static const double radiusNone = 0.0;
  static const double radiusXs = 2.0;
  static const double radiusSm = 4.0;

  // Border widths
  static const double borderWidth = 1.0;
  static const double borderThick = 2.0;

  // Screen Breakpoints
  static const double breakpointMobile = 600.0;
  static const double breakpointTablet = 900.0;
  static const double breakpointDesktop = 1200.0;
}
