# Changelog

## [2.0.0] - 2026-10-13

### Changed (breaking)

- Regenerated with protoc_plugin 25.1 (`buf.build/protocolbuffers/dart:v25.1.0`)
  / connect-dart 2.0; requires `protobuf ^6.1.0`, `connectrpc ^2.0.0`,
  `fixnum ^1.1.1`, Dart `^3.7.0`.
- Well-known types now come from `package:protobuf/well_known_types/...`.
  The barrel re-exports the runtime `Any`, `Duration`, `Struct` and
  `Timestamp`; the vendored `lib/src/google/protobuf/{any,duration,
  field_mask,struct,timestamp}` copies are gone.
- Empty `*.pbserver.dart` files are no longer generated or exported.

### Removed

- `google.type.Interval` and `google.type.Money` re-exports. No
  `antinvestor.common` proto imports them any more, so they are no longer
  generated. Use `common.v1.Money`.

## [1.53.1] - 2026-05-10

### Fixed

- Hide `Money`, `Money$json`, and `moneyDescriptor` from the
  `google/type/money` re-exports so the barrel no longer produces
  `ambiguous_export` errors at consumer sites that already use the
  canonical `common.v1.Money` re-exports added in 1.53.0.

## [1.53.0] - 2026-05-09

### Added

- `common.v1.Money` shared message type. Field numbers and types mirror
  `google.type.Money` so the wire format is identical — services migrating
  away from `google.type.Money` can do so without coordinating deploys.

## [1.52.0] - 2026-1-2

### Changed

- Switch to page cursor away from pagination

## [1.51.10] - 2025-12-31

### Changed

- Improve token manager error handling

## [1.51.4] - 2025-12-23

### Changed

- Bugfix missing json.dart exports from antinvestor_api_common.dart


## [1.51.2] - 2025-12-23

### Changed

- Working version of common code

## [1.50.22] - 2025-12-23

### Changed

- Improved the dart common replacement code

## [1.50.18] - 2025-12-23

### Changed

- Centralize most dependencies to the latest common code package

## [1.50.14] - 2025-12-23

### Changed

- Increment version of common code for dependency management


## [1.50.3] - 2025-12-22

### Changed

- Removed re-exports of `protobuf`, `connectrpc`, and `fixnum` packages - service SDKs should declare these dependencies directly

## [1.50.2] - 2025-12-22

### Changed

- Refactored client code to use common `ConnectClientBase` pattern
- Simplified client creation with `newXxxClient()` factory functions
- Removed redundant `client_factory.dart` files
- All common client functionality now in `antinvestor_api_common`

### Added

- Type aliases for convenience (e.g., `DeviceClient`, `ChatClient`)
- `ClientOptions` for flexible client configuration
- Support for `noAuth` mode for unauthenticated requests

## 1.47.1

### Changed
- Updated to latest common code and dependencies

## 1.47.0 - 2025-10-27

### 🚀 New Features
- Moved error details to common package for better reusability
- Added common validation utilities and error types
- Enhanced error handling across all services

### Changed
- Migrated from gRPC Gateway to Connect RPC protocol
- Updated dependencies and improved compatibility
- Refactored common utilities for better maintainability

### Fixed
- Resolved dependency resolution issues
- Fixed package versioning and compatibility
- Addressed potential memory leaks in common utilities

## 1.46.6 - 2025-10-19

### Changed
- Initial migration to Connect RPC
- Standardized error handling across services
- Improved code organization and documentation
