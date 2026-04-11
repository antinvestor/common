import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The resolved set of permissions the current user has.
/// Host apps override this with the result of a batch capability check.
final userPermissionsProvider = FutureProvider<Set<String>>((ref) async {
  // Default: empty. Host app MUST override this with batch check results.
  return const <String>{};
});

/// Check if user has a specific permission.
final hasPermissionProvider = Provider.family<bool, String>((ref, permission) {
  final permissions = ref.watch(userPermissionsProvider).valueOrNull ?? {};
  return permissions.contains(permission);
});

/// Check if user has ANY of the given permissions.
final hasAnyPermissionProvider =
    Provider.family<bool, Set<String>>((ref, required) {
  if (required.isEmpty) return true; // No permissions required = allow all
  final permissions = ref.watch(userPermissionsProvider).valueOrNull ?? {};
  return permissions.intersection(required).isNotEmpty;
});

/// Check if user has ALL of the given permissions.
final hasAllPermissionsProvider =
    Provider.family<bool, Set<String>>((ref, required) {
  if (required.isEmpty) return true;
  final permissions = ref.watch(userPermissionsProvider).valueOrNull ?? {};
  return required.every(permissions.contains);
});
