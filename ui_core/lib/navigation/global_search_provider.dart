import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global search query shared between the app shell search bar and
/// entity list pages.
///
/// The app shell renders a single search bar that updates this provider.
/// Entity list pages watch it to filter/search their data — no per-page
/// search bars needed.
final globalSearchQueryProvider =
    NotifierProvider<GlobalSearchNotifier, String>(GlobalSearchNotifier.new);

class GlobalSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;

  void clear() => state = '';
}
