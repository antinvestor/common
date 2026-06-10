import 'dart:convert';

import 'package:http/http.dart' as http;

import 'analytics_dashboard.dart';
import 'analytics_models.dart';
import 'analytics_provider.dart';
import 'service_analytics_spec.dart';

/// Transport hook used by [ThesaAnalyticsDataSource] to reach the Thesa BFF.
///
/// [path] is relative (e.g. `/api/analytics/query/scalar`) and [body] is the
/// JSON-encoded request payload. Implementations must POST the body with
/// `Content-Type: application/json` and the caller's auth credentials
/// attached, returning the raw response. This keeps ui_core free of any
/// app-specific auth dependency: the Thesa UI wires AuthRuntime.fetch in,
/// other apps wire a plain authenticated [http.Client].
typedef AnalyticsTransport =
    Future<http.Response> Function(String path, {Object? body});

/// Error returned by the Thesa analytics API (non-200 response).
///
/// Carries the HTTP status and the server's `error` message so failures
/// surface in the UI instead of degrading to silent zeros.
class AnalyticsQueryException implements Exception {
  const AnalyticsQueryException({
    required this.statusCode,
    required this.message,
    required this.path,
  });

  final int statusCode;
  final String message;
  final String path;

  @override
  String toString() =>
      'AnalyticsQueryException($statusCode) at $path: $message';
}

/// Standard [AnalyticsDataSource] backed by the Thesa BFF analytics API.
///
/// Endpoints (all POST, JSON bodies):
///   /api/analytics/query/scalar      -> {"value": num}
///   /api/analytics/query/timeseries  -> {"points": [{timestamp, value}]}
///   /api/analytics/query/grouped     -> {"segments": [{label, value}]}
///   /api/analytics/query/topn        -> {"items": [{label, value, metadata}]}
///
/// Request bodies follow the server contract exactly: time ranges are sent
/// as a nested `time_range: {start, end}` object (RFC3339) and the
/// time-series granularity as `step`. Tenant scoping is injected
/// server-side from the caller's JWT; this client never sends `tenant_id`
/// or `partition_id` filters and strips them defensively if a caller
/// passes them (mirroring the server's own sanitization).
class ThesaAnalyticsDataSource implements AnalyticsDataSource {
  ThesaAnalyticsDataSource(
    this._transport, {
    List<ServiceAnalyticsSpec> specs = const [],
  }) : _specs = {for (final s in specs) s.service: s};

  final AnalyticsTransport _transport;
  final Map<String, ServiceAnalyticsSpec> _specs;

  /// The catalog entry for [service], or null when none was registered.
  ServiceAnalyticsSpec? specFor(String service) => _specs[service];

  // ---------------------------------------------------------------------
  // AnalyticsDataSource implementation (spec-driven)
  // ---------------------------------------------------------------------

  @override
  Future<List<MetricValue>> getMetrics(
    String service, {
    AnalyticsTimeRange? timeRange,
  }) async {
    final spec = _specs[service];
    if (spec == null || spec.kpis.isEmpty) return const <MetricValue>[];

    final values = await Future.wait([
      for (final kpi in spec.kpis)
        queryScalar(
          metric: kpi.metric,
          aggregation: kpi.aggregation,
          filters: {...spec.baseFilters, ...?kpi.filters},
          timeRange: timeRange,
        ),
    ]);

    return [
      for (var i = 0; i < spec.kpis.length; i++)
        MetricValue(
          key: spec.kpis[i].key,
          label: spec.kpis[i].label,
          value: values[i],
          unit: spec.kpis[i].unit,
          icon: spec.kpis[i].icon,
        ),
    ];
  }

