import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'permission_manifest.dart';

/// Collects permission manifests from all service UI libraries
/// and provides the complete list for batch checking.
class PermissionRegistry {
  PermissionRegistry._();

  static final PermissionRegistry instance = PermissionRegistry._();

  final List<PermissionManifest> _manifests = [];

  /// Register a permission manifest from a service UI library.
  void register(PermissionManifest manifest) => _manifests.add(manifest);

  /// All registered manifests.
  List<PermissionManifest> get manifests => List.unmodifiable(_manifests);

  /// All unique permission keys across all registered services.
  /// Use this to do a single batch check at startup.
  Set<String> get allPermissionKeys {
    final keys = <String>{};
    for (final m in _manifests) {
      keys.addAll(m.allPermissionKeys);
    }
    return keys;
  }

  /// All namespaces to check, mapped to their permission keys.
  Map<String, Set<String>> get permissionsByNamespace {
    final map = <String, Set<String>>{};
    for (final m in _manifests) {
      map.putIfAbsent(m.namespace, () => {}).addAll(m.allPermissionKeys);
    }
    return map;
  }

  /// Get permissions for a specific namespace and scope.
  Set<String> permissionsForNamespace(String namespace) {
    for (final m in _manifests) {
      if (m.namespace == namespace) {
        return m.allPermissionKeys;
      }
    }
    return const {};
  }

  /// Get service-level permissions (the minimum required to see a service).
  Set<String> servicePermissions(String namespace) {
    for (final m in _manifests) {
      if (m.namespace == namespace) {
        return m.permissions
            .where((p) => p.scope == PermissionScope.service)
            .map((p) => p.key)
            .toSet();
      }
    }
    return const {};
  }

  /// Clear all registrations (useful for testing).
  void clear() => _manifests.clear();
}

/// Riverpod provider exposing the permission registry.
final permissionRegistryProvider = Provider<PermissionRegistry>((ref) {
  return PermissionRegistry.instance;
});
