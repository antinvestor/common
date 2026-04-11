import 'package:flutter/material.dart';

import '../responsive/breakpoints.dart';
import 'analytics_models.dart';
import 'metric_card.dart';

/// A responsive row/grid of [MetricCard] widgets.
///
/// Desktop: 4 across, tablet: 2 across, mobile: 1 column.
/// Shows skeleton placeholders when [isLoading] is true.
class MetricsRow extends StatelessWidget {
  const MetricsRow({
    super.key,
    required this.metrics,
    this.isLoading = false,
    this.skeletonCount = 4,
  });

  final List<MetricValue> metrics;
  final bool isLoading;
  final int skeletonCount;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final int crossAxisCount;
    if (AppBreakpoints.isDesktop(width)) {
      crossAxisCount = 4;
    } else if (AppBreakpoints.isTablet(width)) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
    }

    final compact = AppBreakpoints.isMobile(width);
    final items = isLoading
        ? List.generate(skeletonCount, (_) => null)
        : metrics.map((m) => m as MetricValue?).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final totalSpacing = spacing * (crossAxisCount - 1);
        final itemWidth =
            (constraints.maxWidth - totalSpacing) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((metric) {
            return SizedBox(
              width: crossAxisCount == 1
                  ? constraints.maxWidth
                  : itemWidth.clamp(0, constraints.maxWidth),
              child: metric != null
                  ? MetricCard(metric: metric, compact: compact)
                  : _MetricSkeleton(compact: compact),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Skeleton placeholder matching [MetricCard] dimensions.
class _MetricSkeleton extends StatelessWidget {
  const _MetricSkeleton({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shimmer = cs.onSurface.withValues(alpha: 0.06);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 26 : 34,
                height: compact ? 26 : 34,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const Spacer(),
              Container(
                width: 48,
                height: 20,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          Container(
            width: 80,
            height: 14,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 120,
            height: compact ? 22 : 28,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