  @override
  Future<List<TimeSeries>> getTimeSeries(
    String service,
    String metric, {
    AnalyticsTimeRange? timeRange,
  }) async {
    final spec = _specs[service];
    final chart = spec?.chartFor(metric, type: ChartType.timeSeries);
    final points = await queryTimeSeries(
      metric: metric,
      aggregation: chart?.aggregation ?? AnalyticsAggregation.sum,
      filters: {...?spec?.baseFilters, ...?chart?.filters},
      timeRange: timeRange,
      granularity: chart?.granularity ?? timeRange?.granularity,
    );
    return [
      TimeSeries(key: metric, label: chart?.label ?? metric, points: points),
    ];
  }

  @override
  Future<List<DistributionSegment>> getDistribution(
    String service,
    String metric,
    String groupBy, {
    AnalyticsTimeRange? timeRange,
  }) {
    final spec = _specs[service];
    final chart = spec?.chartFor(metric, type: ChartType.distribution);
    return queryGrouped(
      metric: metric,
      groupBy: groupBy,
      aggregation: chart?.aggregation ?? AnalyticsAggregation.sum,
      filters: {...?spec?.baseFilters, ...?chart?.filters},
      timeRange: timeRange,
    );
  }

  @override
  Future<List<TopNItem>> getTopN(
    String service,
    String metric, {
    int limit = 10,
    AnalyticsTimeRange? timeRange,
  }) {
    final spec = _specs[service];
    final table = spec?.tableFor(metric);
    final groupBy = table?.groupBy;
    if (groupBy == null || groupBy.isEmpty) {
      throw ArgumentError(
        'Top-N queries require group_by: declare TableConfig.topN('
        '"$metric", groupBy: ...) in the ServiceAnalyticsSpec for '
        '"$service".',
      );
    }
    return queryTopN(
      metric: metric,
      groupBy: groupBy,
      aggregation: table?.aggregation ?? AnalyticsAggregation.sum,
      limit: limit,
      filters: {...?spec?.baseFilters, ...?table?.filters},
      timeRange: timeRange,
    );
  }

  // ---------------------------------------------------------------------
  // Raw query methods (one per endpoint)
  // ---------------------------------------------------------------------

  /// Query a single scalar value.
  Future<double> queryScalar({
    required String metric,
    AnalyticsAggregation aggregation = AnalyticsAggregation.sum,
    Map<String, String>? filters,
    AnalyticsTimeRange? timeRange,
  }) async {
    final data = await _post(
      '/api/analytics/query/scalar',
      _requestBody(
        metric: metric,
        aggregation: aggregation,
        filters: filters,
        timeRange: timeRange,
      ),
    );
    return ((data['value'] ?? 0) as num).toDouble();
  }

  /// Query time series data points.
  Future<List<TimeSeriesPoint>> queryTimeSeries({
    required String metric,
    AnalyticsAggregation aggregation = AnalyticsAggregation.sum,
    Map<String, String>? filters,
    AnalyticsTimeRange? timeRange,
    TimeGranularity? granularity,
  }) async {
    final data = await _post(
      '/api/analytics/query/timeseries',
      _requestBody(
        metric: metric,
        aggregation: aggregation,
        filters: filters,
        timeRange: timeRange,
        step: granularity ?? timeRange?.granularity,
      ),
    );
    final points = data['points'] as List<dynamic>? ?? const [];
    return [
      for (final p in points.cast<Map<String, dynamic>>())
        TimeSeriesPoint(
          timestamp: DateTime.parse(p['timestamp'] as String),
          value: (p['value'] as num).toDouble(),
          label: p['label'] as String?,
        ),
    ];
  }

  /// Query a grouped distribution (pie/donut segments).
  Future<List<DistributionSegment>> queryGrouped({
    required String metric,
    required String groupBy,
    AnalyticsAggregation aggregation = AnalyticsAggregation.sum,
    Map<String, String>? filters,
    AnalyticsTimeRange? timeRange,
  }) async {
    final data = await _post(
      '/api/analytics/query/grouped',
      _requestBody(
        metric: metric,
        aggregation: aggregation,
        filters: filters,
        groupBy: groupBy,
        timeRange: timeRange,
      ),
    );
    final segments = data['segments'] as List<dynamic>? ?? const [];
    return [
      for (final s in segments.cast<Map<String, dynamic>>())
        DistributionSegment(
          label: s['label'] as String,
          value: (s['value'] as num).toDouble(),
        ),
    ];
  }

