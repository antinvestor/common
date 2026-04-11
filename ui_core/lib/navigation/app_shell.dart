import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:antinvestor_ui_core/responsive/breakpoints.dart';
import 'package:antinvestor_ui_core/navigation/app_sidebar.dart';

/// The app shell provides persistent sidebar navigation.
///
/// - Desktop/Tablet: persistent sidebar + content area
/// - Mobile: hamburger drawer + full-width content
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = AppBreakpoints.isMobile(constraints.maxWidth);

        if (isMobile) {
          return _MobileShell(
            currentRoute: currentRoute,
            child: navigationShell,
          );
        }

        return _DesktopShell(
          currentRoute: currentRoute,
          child: navigationShell,
        );
      },
    );
  }
}

/// Lightweight shell that takes a plain Widget child.
class AppShellSimple extends StatelessWidget {
  const AppShellSimple({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = AppBreakpoints.isMobile(constraints.maxWidth);

        if (isMobile) {
          return _MobileShell(currentRoute: currentRoute, child: child);
        }

        return _DesktopShell(currentRoute: currentRoute, child: child);
      },
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.currentRoute, required this.child});

  final String currentRoute;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(currentRoute: currentRoute),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.currentRoute, required this.child});

  final String currentRoute;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (scaffoldContext) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: AppSidebar(
          currentRoute: currentRoute,
          isDrawer: true,
          onNavigate: () => Navigator.of(context).pop(),
        ),
      ),
      body: child,
    );
  }
}
