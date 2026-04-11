import 'package:connectrpc/connect.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antinvestor_ui_core/auth/auth_token_provider.dart';
import 'package:antinvestor_ui_core/logging/app_logger.dart';
import 'package:antinvestor_ui_core/api/http_client_native.dart'
    if (dart.library.js_interop) 'package:antinvestor_ui_core/api/http_client_web.dart';

/// Interceptor that injects the Bearer token into every request.
///
/// Strategy:
/// 1. Before request: get a valid token.
/// 2. If request fails with unauthenticated: force-refresh and retry once.
/// 3. permissionDenied is NOT retried (valid token, missing role).
class AuthInterceptor {
  AuthInterceptor(this._tokenProvider, this._onAuthFailure);
  final AuthTokenProvider _tokenProvider;
  final void Function() _onAuthFailure;
  bool _authFailureFired = false;

  void _triggerAuthFailure() {
    if (_authFailureFired) return;
    _authFailureFired = true;
    _onAuthFailure();
  }

  AnyFn<I, O> call<I extends Object, O extends Object>(AnyFn<I, O> next) {
    return (req) async {
      var token = await _tokenProvider.ensureValidAccessToken();
      if (token != null) {
        req.headers['authorization'] = 'Bearer $token';
      }
      try {
        return await next(req);
      } on ConnectException catch (e) {
        if (e.code != Code.unauthenticated) {
          rethrow;
        }

        AppLogger.warning(
          'Token rejected (unauthenticated), attempting refresh',
          data: {'code': '${e.code}'},
        );

        final newToken = await _tokenProvider.forceRefreshAccessToken();
        if (newToken == null) {
          AppLogger.error(
            'Token refresh failed — logging out',
          );
          _triggerAuthFailure();
          rethrow;
        }
        req.headers['authorization'] = 'Bearer $newToken';
        try {
          return await next(req);
        } on ConnectException catch (retryError) {
          if (retryError.code == Code.unauthenticated) {
            AppLogger.warning(
              'Retry with fresh token also rejected',
              data: {'code': '${retryError.code}'},
            );
          }
          rethrow;
        }
      }
    };
  }
}

bool _globalAuthFailureFired = false;

/// Reset the global auth failure guard after a successful login.
void resetAuthFailureGuard() => _globalAuthFailureFired = false;

/// Creates a Connect RPC transport for the given [baseUrl].
///
/// Requires an [AuthTokenProvider] to be available via Riverpod.
/// Host apps must provide the [authTokenProvider] override.
Transport createTransport(
  AuthTokenProvider tokenProvider, {
  required String baseUrl,
  void Function()? onAuthFailure,
}) {
  final authInterceptor = AuthInterceptor(tokenProvider, () {
    if (_globalAuthFailureFired) return;
    _globalAuthFailureFired = true;
    AppLogger.error('Auth failure — logging out');
    tokenProvider.logout();
    onAuthFailure?.call();
  });

  return protocol.Transport(
    baseUrl: baseUrl,
    codec: const ProtoCodec(),
    httpClient: createPlatformHttpClient(),
    interceptors: [authInterceptor.call],
    useHttpGet: false,
  );
}

/// Provider for the auth token provider. Host apps MUST override this.
final authTokenProviderProvider = Provider<AuthTokenProvider>((ref) {
  throw UnimplementedError(
    'authTokenProviderProvider must be overridden in the host app\'s ProviderScope.',
  );
});