  /// Query top-N ranked items. The server requires [groupBy].
  Future<List<TopNItem>> queryTopN({
    required String metric,
    required String groupBy,
    AnalyticsAggregation aggregation = AnalyticsAggregation.sum,
    int limit = 10,
    Map<String, String>? filters,
    AnalyticsTimeRange? timeRange,
  }) async {
    final data = await _post(
      '/api/analytics/query/topn',
      _requestBody(
        metric: metric,
        aggregation: aggregation,
        filters: filters,
        groupBy: groupBy,
        limit: limit,
        timeRange: timeRange,
      ),
    );
    final items = data['items'] as List<dynamic>? ?? const [];
    return [
      for (final item in items.cast<Map<String, dynamic>>())
        TopNItem(
          label: item['label'] as String,
          value: (item['value'] as num).toDouble(),
          metadata: (item['metadata'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ),
        ),
    ];
  }

  // ---------------------------------------------------------------------
  // Request building
  // ---------------------------------------------------------------------

  Map<String, dynamic> _requestBody({
    required String metric,
    required AnalyticsAggregation aggregation,
    Map<String, String>? filters,
    String? groupBy,
    int? limit,
    AnalyticsTimeRange? timeRange,
    TimeGranularity? step,
  }) {
    final cleaned = _stripReservedFilters(filters);
    return <String, dynamic>{
      'metric': metric,
      'aggregation': aggregation.wireName,
      if (cleaned.isNotEmpty) 'filters': cleaned,
      'group_by': ?groupBy,
      'limit': ?limit,
      if (timeRange != null)
        'time_range': {
          'start': timeRange.start.toUtc().toIso8601String(),
          'end': timeRange.end.toUtc().toIso8601String(),
        },
      if (step != null) 'step': step.name,
    };
  }

  /// Removes the reserved tenancy labels (`tenant_id` / `partition_id`, in
  /// any dot or underscore spelling) from client-supplied filters. The
  /// server injects authoritative tenant scoping from the JWT and performs
  /// the same sanitization; stripping here keeps requests honest.
  static Map<String, String> _stripReservedFilters(
    Map<String, String>? filters,
  ) {
    if (filters == null || filters.isEmpty) return const {};
    return {
      for (final e in filters.entries)
        if (!_isReservedScopeLabel(_normalizeLabelName(e.key))) e.key: e.value,
    };
  }

  static bool _isReservedScopeLabel(String name) =>
      name == 'tenant_id' || name == 'partition_id';

  /// Mirrors the server's label normalization: every character invalid in a
  /// Prometheus label name becomes `_` (so `tenant.id` -> `tenant_id`), and
  /// a leading digit gets a `_` prefix.
  static String _normalizeLabelName(String name) {
    var s = name.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_');
    if (s.isNotEmpty && s.codeUnitAt(0) >= 0x30 && s.codeUnitAt(0) <= 0x39) {
      s = '_$s';
    }
    return s;
  }

  // ---------------------------------------------------------------------
  // HTTP plumbing
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _transport(path, body: json.encode(body));
    if (response.statusCode != 200) {
      throw AnalyticsQueryException(
        statusCode: response.statusCode,
        message: _errorMessage(response),
        path: path,
      );
    }
    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw AnalyticsQueryException(
        statusCode: response.statusCode,
        message: 'unexpected response shape: ${decoded.runtimeType}',
        path: path,
      );
    }
    return decoded;
  }

  static String _errorMessage(http.Response response) {
    try {
      final parsed = json.decode(utf8.decode(response.bodyBytes));
      final msg = (parsed as Map<String, dynamic>)['error'];
      if (msg is String && msg.isNotEmpty) return msg;
    } catch (_) {
      // Fall through to the generic message.
    }
    return 'HTTP ${response.statusCode}';
  }
}
