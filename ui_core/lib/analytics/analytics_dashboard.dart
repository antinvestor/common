import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../responsive/breakpoints.dart';
import '../widgets/page_header.dart';
import 'analytics_models.dart';
import 'analytics_provider.dart';
import 'distribution_chart.dart';
import 'metrics_row.dart';
import 'time_range_selector.dart';
import 'time_series_chart.dart';
import 'top_n_list.dart';

// ---------------------------------------------------------------------------
// Configuration classes
// ---------------------------------------------------------------------------

/// Type of chart visualization.
enum ChartType { timeSeries, distribution }

/// Declarative chart configuration for the dashboard.
class ChartConfig {
  const ChartConfig.timeSeries(
    this.metric, {
    required this.label,
    this.granularity,
  })  : type = ChartType.timeSeries,
        groupBy = null;

  const ChartConfig.distribution(
    this.metric, {
    required this.label,
    required this.groupBy,
  })  : type = ChartType.distribution,
        granularity = null;

  final ChartType type;
  final String metric;
  final String label;
  final String? groupBy;
  final TimeGranularity? granularity;
}

/// Declarative table configuration for the dashboard.
class TableConfig {
  const TableConfig.topN(
    this.metric, {
    required this.label,
    this.limit = 10,
  });

  final String metric;
  final String label;
  final int limit;
}

// ---------------------------------------------------------------------------
// Dashboard widget
// ---------------------------------------------------------------------------

/// Declarative analytics dashboard that any service can use.
///
/// Configure what metrics, charts, and tables to show -- the widget
/// handles data fetching, layout, loading states, and refresh.
///
/// ```dart
/// AnalyticsDashboard(
///   service: 'payment',
///   title: 'Payment Analytics',
///   metrics: ['total_payments', 'total_volume', 'success_rate', 'avg_amount'],
///   charts: [
///     ChartConfig.timeSeries('payment_volume', label: 'Payment Volume'),
///     ChartConfig.distribution('payment_routes', groupBy: 'route', label: 'By Route'),
///   ],
///   tables: [
///     TableConfig.topN('top_recipients', label: 'Top Recipients', limit: 10),
///   ],
/// )
/// ```
class AnalyticsDashboard extends ConsumerStatefulWidget {
  const AnalyticsDashboard({
    super.key,
    required this.service,
    required this.title,
    this.breadcrumbs,
    this.metrics = const [],
    this.charts = const [],
    this.tables = const [],
    this.refreshInterval,
    this.actions,
  });

  final String service;
  final String title;
  final List<String>? breadcrumbs;

  /// Metric keys to show as KPI cards at the top.
  final List<String> metrics;

  /// Chart configurations to render in a responsive grid.
  final List<ChartConfig> charts;

  /// Table configurations to render below charts.
  final List<TableConfig> tables;

  /// Optional auto-refresh interval.
  final Duration? refreshInterval;

  /// Extra action widgets in the header area.
  final List<Widget>? actions;

  @override
  ConsumerState<AnalyticsDashboard> createState() =>
      _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends ConsumerState<AnalyticsDashboard> {
  late AnalyticsTimeRange _timeRange;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _timeRange = AnalyticsTimeRange.last30Days();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    if (widget.refreshInterval != null) {
      _refreshTimer = Timer.periodic(widget.refreshInterval!, (_) {
        _invalidateAll();
      });
    }
  }

