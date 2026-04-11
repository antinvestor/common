/// Declares all permissions a service UI library requires.
/// Each library exports one of these so the host app knows
/// what to batch-check against the authorization backend.
class PermissionManifest {
  const PermissionManifest({
    required this.namespace,
    required this.permissions,
  });

  /// The authorization namespace (matches proto service_permissions.namespace).
  /// E.g., "service_profile", "service_payment", "service_audit"
  final String namespace;

  /// All permissions this library uses, with their UI contexts.
  final List<PermissionEntry> permissions;

  /// All unique permission keys for batch checking.
  Set<String> get allPermissionKeys =>
      permissions.map((p) => p.key).toSet();
}

/// A single permission declaration with its UI context.
class PermissionEntry {
  const PermissionEntry({
    required this.key,
    required this.label,
    this.description = '',
    this.scope = PermissionScope.feature,
  });

  /// The permission key as defined in the proto.
  /// E.g., "profile_view", "contact_manage"
  final String key;

  /// Human-readable label for admin UI.
  final String label;

  /// Description of what this permission grants.
  final String description;

  /// Where this permission is checked in the UI.
  final PermissionScope scope;
}

/// Defines where a permission is enforced in the UI hierarchy.
enum PermissionScope {
  /// Controls whether the entire service is visible in navigation.
  service,

  /// Controls whether a specific feature/sub-page is visible.
  feature,

  /// Controls whether a specific action (create, edit, delete, export) is available.
  action,
}
