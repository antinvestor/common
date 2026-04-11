import 'package:antinvestor_ui_core/auth/device_location.dart';

/// AuditContext captures the full context of an authenticated action:
/// who (user identity claims), when (timestamp), where (device location),
/// and the tenancy context (tenant + partition).
class AuditContext {
  const AuditContext({
    required this.profileId,
    this.tenantId,
    this.partitionId,
    this.contactId,
    this.accessId,
    this.sessionId,
    this.deviceId,
    this.displayName,
    this.location,
  });

  final String? tenantId;
  final String? partitionId;
  final String profileId;
  final String? contactId;
  final String? accessId;
  final String? sessionId;
  final String? deviceId;
  final String? displayName;
  final DeviceLocation? location;

  Map<String, String> toMap() {
    final map = <String, String>{
      'profile_id': profileId,
      'tenant_id': ?tenantId,
      'partition_id': ?partitionId,
      'contact_id': ?contactId,
      'access_id': ?accessId,
      'session_id': ?sessionId,
      'device_id': ?deviceId,
      'display_name': ?displayName,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    if (location != null) {
      map.addAll(location!.toMap());
    }

    return map;
  }

  String get displayLabel => displayName != null && displayName!.isNotEmpty
      ? '$displayName ($profileId)'
      : profileId;

  String get locationLabel => location?.displayLabel ?? 'Unknown location';

  String get fullLabel => '$displayLabel — $locationLabel';
}
