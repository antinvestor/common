import 'package:flutter/material.dart';

import 'analytics_models.dart';

/// Formats a [MetricValue] for display based on its unit.
String formatMetricValue(double value, String? unit) {
  switch (unit) {
    case 'currency':
      if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}B';
      if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
      if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
      return value.toStringAsFixed(2);
    case 'percent':
      return '${value.toStringAsFixed(1)}%';
    case 'bytes':
      if (value >= 1e12) return '${(value / 1e12).toStringAsFixed(1)} TB';
      if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)} GB';
      if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)} MB';
      if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)} KB';
      return '${value.toInt()} B';
    case 'count':
    default:
      if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}B';
      if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
      if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
      if (value == value.roundToDouble()) return value.toInt().toString();
      return value.toStringAsFixed(1);
  }
}

/// A single KPI card showing label, formatted value, trend arrow, and change.
class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.metric, this.compact = false});

  final MetricValue metric;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final trendColor = switch (metric.trend) {
      MetricTrend.up => Colors.green.shade600,
      MetricTrend.down => cs.error,
      MetricTrend.flat || null => cs.onSurfaceVariant,
    };
    final trendIcon = switch (metric.trend) {
      MetricTrend.up => Icons.trending_up,
      MetricTrend.down => Icons.trending_down,
      MetricTrend.flat || null => Icons.trending_flat,
    };

    final changePercent = metric.changePercent;
    final formattedValue = formatMetricValue(metric.value, metric.unit);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (metric.icon != null)
                Container(
                  padding: EdgeInsets.all(compact ? 6 : 8),
                  decoration: BoxDecoration(
                    color: cs.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    metric.icon,
                    size: compact ? 14 : 18,
                    color: cs.tertiary,
                  ),
                ),
              const Spacer(),
              if (changePercent != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(trendIcon, size: 12, color: trendColor),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '${changePercent.abs().toStringAsFixed(1)}%',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: trendColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            metric.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formattedValue,
            style:
                (compact
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineMedium)
                    ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
