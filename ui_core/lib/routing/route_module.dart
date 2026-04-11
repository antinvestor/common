import 'package:go_router/go_router.dart';

import 'package:antinvestor_ui_core/navigation/nav_items.dart';

/// Abstract base for service UI modules that contribute routes and
/// navigation items to a host application.
///
/// Each service UI package exports a concrete RouteModule implementation.
/// The host app composes them:
/// ```dart
/// final modules = [ProfileRouteModule(), PaymentRouteModule(), ...];
/// ShellRoute(
///   routes: [...ownRoutes, for (final m in modules) ...m.buildRoutes()],
/// )
/// ```
abstract class RouteModule {
  /// Unique identifier (e.g., 'profile', 'payment', 'files').
  String get moduleId;

  /// GoRouter route trees to be merged into the host app's router.
  List<RouteBase> buildRoutes();

  /// Navigation items for the sidebar.
  List<NavItem> buildNavItems();

  /// Route permission map. Keys are route prefixes, values are
  /// sets of role strings required to access that route.
  Map<String, Set<String>> get routePermissions;
}
