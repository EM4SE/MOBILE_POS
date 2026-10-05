import 'package:flutter/material.dart';
import '../../core/utils/responsive_helper.dart';

/// Responsive builder widget switching between landscape terminal layout and compact mobile layout
class ResponsiveLayout extends StatelessWidget {
  final Widget landscapeBody;
  final Widget? portraitBody;

  const ResponsiveLayout({
    super.key,
    required this.landscapeBody,
    this.portraitBody,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (ResponsiveHelper.isLandscape(context)) {
          return landscapeBody;
        }
        return portraitBody ?? landscapeBody;
      },
    );
  }
}