  void _invalidateAll() {
    // Invalidate metrics
    ref.invalidate(serviceMetricsProvider);
    // Invalidate each chart/table provider
    for (final chart in widget.charts) {
      if (chart.type == ChartType.timeSeries) {
        ref.invalidate(serviceTimeSeriesProvider);
      } else {
        ref.invalidate(serviceDistributionProvider);
      }
    }
    for (final _ in widget.tables) {
      ref.invalidate(serviceTopNProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = AppBreakpoints.isDesktop(width);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Fetch metrics
    final metricsAsync = ref.watch(
      serviceMetricsProvider(
        ServiceMetricsParams(widget.service, timeRange: _timeRange),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          PageHeader(
            title: widget.title,
            breadcrumbs:
                widget.breadcrumbs ?? ['Services', widget.title, 'Analytics'],
            actions: [
              // Refresh button
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _invalidateAll,
              ),
              ...?widget.actions,
            ],
          ),
          const SizedBox(height: 16),

          // Time range selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: TimeRangeSelector(
              value: _timeRange,
              onChanged: (range) {
                setState(() => _timeRange = range);
              },
            ),
          ),
          const SizedBox(height: 20),

          // KPI metrics row
          if (widget.metrics.isNotEmpty)
            metricsAsync.when(
              data: (metrics) => MetricsRow(metrics: metrics),
              loading: () => MetricsRow(
                metrics: const [],
                isLoading: true,
                skeletonCount: widget.metrics.length.clamp(1, 4),
              ),
              error: (e, _) => _ErrorCard(message: 'Failed to load metrics: $e'),
            ),

          if (widget.metrics.isNotEmpty) const SizedBox(height: 20),

          // Charts in responsive grid
          if (widget.charts.isNotEmpty)
            _buildChartsGrid(isDesktop, cs, theme),

          if (widget.charts.isNotEmpty) const SizedBox(height: 20),

          // Tables
          for (final table in widget.tables) ...[
            _TopNSection(
              service: widget.service,
              config: table,
              timeRange: _timeRange,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildChartsGrid(bool isDesktop, ColorScheme cs, ThemeData theme) {
    final charts = widget.charts;

    if (!isDesktop || charts.length == 1) {
      return Column(
        children: [
          for (var i = 0; i < charts.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _ChartSection(
              service: widget.service,
              config: charts[i],
              timeRange: _timeRange,
            ),
          ],
        ],
      );
    }

    // 2-column layout for desktop
    final rows = <Widget>[];
    for (var i = 0; i < charts.length; i += 2) {
      if (i + 1 < charts.length) {
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ChartSection(
                    service: widget.service,
                    config: charts[i],
                    timeRange: _timeRange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ChartSection(
                    service: widget.service,
                    config: charts[i + 1],
                    timeRange: _timeRange,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        rows.add(
          _ChartSection(
            service: widget.service,
            config: charts[i],
            timeRange: _timeRange,
          ),
        );
      }
      if (i + 2 < charts.length) rows.add(const SizedBox(height: 16));
    }

    return Column(children: rows);
  }
}

// ---------------------------------------------------------------------------
// Internal section widgets
// ---------------------------------------------------------------------------

class _ChartSection extends ConsumerWidget {
  const _ChartSection({
    required this.service,
    required this.config,
    required this.timeRange,
  });

  final String service;
  final ChartConfig config;
  final AnalyticsTimeRange timeRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            config.label,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (config.type == ChartType.timeSeries)
            _buildTimeSeries(ref)
          else
            _buildDistribution(ref),
        ],
      ),
    );
  }

  Widget _buildTimeSeries(WidgetRef ref) {
    final async = ref.watch(
      serviceTimeSeriesProvider(
        ServiceTimeSeriesParams(service, config.metric, timeRange: timeRange),
      ),
    );
    return async.when(
      data: (series) => TimeSeriesChart(
        series: series,
        granularity: config.granularity ?? timeRange.granularity,
      ),
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _ErrorCard(message: 'Failed to load chart: $e'),
    );
  }

  Widget _buildDistribution(WidgetRef ref) {
    final async = ref.watch(
      serviceDistributionProvider(
        ServiceDistributionParams(
          service,
          config.metric,
          config.groupBy ?? 'default',
          timeRange: timeRange,
        ),
      ),
    );
    return async.when(
      data: (segments) => DistributionChart(segments: segments),
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _ErrorCard(message: 'Failed to load chart: $e'),
    );
  }
}

class _TopNSection extends ConsumerWidget {
  const _TopNSection({
    required this.service,
    required this.config,
    required this.timeRange,
  });

  final String service;
  final TableConfig config;
  final AnalyticsTimeRange timeRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      serviceTopNProvider(
        ServiceTopNParams(service, config.metric,
            limit: config.limit, timeRange: timeRange),
      ),
    );
    return async.when(
      data: (items) => TopNList(items: items, title: config.label),
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _ErrorCard(message: 'Failed to load data: $e'),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
