import 'package:flutter/material.dart';

/// Trend direction for a metric compared to its previous period.
enum MetricTrend { up, down, flat }

/// Time granularity for bucketing time series data.
enum TimeGranularity { minute, hour, day, week, month, quarter, year }

/// A single KPI metric value (e.g., "Total Payments: 1,234").
class MetricValue {
  const MetricValue({
    required this.key,
    required this.label,
    required this.value,
    this.previousValue,
    this.unit,
    this.icon,
    this.trend,
  });

  final String key;
  final String label;
  final double value;
  final double? previousValue;

  /// Unit hint for formatting: "count", "currency", "percent", "bytes".
  final String? unit;

  final IconData? icon;
  final MetricTrend? trend;

  /// Percentage change from [previousValue] to [value].
  double? get changePercent => previousValue != null && previousValue != 0
      ? ((value - previousValue!) / previousValue!) * 100
      : null;
}

/// A single point in a time series.
class TimeSeriesPoint {
  const TimeSeriesPoint({
    required this.timestamp,
    required this.value,
    this.label,
  });

  final DateTime timestamp;
  final double value;
  final String? label;
}

/// A named time series with its data points.
class TimeSeries {
  const TimeSeries({
    required this.key,
    required this.label,
    required this.points,
    this.color,
  });

  final String key;
  final String label;
  final List<TimeSeriesPoint> points;
  final Color? color;
}

/// A segment in a distribution (pie/donut chart slice).
class DistributionSegment {
  const DistributionSegment({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final double value;
  final Color? color;

  /// Percentage of [total] that this segment represents.
  double percent(double total) => total > 0 ? (value / total) * 100 : 0;
}

/// A ranked item in a top-N list.
class TopNItem {
  const TopNItem({
    required this.label,
    required this.value,
    this.metadata,
  });

  final String label;
  final double value;
  final Map<String, String>? metadata;
}

/// Time range for analytics queries with optional granularity.
class AnalyticsTimeRange {
  const AnalyticsTimeRange({
    required this.start,
    required this.end,
    this.granularity,
  });

  final DateTime start;
  final DateTime end;
  final TimeGranularity? granularity;

  /// Last 24 hours with hourly granularity.
  factory AnalyticsTimeRange.last24Hours() {
    final now = DateTime.now();
    return AnalyticsTimeRange(
      start: now.subtract(const Duration(hours: 24)),
      end: now,
      granularity: TimeGranularity.hour,
    );
  }

  /// Last 7 days with daily granularity.
  factory AnalyticsTimeRange.last7Days() {
    final now = DateTime.now();
    return AnalyticsTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
      granularity: TimeGranularity.day,
    );
  }

  /// Last 30 days with daily granularity.
  factory AnalyticsTimeRange.last30Days() {
    final now = DateTime.now();
    return AnalyticsTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
      granularity: TimeGranularity.day,
    );
  }

  /// Last 90 days with weekly granularity.
  factory AnalyticsTimeRange.last90Days() {
    final now = DateTime.now();
    return AnalyticsTimeRange(
      start: now.subtract(const Duration(days: 90)),
      end: now,
      granularity: TimeGranularity.week,
    );
  }

  /// Last year with monthly granularity.
  factory AnalyticsTimeRange.lastYear() {
    final now = DateTime.now();
    return AnalyticsTimeRange(
      start: DateTime(now.year - 1, now.month, now.day),
      end: now,
      granularity: TimeGranularity.month,
    );
  }

  /// Duration of this time range.
  Duration get duration => end.difference(start);

  /// Query parameters for HTTP requests.
  Map<String, String> toQueryParams() => {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        if (granularity != null) 'granularity': granularity!.name,
      };
}
