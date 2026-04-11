import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the current user's roles as strings.
///
/// Host applications must override this provider to supply actual roles.
/// Example:
/// ```dart
/// // In your app's ProviderScope overrides:
/// ProviderScope(
///   overrides: [
///     currentUserRolesProvider.overrideWith((ref) async {
///       final authRepo = ref.watch(authRepositoryProvider);
///       return await authRepo.getUserRoles();
///     }),
///   ],
///   child: MyApp(),
/// )
/// ```
final currentUserRolesProvider = FutureProvider<Set<String>>((ref) async {
  // Default: empty roles. Host app MUST override this.
  return const <String>{};
});

/// Check if user has any of the specified roles.
final hasAnyRoleProvider = FutureProvider.family<bool, Set<String>>(
  (ref, requiredRoles) async {
    final roles = await ref.watch(currentUserRolesProvider.future);
    return requiredRoles.isEmpty || roles.intersection(requiredRoles).isNotEmpty;
  },
);
