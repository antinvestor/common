/// Returns the required roles for a given route location using
/// longest-prefix matching against a permissions map.
///
/// Returns empty set if no match (allow all authenticated users).
Set<String> requiredRolesForRoute(
  String location,
  Map<String, Set<String>> permissions,
) {
  final sorted = permissions.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  for (final prefix in sorted) {
    if (location == prefix || location.startsWith('$prefix/')) {
      return permissions[prefix]!;
    }
  }
  return {};
}
