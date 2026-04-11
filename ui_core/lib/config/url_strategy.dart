import 'url_strategy_stub.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart';

/// Configures the URL strategy for the app.
/// On web, uses path-based URLs (no hash fragment) so OAuth callbacks
/// redirect correctly. On other platforms, this is a no-op.
void configureUrlStrategy() => configureUrlStrategyImpl();
