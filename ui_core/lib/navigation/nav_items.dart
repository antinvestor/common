import 'package:flutter/material.dart';

/// A single navigation item that can contain children (submenus).
class NavItem {
  const NavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.activeIcon,
    this.route,
    this.children = const [],
    this.requiredRoles = const {},
    this.requiredPermissions = const {},
    this.badge,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final String? route;
  final List<NavItem> children;
  final Set<String> requiredRoles;

  /// Proto-defined permission keys required to see this item.
  /// If non-empty, the user must have at least one of these permissions.
  final Set<String> requiredPermissions;
  final String? badge;

  bool get hasChildren => children.isNotEmpty;

  bool matchesRoute(String currentRoute) {
    if (route != null && currentRoute.startsWith(route!)) return true;
    return children.any((c) => c.matchesRoute(currentRoute));
  }

  NavItem? filterByRoles(Set<String> userRoles) {
    if (requiredRoles.isNotEmpty &&
        userRoles.intersection(requiredRoles).isEmpty) {
      return null;
    }

    final filteredChildren = children
        .map((c) => c.filterByRoles(userRoles))
        .whereType<NavItem>()
        .toList();

    if (route == null && filteredChildren.isEmpty && children.isNotEmpty) {
      return null;
    }

    return NavItem(
      id: id,
      label: label,
      icon: icon,
      activeIcon: activeIcon,
      route: route,
      children: filteredChildren,
      requiredRoles: requiredRoles,
      requiredPermissions: requiredPermissions,
      badge: badge,
    );
  }

  /// Filter this item and its children by proto-defined permissions.
  /// Returns null if the user lacks the required permissions.
  NavItem? filterByPermissions(Set<String> userPermissions) {
    if (requiredPermissions.isNotEmpty &&
        userPermissions.intersection(requiredPermissions).isEmpty) {
      return null;
    }

    final filteredChildren = children
        .map((c) => c.filterByPermissions(userPermissions))
        .whereType<NavItem>()
        .toList();

    if (route == null && filteredChildren.isEmpty && children.isNotEmpty) {
      return null;
    }

    return NavItem(
      id: id,
      label: label,
      icon: icon,
      activeIcon: activeIcon,
      route: route,
      children: filteredChildren,
      requiredRoles: requiredRoles,
      requiredPermissions: requiredPermissions,
      badge: badge,
    );
  }
}
