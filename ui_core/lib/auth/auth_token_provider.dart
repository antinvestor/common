/// Abstract interface for providing auth tokens to the API layer.
///
/// Host applications implement this to bridge their auth system
/// (e.g., OpenID Connect, Firebase Auth) to the core's AuthInterceptor.
abstract class AuthTokenProvider {
  /// Returns a valid access token, refreshing if near expiry.
  Future<String?> ensureValidAccessToken();

  /// Forces a token refresh, ignoring cached expiry.
  Future<String?> forceRefreshAccessToken();

  /// Logs out the current user and clears all tokens.
  Future<void> logout();
}
