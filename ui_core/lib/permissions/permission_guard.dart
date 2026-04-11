import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'permission_provider.dart';

/// Guards a widget based on specific permissions (not roles).
/// More granular than RoleGuard -- checks proto-defined permissions.
class PermissionGuard extends ConsumerWidget {
  const PermissionGuard({
    super.key,
    required this.permissions,
    required this.child,
    this.fallback,
    this.requireAll = false,
  });

  /// Permission keys to check (e.g., {'profile_create', 'contact_manage'}).
  final Set<String> permissions;
  final Widget child;
  final Widget? fallback;

  /// If true, ALL permissions are required. If false (default), ANY suffices.
  final bool requireAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsync = ref.watch(userPermissionsProvider);

    return permissionsAsync.when(
      data: (userPermissions) {
        if (permissions.isEmpty) return child;

        final hasAccess = requireAll
            ? permissions.every(userPermissions.contains)
            : userPermissions.intersection(permissions).isNotEmpty;

        if (hasAccess) return child;
        return fallback ?? const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Full-screen guard that shows an "Access Denied" page when the user
/// does not have the required permissions.
class RoutePermissionGuard extends ConsumerWidget {
  const RoutePermissionGuard({
    super.key,
    required this.permissions,
    required this.child,
    this.requireAll = false,
  });

  final Set<String> permissions;
  final Widget child;
  final bool requireAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsync = ref.watch(userPermissionsProvider);

    return permissionsAsync.when(
      data: (userPermissions) {
        if (permissions.isEmpty) return child;

        final hasAccess = requireAll
            ? permissions.every(userPermissions.contains)
            : userPermissions.intersection(permissions).isNotEmpty;

        if (hasAccess) return child;
        return const _PermissionDeniedScreen();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _PermissionDeniedScreen(),
    );
  }
}

class _PermissionDeniedScreen extends StatelessWidget {
  const _PermissionDeniedScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.lock_outlined,
                size: 36,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Access Denied',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have the required permissions to view this page.\n'
              'Contact your administrator if you need access.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
