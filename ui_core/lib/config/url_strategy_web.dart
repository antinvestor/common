import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Use path-based URLs on web so OAuth callback redirects work correctly.
void configureUrlStrategyImpl() => usePathUrlStrategy();
