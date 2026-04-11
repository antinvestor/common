import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nav_items.dart';

/// Tracks which parent nav sections are expanded in the sidebar.
class SidebarExpansionState extends ChangeNotifier {
  final Set<String> _expanded = {};

  bool isExpanded(String id) => _expanded.contains(id);

  void toggle(String id) {
    if (_expanded.contains(id)) {
      _expanded.remove(id);
    } else {
      _expanded.add(id);
    }
    notifyListeners();
  }

  void expand(String id) {
    if (_expanded.add(id)) notifyListeners();
  }

  void collapse(String id) {
    if (_expanded.remove(id)) notifyListeners();
  }

  void expandForRoute(String route, List<NavItem> items) {
    var changed = false;
    for (final item in items) {
      if (item.hasChildren && item.matchesRoute(route)) {
        changed = _expanded.add(item.id) || changed;
      }
    }
    if (changed) notifyListeners();
  }
}

final sidebarExpansionProvider = ChangeNotifierProvider<SidebarExpansionState>(
  (ref) => SidebarExpansionState(),
);
