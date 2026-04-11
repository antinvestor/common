// Helpers for consuming paginated gRPC streams safely.

/// Default max items returned by collectStream (pageSize 50 * maxPages 10).
/// Used by UI screens to determine if "Load More" / "hasMore" should be shown.
const kDefaultPagedResultLimit = 500;

/// Result of a paginated stream collection.
class PagedResult<T> {
  const PagedResult({required this.items, required this.hasMore});
  final List<T> items;
  final bool hasMore;
}

/// Collects items from a paginated server stream with a maximum page cap
/// to prevent unbounded memory growth.
///
/// [stream] is the gRPC response stream. [extract] pulls the list of items
/// from each response message. [maxPages] limits how many pages are consumed
/// (default 10). Returns the accumulated list.
Future<List<T>> collectStream<R, T>(
  Stream<R> stream, {
  required List<T> Function(R response) extract,
  int maxPages = 10,
}) async {
  final result = await collectStreamPaged(
    stream,
    extract: extract,
    maxPages: maxPages,
  );
  return result.items;
}

/// Like [collectStream] but also returns whether more pages are available.
Future<PagedResult<T>> collectStreamPaged<R, T>(
  Stream<R> stream, {
  required List<T> Function(R response) extract,
  int maxPages = 10,
}) async {
  final results = <T>[];
  var pages = 0;
  var hitPageCap = false;
  await for (final response in stream) {
    final items = extract(response);
    results.addAll(items);
    pages++;
    if (items.isEmpty) break;
    if (pages >= maxPages) {
      hitPageCap = true;
      break;
    }
  }
  return PagedResult(items: results, hasMore: hitPageCap);
}

/// Counts items from a paginated server stream with a maximum page cap.
/// Only accumulates the count, not the items themselves.
Future<int> countStream<R>(
  Stream<R> stream, {
  required int Function(R response) count,
  int maxPages = 20,
}) async {
  var total = 0;
  var pages = 0;
  await for (final response in stream) {
    final c = count(response);
    total += c;
    if (++pages >= maxPages || c == 0) break;
  }
  return total;
}
