// This is a generated file - do not edit.
//
// Generated from common/v1/permissions.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'permissions.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'permissions.pbenum.dart';

/// RoleBinding maps a standard role to the permissions it grants within a service.
/// Used to generate OPL permit functions and enforce role-based access control.
class RoleBinding extends $pb.GeneratedMessage {
  factory RoleBinding({
    StandardRole? role,
    $core.Iterable<$core.String>? permissions,
  }) {
    final result = RoleBinding._();
    if (role != null) result.role = role;
    if (permissions != null) result.permissions.addAll(permissions);
    return result;
  }

  RoleBinding._();

  factory RoleBinding.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RoleBinding()..mergeFromBuffer(data, registry);
  factory RoleBinding.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RoleBinding()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RoleBinding',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'common.v1'),
      createEmptyInstance: RoleBinding.$_createMessage)
    ..aE<StandardRole>(1, _omitFieldNames ? '' : 'role',
        enumValues: StandardRole.values)
    ..pPS(2, _omitFieldNames ? '' : 'permissions')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoleBinding clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoleBinding copyWith(void Function(RoleBinding) updates) =>
      super.copyWith((message) => updates(message as RoleBinding))
          as RoleBinding;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RoleBinding() / RoleBinding.new instead')
  static RoleBinding create() => RoleBinding._();
  static $pb.GeneratedMessage $_createMessage() => RoleBinding._();
  @$core.override
  RoleBinding createEmptyInstance() => RoleBinding._();
  @$core.pragma('dart2js:noInline')
  static RoleBinding getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RoleBinding>(
          RoleBinding.$_createMessage);
  static RoleBinding? _defaultInstance;

  /// The role being granted permissions.
  @$pb.TagNumber(1)
  StandardRole get role => $_getN(0);
  @$pb.TagNumber(1)
  set role(StandardRole value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRole() => $_has(0);
  @$pb.TagNumber(1)
  void clearRole() => $_clearField(1);

  /// Permissions granted to this role. Must be a subset of ServicePermissions.permissions.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get permissions => $_getList(1);
}

/// MethodPermissions declares access control requirements for an RPC method.
class MethodPermissions extends $pb.GeneratedMessage {
  factory MethodPermissions({
    $core.Iterable<$core.String>? permissions,
    $core.bool? allowUnauthenticated,
  }) {
    final result = MethodPermissions._();
    if (permissions != null) result.permissions.addAll(permissions);
    if (allowUnauthenticated != null)
      result.allowUnauthenticated = allowUnauthenticated;
    return result;
  }

  MethodPermissions._();

  factory MethodPermissions.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MethodPermissions()..mergeFromBuffer(data, registry);
  factory MethodPermissions.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MethodPermissions()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MethodPermissions',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'common.v1'),
      createEmptyInstance: MethodPermissions.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'permissions')
    ..aOB(2, _omitFieldNames ? '' : 'allowUnauthenticated')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MethodPermissions clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MethodPermissions copyWith(void Function(MethodPermissions) updates) =>
      super.copyWith((message) => updates(message as MethodPermissions))
          as MethodPermissions;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MethodPermissions() / MethodPermissions.new instead')
  static MethodPermissions create() => MethodPermissions._();
  static $pb.GeneratedMessage $_createMessage() => MethodPermissions._();
  @$core.override
  MethodPermissions createEmptyInstance() => MethodPermissions._();
  @$core.pragma('dart2js:noInline')
  static MethodPermissions getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MethodPermissions>(
          MethodPermissions.$_createMessage);
  static MethodPermissions? _defaultInstance;

  /// Permissions required to call this method, e.g. "profile_view", "contact_manage".
  /// All listed permissions must be satisfied (AND logic).
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get permissions => $_getList(0);

  /// If true, the method can be called without authentication.
  @$pb.TagNumber(2)
  $core.bool get allowUnauthenticated => $_getBF(1);
  @$pb.TagNumber(2)
  set allowUnauthenticated($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAllowUnauthenticated() => $_has(1);
  @$pb.TagNumber(2)
  void clearAllowUnauthenticated() => $_clearField(2);
}

/// ServicePermissions declares all permissions a service requires to function.
/// This serves as a registry of permissions that must be provisioned for the service,
/// and includes role bindings for OPL generation and authorization enforcement.
class ServicePermissions extends $pb.GeneratedMessage {
  factory ServicePermissions({
    $core.String? namespace,
    $core.Iterable<$core.String>? permissions,
    $core.Iterable<RoleBinding>? roleBindings,
  }) {
    final result = ServicePermissions._();
    if (namespace != null) result.namespace = namespace;
    if (permissions != null) result.permissions.addAll(permissions);
    if (roleBindings != null) result.roleBindings.addAll(roleBindings);
    return result;
  }

  ServicePermissions._();

  factory ServicePermissions.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ServicePermissions()..mergeFromBuffer(data, registry);
  factory ServicePermissions.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ServicePermissions()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServicePermissions',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'common.v1'),
      createEmptyInstance: ServicePermissions.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'namespace')
    ..pPS(2, _omitFieldNames ? '' : 'permissions')
    ..pPM<RoleBinding>(3, _omitFieldNames ? '' : 'roleBindings',
        subBuilder: RoleBinding.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServicePermissions clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServicePermissions copyWith(void Function(ServicePermissions) updates) =>
      super.copyWith((message) => updates(message as ServicePermissions))
          as ServicePermissions;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ServicePermissions() / ServicePermissions.new instead')
  static ServicePermissions create() => ServicePermissions._();
  static $pb.GeneratedMessage $_createMessage() => ServicePermissions._();
  @$core.override
  ServicePermissions createEmptyInstance() => ServicePermissions._();
  @$core.pragma('dart2js:noInline')
  static ServicePermissions getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServicePermissions>(
          ServicePermissions.$_createMessage);
  static ServicePermissions? _defaultInstance;

  /// Namespace for this service's permissions, used for OPL namespace generation
  /// and ensuring consistency across authorization systems.
  /// e.g. "service_profile", "service_payment", "service_tenancy".
  @$pb.TagNumber(1)
  $core.String get namespace => $_getSZ(0);
  @$pb.TagNumber(1)
  set namespace($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNamespace() => $_has(0);
  @$pb.TagNumber(1)
  void clearNamespace() => $_clearField(1);

  /// All permissions this service needs, e.g. "profile_view", "profile_create".
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get permissions => $_getList(1);

  /// Role-to-permission mappings for this service. Used to generate OPL permit
  /// functions and for runtime role-based access control.
  @$pb.TagNumber(3)
  $pb.PbList<RoleBinding> get roleBindings => $_getList(2);
}

class Permissions {
  static final methodPermissions = $pb.Extension<MethodPermissions>(
      _omitMessageNames ? '' : 'google.protobuf.MethodOptions',
      _omitFieldNames ? '' : 'methodPermissions',
      50000,
      $pb.PbFieldType.OM,
      defaultOrMaker: MethodPermissions.getDefault,
      subBuilder: MethodPermissions.$_createMessage);
  static final servicePermissions = $pb.Extension<ServicePermissions>(
      _omitMessageNames ? '' : 'google.protobuf.ServiceOptions',
      _omitFieldNames ? '' : 'servicePermissions',
      50000,
      $pb.PbFieldType.OM,
      defaultOrMaker: ServicePermissions.getDefault,
      subBuilder: ServicePermissions.$_createMessage);
  static void registerAllExtensions($pb.ExtensionRegistry registry) {
    registry.add(methodPermissions);
    registry.add(servicePermissions);
  }
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
