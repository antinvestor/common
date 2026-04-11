import 'dart:async';

import 'package:flutter/foundation.dart';

/// Holds the state for a paginated list loaded from a gRPC stream.
class PaginatedState<T> {
  const PaginatedState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<T> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  PaginatedState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return PaginatedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for consuming a gRPC paginated stream one page at a time.
///
/// Usage:
/// ```dart
/// final controller = PaginatedStreamController<MyResponse, MyItem>(
///   streamFactory: () => client.search(request),
///   extract: (response) => response.data,
/// );
/// await controller.loadFirstPage();
/// // later...
/// await controller.loadMore();
/// ```
class PaginatedStreamController<R, T> {
  PaginatedStreamController({
    required Stream<R> Function() streamFactory,
    required List<T> Function(R response) extract,
    int maxPages = 20,
  }) : _streamFactory = streamFactory,
       _extract = extract,
       _maxPages = maxPages;

  final Stream<R> Function() _streamFactory;
  final List<T> Function(R response) _extract;
  final int _maxPages;

  StreamSubscription<R>? _subscription;
  late final _stateNotifier = ValueNotifier<PaginatedState<T>>(const PaginatedState());
  int _pagesLoaded = 0;
  Completer<void>? _pageCompleter;
  bool _streamExhausted = false;

  ValueListenable<PaginatedState<T>> get stateListenable => _stateNotifier;

  PaginatedState<T> get state => _stateNotifier.value;

  /// Start the stream and load the first page.
  Future<void> loadFirstPage() async {
    _updateState(
      const PaginatedState<T>().copyWith(isLoading: true, clearError: true),
    );
    _pagesLoaded = 0;
    _streamExhausted = false;

    try {
      _subscription?.cancel();
      final stream = _streamFactory();
      _pageCompleter = Completer<void>();

      _subscription = stream.listen(
        (response) {
          final items = _extract(response);
          _pagesLoaded++;

          final currentItems = [...state.items, ...items];
          final exhausted = items.isEmpty || _pagesLoaded >= _maxPages;

          _updateState(
            PaginatedState<T>(
              items: currentItems,
              hasMore: !exhausted,
              isLoading: false,
              isLoadingMore: false,
            ),
          );

          if (exhausted) {
            _streamExhausted = true;
            _subscription?.cancel();
          }

          _pageCompleter?.complete();
          _pageCompleter = null;
        },
        onError: (error) {
          _updateState(
            state.copyWith(
              isLoading: false,
              isLoadingMore: false,
              error: error.toString(),
            ),
          );
          _pageCompleter?.complete();
          _pageCompleter = null;
        },
        onDone: () {
          _streamExhausted = true;
          _updateState(
            state.copyWith(
              hasMore: false,
              isLoading: false,
              isLoadingMore: false,
            ),
          );
          _pageCompleter?.complete();
          _pageCompleter = null;
        },
      );

      // Wait for first page
      if (_pageCompleter != null) {
        await _pageCompleter!.future;
      }
    } catch (e) {
      _updateState(PaginatedState<T>(error: e.toString()));
    }
  }

  /// Pause after each page, resume to get next page.
  /// With gRPC streams, data arrives continuously, so we just wait.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || _streamExhausted) return;

    _updateState(state.copyWith(isLoadingMore: true));

    // The stream delivers pages as they come — just wait for the next one
    _pageCompleter = Completer<void>();
    _subscription?.resume();

    await _pageCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _updateState(state.copyWith(isLoadingMore: false, hasMore: false));
      },
    );
  }

  void _updateState(PaginatedState<T> newState) {
    _stateNotifier.value = newState;
  }

  void dispose() {
    _subscription?.cancel();
    _stateNotifier.dispose();
  }
}
