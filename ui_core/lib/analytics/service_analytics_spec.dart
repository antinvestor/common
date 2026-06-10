import 'package:flutter/material.dart';

import 'analytics_dashboard.dart';
import 'analytics_models.dart';

/// Declarative KPI specification rendered as a scalar query.
///
/// Each KPI maps to one `POST /api/analytics/query/scalar` call whose result
/// becomes a [MetricValue] card on the dashboard.
class KpiSpec {
  const KpiSpec(
    this.key, {
    required this.label,
    required this.metric,
    this.aggregation = AnalyticsAggregation.sum,
    this.filters,
    this.unit,
    this.icon,
  });

  /// Stable identifier, also used as the [MetricValue.key].
  final String key;

  /// Human-readable card label.
  final String label;

  /// OTel metric name queried from the analytics backend.
  final String metric;

  /// How the backend aggregates the metric.
  final AnalyticsAggregation aggregation;

  /// Extra label filters applied alongside the service's base filters.
  final Map<String, String>? filters;

  /// Unit hint for formatting: "count", "currency", "percent", "bytes".
  final String? unit;

  final IconData? icon;
}

/// Per-service analytics catalog: declares WHAT a service's analytics page
/// shows, while the data source and [AnalyticsDashboard] handle HOW.
///
/// Composes the existing dashboard config types ([ChartConfig],
/// [TableConfig]) so a service UI can do:
///
/// ```dart
/// const spec = ServiceAnalyticsSpec(
///   service: 'payment',
///   kpis: [
///     KpiSpec('total', label: 'Payments', metric: 'payment_total'),
///   ],
///   charts: [
///     ChartConfig.timeSeries('payment_total', label: 'Volume'),
///   ],
///   tables: [
///     TableConfig.topN('payment_total', label: 'Top Routes',
///         groupBy: 'route'),
///   ],
/// );
///
/// AnalyticsDashboard(
///   service: spec.service,
///   title: 'Payments',
///   metrics: spec.metricKeys,
///   charts: spec.charts,
///   tables: spec.tables,
/// )
/// ```
class ServiceAnalyticsSpec {
  const ServiceAnalyticsSpec({
    required this.service,
    this.baseFilters = const {},
    this.kpis = const [],
    this.charts = const [],
    this.tables = const [],
  });

  /// Service identifier matching the `service` argument that
  /// [AnalyticsDashboard] and the data source pass around.
  final String service;

  /// Filters applied to every query for this service
  /// (e.g. `{'service': 'payment'}`).
  final Map<String, String> baseFilters;

  /// KPI cards, each backed by a scalar query.
  final List<KpiSpec> kpis;

  /// Charts (time series and distributions), reusing the dashboard config.
  final List<ChartConfig> charts;

  /// Top-N tables, reusing the dashboard config.
  final List<TableConfig> tables;

  /// KPI keys, in declared order, for [AnalyticsDashboard.metrics].
  List<String> get metricKeys => [for (final k in kpis) k.key];

  /// The chart config for [metric], optionally narrowed by chart [type],
  /// or null when not declared.
  ChartConfig? chartFor(String metric, {ChartType? type}) {
    for (final c in charts) {
      if (c.metric == metric && (type == null || c.type == type)) return c;
    }
    return null;
  }

  /// The table config for [metric], or null when not declared.
  TableConfig? tableFor(String metric) {
    for (final t in tables) {
      if (t.metric == metric) return t;
    }
    return null;
  }
}
