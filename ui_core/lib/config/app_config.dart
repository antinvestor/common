/// Environment-aware application configuration.
///
/// Values are injected at build time via `--dart-define` flags.
/// Defaults are set to **development** so `flutter run` works out of the box.
///
/// The define keys match the shared Makefile.common variables:
///   OIDC_CLIENT_ID  -> AppConfig.oauthClientId
///   OIDC_ISSUER     -> AppConfig.oauthIssuerUrl
///
/// Production build example:
/// ```
/// make ui-build-prod \
///   OIDC_CLIENT_ID=d6qbqdkpf2t52mcunf60 \
///   OIDC_ISSUER=https://oauth2.stawi.org
/// ```
///
/// Development (default -- no flags needed):
///   clientId:  d6qbqdkpf2t52mcunf6g  (dev tenant)
///   issuerUrl: https://oauth2.stawi.org
abstract final class AppConfig {
  /// OAuth2 client ID for the current environment.
  /// Makefile passes this as OIDC_CLIENT_ID.
  /// Host apps MUST provide this via --dart-define=OIDC_CLIENT_ID=...
  static const oauthClientId = String.fromEnvironment(
    'OIDC_CLIENT_ID',
    defaultValue: '',
  );

  /// OAuth2 issuer URL (OIDC discovery endpoint).
  /// Makefile passes this as OIDC_ISSUER.
  /// Host apps MUST provide this via --dart-define=OIDC_ISSUER=...
  static const oauthIssuerUrl = String.fromEnvironment(
    'OIDC_ISSUER',
    defaultValue: '',
  );
}
