import 'package:flutter/material.dart';

import 'package:antinvestor_ui_core/responsive/breakpoints.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
    this.desktopLayout,
  });

  final Widget mobileLayout;
  final Widget? tabletLayout;
  final Widget? desktopLayout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (AppBreakpoints.isDesktop(constraints.maxWidth)) {
          return desktopLayout ?? tabletLayout ?? mobileLayout;
        }
        if (AppBreakpoints.isTablet(constraints.maxWidth)) {
          return tabletLayout ?? mobileLayout;
        }
        return mobileLayout;
      },
    );
  }
}
