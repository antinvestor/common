import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'analytics_models.dart';

/// A donut chart with legend for [DistributionSegment] data.
class DistributionChart extends StatelessWidget {
  const DistributionChart({
    super.key,
    required this.segments,
    this.height = 240,
    this.donutWidth = 32,
  });

  final List<DistributionSegment> segments;
  final double height;
  final double donutWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (segments.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }

    final total = segments.fold(0.0, (sum, s) => sum + s.value);
    final defaultColors = [
      cs.primary,
      cs.tertiary,
      cs.secondary,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
    ];

    final coloredSegments = [
      for (var i = 0; i < segments.length; i++)
        (
          segment: segments[i],
          color: segments[i].color ?? defaultColors[i % defaultColors.length],
        ),
    ];

    return SizedBox(
      height: height,
      child: Row(
        children: [
          // Donut
          Expanded(
            flex: 3,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: coloredSegments
                        .map((e) => (value: e.segment.value, color: e.color))
                        .toList(),
                    total: total,
                    strokeWidth: donutWidth,
                    backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTotal(total),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Total',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Legend
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in coloredSegments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: entry.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.segment.label,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.segment.percent(total).toStringAsFixed(1)}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTotal(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.total,
    required this.strokeWidth,
    required this.backgroundColor,
  });

  final List<({double value, Color color})> segments;
  final double total;
  final double strokeWidth;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = backgroundColor,
    );

    if (total <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    var startAngle = -math.pi / 2; // Start from top

    for (final seg in segments) {
      final sweep = (seg.value / total) * 2 * math.pi;
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt
          ..color = seg.color,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.segments != segments || old.total != total;
}
