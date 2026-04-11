import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antinvestor_ui_core/auth/role_provider.dart';

/// Widget that renders [child] only if the current user has at least one of
/// [requiredRoles]. Otherwise renders [fallback] (defaults to nothing).
class RoleGuard extends ConsumerWidget {
  const RoleGuard({
    super.key,
    required this.requiredRoles,
    required this.child,
    this.fallback,
  });

  final Set<String> requiredRoles;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(currentUserRolesProvider);

    return rolesAsync.when(
      data: (userRoles) {
        if (requiredRoles.isEmpty ||
            userRoles.intersection(requiredRoles).isNotEmpty) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Full-screen guard that shows an "Access Denied" page when the user
/// does not have the required roles.
class RouteRoleGuard extends ConsumerWidget {
  const RouteRoleGuard({
    super.key,
    required this.requiredRoles,
    required this.child,
  });

  final Set<String> requiredRoles;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(currentUserRolesProvider);

    return rolesAsync.when(
      data: (userRoles) {
        if (requiredRoles.isEmpty ||
            userRoles.intersection(requiredRoles).isNotEmpty) {
          return child;
        }
        return const _AccessDeniedScreen();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _AccessDeniedScreen(),
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

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
              'You do not have permission to view this page.\n'
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
