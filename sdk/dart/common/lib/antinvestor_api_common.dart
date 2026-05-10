/// Common types and utilities shared across all Ant Investor API services.
///
/// This library provides:
/// - **Token Management**: Automatic token refresh and persistence
/// - **Authentication Interceptors**: Transparent token refresh for Connect RPC
/// - **JWT Utilities**: Parse and validate JWT tokens
/// - **Common Protobuf Types**: Shared message types across services
///
/// ## Token Refresh Interceptor
///
/// ```dart
/// import 'package:antinvestor_api_common/antinvestor_api_common.dart';
///
/// // Create a token manager
/// final tokenManager = TokenManager(
///   persistTokens: (accessToken, refreshToken) async {
///     // Save to secure storage
///   },
///   loadTokens: () async {
///     // Load from secure storage
///     return TokenPair(accessToken: '...', refreshToken: '...');
///   },
/// );
///
/// await tokenManager.initialize();
///
/// // Create the interceptor
/// final interceptor = TokenRefreshInterceptor(
///   getAccessToken: () => tokenManager.accessToken,
///   getRefreshToken: () => tokenManager.refreshToken,
///   setAccessToken: (token) => tokenManager.setAccessToken(token),
///   isTokenExpired: (token) => JwtUtils.isTokenExpired(token),
///   refreshToken: (refreshToken) async {
///     // Call your auth service to refresh
///     final response = await authClient.refreshToken(refreshToken);
///     return response.accessToken;
///   },
/// );
///
/// // Use with any service client
/// final client = ChatServiceClient(
///   channel,
/// );
/// ```
library;

// Export authentication utilities
export 'src/common/auth/jwt_utils.dart';
export 'src/common/auth/token_manager.dart';
export 'src/common/auth/token_refresh_interceptor.dart';

// Export client helpers
export 'src/common/client/transport_helper.dart';
export 'src/common/client/client_base.dart';

// Export generated protobuf files
export 'src/common/v1/common.pb.dart';
export 'src/common/v1/common.pbenum.dart';
export 'src/common/v1/common.pbjson.dart';
export 'src/common/v1/money.pb.dart';
export 'src/common/v1/money.pbenum.dart';
export 'src/common/v1/money.pbjson.dart';

// Export well-known types (shared across all service packages)
export 'src/google/protobuf/struct.pb.dart';
export 'src/google/protobuf/struct.pbenum.dart';
export 'src/google/protobuf/struct.pbjson.dart';
export 'src/google/protobuf/timestamp.pb.dart';
export 'src/google/protobuf/timestamp.pbenum.dart';
export 'src/google/protobuf/timestamp.pbjson.dart';
export 'src/google/protobuf/duration.pb.dart';
export 'src/google/protobuf/duration.pbenum.dart';
export 'src/google/protobuf/duration.pbjson.dart';
export 'src/google/protobuf/any.pb.dart';
export 'src/google/protobuf/any.pbenum.dart';
export 'src/google/protobuf/any.pbjson.dart';

// Export Google types (shared across all service packages).
//
// google.type.Money / Money$json are intentionally hidden — services have
// migrated to common.v1.Money (re-exported above). The remaining
// google.type.* re-exports stay for codes that still use Interval, etc.
export 'src/google/type/interval.pb.dart';
export 'src/google/type/interval.pbenum.dart';
export 'src/google/type/interval.pbjson.dart';
export 'src/google/type/money.pb.dart' hide Money;
export 'src/google/type/money.pbenum.dart';
export 'src/google/type/money.pbjson.dart' hide Money$json, moneyDescriptor;
