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

/// StandardRole defines the standard roles used across all services for
/// authorization. These roles map to OPL namespace relations and Keto tuples.
/// buf:lint:ignore ENUM_VALUE_PREFIX
class StandardRole extends $pb.ProtobufEnum {
  /// buf:lint:ignore ENUM_ZERO_VALUE_SUFFIX
  static const StandardRole ROLE_UNSPECIFIED =
      StandardRole._(0, _omitEnumNames ? '' : 'ROLE_UNSPECIFIED');
  static const StandardRole ROLE_OWNER =
      StandardRole._(1, _omitEnumNames ? '' : 'ROLE_OWNER');
  static const StandardRole ROLE_ADMIN =
      StandardRole._(2, _omitEnumNames ? '' : 'ROLE_ADMIN');
  static const StandardRole ROLE_OPERATOR =
      StandardRole._(3, _omitEnumNames ? '' : 'ROLE_OPERATOR');
  static const StandardRole ROLE_VIEWER =
      StandardRole._(4, _omitEnumNames ? '' : 'ROLE_VIEWER');
  static const StandardRole ROLE_MEMBER =
      StandardRole._(5, _omitEnumNames ? '' : 'ROLE_MEMBER');
  static const StandardRole ROLE_SERVICE =
      StandardRole._(6, _omitEnumNames ? '' : 'ROLE_SERVICE');

  static const $core.List<StandardRole> values = <StandardRole>[
    ROLE_UNSPECIFIED,
    ROLE_OWNER,
    ROLE_ADMIN,
    ROLE_OPERATOR,
    ROLE_VIEWER,
    ROLE_MEMBER,
    ROLE_SERVICE,
  ];

  static final $core.List<StandardRole?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static StandardRole? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StandardRole._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
