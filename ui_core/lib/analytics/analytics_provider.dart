import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_models.dart';

// ---------------------------------------------------------------------------
// Abstract data source
// ---------------------------------------------------------------------------

/// Abstract analytics data source consumed by all analytics widgets.
///
/// Each host app (e.g., Thesa) provides a concrete implementation that
/// talks to the analytics backend. UI widgets only depend on this interface.
abstract class AnalyticsDataSource {
  /// Fetch KPI metric values for a service dashboard.
  Future<List<MetricValue>> getMetrics(
    String service, {
    AnalyticsTimeRange? timeRange,
  });

  /// Fetch time series data for a metric.
  Future<List<TimeSeries>> getTimeSeries(
    String service,
    String metric, {
    AnalyticsTimeRange? timeRange,
  });

  /// Fetch distribution/breakdown for a metric grouped by a dimension.
  Future<List<DistributionSegment>> getDistribution(
    String service,
    String metric,
    String groupBy, {
    AnalyticsTimeRange? timeRange,
  });

  /// Fetch top-N items for a metric.
  Future<List<TopNItem>> getTopN(
    String service,
    String metric, {
    int limit = 10,
    AnalyticsTimeRange? timeRange,
  });
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Override this in your app's ProviderScope to supply a concrete data source.
final analyticsDataSourceProvider = Provider<AnalyticsDataSource>((ref) {
  throw UnimplementedError(
    'analyticsDataSourceProvider must be overridden in the host app.',
  );
});

// --- Parameter classes for family providers ---------------------------------

class ServiceMetricsParams {
  const ServiceMetricsParams(this.service, {this.timeRange});
  final String service;
  final AnalyticsTimeRange? timeRange;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceMetricsParams &&
          other.service == service &&
          other.timeRange?.start == timeRange?.start &&
          other.timeRange?.end == timeRange?.end;

  @override
  int get hashCode => Object.hash(service, timeRange?.start, timeRange?.end);
}

class ServiceTimeSeriesParams {
  const ServiceTimeSeriesParams(this.service, this.metric, {this.timeRange});
  final String service;
  final String metric;
  final AnalyticsTimeRange? timeRange;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceTimeSeriesParams &&
          other.service == service &&
          other.metric == metric &&
          other.timeRange?.start == timeRange?.start &&
          other.timeRange?.end == timeRange?.end;

  @override
  int get hashCode =>
      Object.hash(service, metric, timeRange?.start, timeRange?.end);
}

class ServiceDistributionParams {
  const ServiceDistributionParams(this.service, this.metric, this.groupBy,
      {this.timeRange});
  final String service;
  final String metric;
  final String groupBy;
  final AnalyticsTimeRange? timeRange;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceDistributionParams &&
          other.service == service &&
          other.metric == metric &&
          other.groupBy == groupBy &&
          other.timeRange?.start == timeRange?.start &&
          other.timeRange?.end == timeRange?.end;

  @override
  int get hashCode =>
      Object.hash(service, metric, groupBy, timeRange?.start, timeRange?.end);
}

class ServiceTopNParams {
  const ServiceTopNParams(this.service, this.metric,
      {this.limit = 10, this.timeRange});
  final String service;
  final String metric;
  final int limit;
  final AnalyticsTimeRange? timeRange;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceTopNParams &&
          other.service == service &&
          other.metric == metric &&
          other.limit == limit &&
          other.timeRange?.start == timeRange?.start &&
          other.timeRange?.end == timeRange?.end;

  @override
  int get hashCode =>
      Object.hash(service, metric, limit, timeRange?.start, timeRange?.end);
}

// --- Convenience family providers -------------------------------------------

/// Fetches KPI metrics for a service.
final serviceMetricsProvider =
    FutureProvider.family<List<MetricValue>, ServiceMetricsParams>(
  (ref, params) {
    final ds = ref.watch(analyticsDataSourceProvider);
    return ds.getMetrics(params.service, timeRange: params.timeRange);
  },
);

/// Fetches time series data for a service metric.
final serviceTimeSeriesProvider =
    FutureProvider.family<List<TimeSeries>, ServiceTimeSeriesParams>(
  (ref, params) {
    final ds = ref.watch(analyticsDataSourceProvider);
    return ds.getTimeSeries(params.service, params.metric,
        timeRange: params.timeRange);
  },
);

/// Fetches distribution data for a service metric.
final serviceDistributionProvider =
    FutureProvider.family<List<DistributionSegment>, ServiceDistributionParams>(
  (ref, params) {
    final ds = ref.watch(analyticsDataSourceProvider);
    return ds.getDistribution(params.service, params.metric, params.groupBy,
        timeRange: params.timeRange);
  },
);

/// Fetches top-N items for a service metric.
final serviceTopNProvider =
    FutureProvider.family<List<TopNItem>, ServiceTopNParams>(
  (ref, params) {
    final ds = ref.watch(analyticsDataSourceProvider);
    return ds.getTopN(params.service, params.metric,
        limit: params.limit, timeRange: params.timeRange);
  },
);
