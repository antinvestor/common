import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Configuration for an entity type displayed as a chip.
class EntityChipConfig {
  const EntityChipConfig({
    required this.icon,
    required this.color,
    this.routeBuilder,
  });

  final IconData icon;
  final Color color;
  /// Builds a route path from the entity ID. Null means non-navigable.
  final String Function(String id)? routeBuilder;
}

/// A tappable chip that shows an entity icon and label, optionally navigating
/// to a detail route.
///
/// Usage:
/// ```dart
/// EntityChip(
///   config: EntityChipConfig(
///     icon: Icons.person_outline,
///     color: Colors.indigo,
///     routeBuilder: (id) => '/profiles/$id',
///   ),
///   id: someProfileId,
///   label: 'John Doe',
/// )
/// ```
class EntityChip extends StatelessWidget {
  const EntityChip({
    super.key,
    required this.config,
    required this.id,
    this.label,
    this.onTap,
  });

  final EntityChipConfig config;
  final String id;
  /// Display label. Falls back to truncated ID if not provided.
  final String? label;
  /// Custom tap handler. If null and config.routeBuilder is set, navigates.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (id.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final displayLabel = label ?? (id.length > 12 ? '${id.substring(0, 12)}...' : id);
    final color = config.color;

    return InkWell(
      onTap: onTap ?? (config.routeBuilder != null
          ? () => _navigate(context)
          : null),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(config.icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                displayLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context) {
    final route = config.routeBuilder!(id);
    GoRouter.of(context).go(route);
  }
}
