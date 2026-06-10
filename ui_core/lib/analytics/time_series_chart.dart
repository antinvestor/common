import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'analytics_models.dart';

/// Display mode for the time series chart.
enum ChartMode { line, bar }

/// A time series line/bar chart rendered with [CustomPaint].
///
/// Supports multiple overlaid series, granularity-aware axis labels,
/// hover tooltips, and toggling between line and bar modes.
class TimeSeriesChart extends StatefulWidget {
  const TimeSeriesChart({
    super.key,
    required this.series,
    this.height = 240,
    this.mode = ChartMode.line,
    this.showModeToggle = true,
    this.granularity,
  });

  final List<TimeSeries> series;
  final double height;
  final ChartMode mode;
  final bool showModeToggle;
  final TimeGranularity? granularity;

  @override
  State<TimeSeriesChart> createState() => _TimeSeriesChartState();
}

class _TimeSeriesChartState extends State<TimeSeriesChart> {
  late ChartMode _mode;
  Offset? _hoverPos;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
  }

  @override
  void didUpdateWidget(covariant TimeSeriesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode) _mode = widget.mode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (widget.series.isEmpty || widget.series.every((s) => s.points.isEmpty)) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text('No data', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }

    final defaultColors = [
      cs.primary,
      cs.tertiary,
      cs.secondary,
      Colors.orange,
      Colors.teal,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Legend + mode toggle
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < widget.series.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color:
                                widget.series[i].color ??
                                defaultColors[i % defaultColors.length],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.series[i].label,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (widget.showModeToggle)
              SegmentedButton<ChartMode>(
                segments: const [
                  ButtonSegment(
                    value: ChartMode.line,
                    icon: Icon(Icons.show_chart, size: 16),
                  ),
                  ButtonSegment(
                    value: ChartMode.bar,
                    icon: Icon(Icons.bar_chart, size: 16),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Chart
        MouseRegion(
          onHover: (e) => setState(() => _hoverPos = e.localPosition),
          onExit: (_) => setState(() => _hoverPos = null),
          child: SizedBox(
            height: widget.height,
            child: CustomPaint(
              size: Size.infinite,
              painter: _TimeSeriesPainter(
                series: widget.series,
                mode: _mode,
                defaultColors: defaultColors,
                granularity: widget.granularity,
                hoverX: _hoverPos?.dx,
                textColor: cs.onSurfaceVariant,
                gridColor: cs.outlineVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeSeriesPainter extends CustomPainter {
  _TimeSeriesPainter({
    required this.series,
    required this.mode,
    required this.defaultColors,
    this.granularity,
    this.hoverX,
    required this.textColor,
    required this.gridColor,
  });

  final List<TimeSeries> series;
  final ChartMode mode;
  final List<Color> defaultColors;
  final TimeGranularity? granularity;
  final double? hoverX;
  final Color textColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 48.0;
    const bottomPad = 28.0;
    const topPad = 8.0;
    const rightPad = 16.0;

    final chartRect = Rect.fromLTRB(
      leftPad,
      topPad,
      size.width - rightPad,
      size.height - bottomPad,
    );

    // Compute global min/max across all series
    DateTime? minTime, maxTime;
    double minVal = double.infinity, maxVal = double.negativeInfinity;

    for (final s in series) {
      for (final p in s.points) {
        if (minTime == null || p.timestamp.isBefore(minTime)) {
          minTime = p.timestamp;
        }
        if (maxTime == null || p.timestamp.isAfter(maxTime)) {
          maxTime = p.timestamp;
        }
        if (p.value < minVal) minVal = p.value;
        if (p.value > maxVal) maxVal = p.value;
      }
    }

    if (minTime == null || maxTime == null) return;

    // Add padding to value range
    if (minVal == maxVal) {
      minVal = minVal - 1;
      maxVal = maxVal + 1;
    }
    final valPad = (maxVal - minVal) * 0.1;
    minVal = math.max(0, minVal - valPad);
    maxVal += valPad;

    final timeSpan = maxTime.difference(minTime).inMilliseconds.toDouble();
    if (timeSpan == 0) return;

    double xForTime(DateTime t) {
      final frac = t.difference(minTime!).inMilliseconds / timeSpan;
      return chartRect.left + frac * chartRect.width;
    }

    double yForValue(double v) {
      final frac = (v - minVal) / (maxVal - minVal);
      return chartRect.bottom - frac * chartRect.height;
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    const gridLines = 4;
    for (var i = 0; i <= gridLines; i++) {
      final y = chartRect.top + (chartRect.height / gridLines) * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      // Y-axis label
      final val = maxVal - ((maxVal - minVal) / gridLines) * i;
      final tp = TextPainter(
        text: TextSpan(
          text: _formatAxisValue(val),
          style: TextStyle(color: textColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(chartRect.left - tp.width - 4, y - tp.height / 2),
      );
    }

    // Draw series
    for (var si = 0; si < series.length; si++) {
      final s = series[si];
      if (s.points.isEmpty) continue;
      final color = s.color ?? defaultColors[si % defaultColors.length];
      final sorted = [...s.points]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (mode == ChartMode.line) {
        _drawLineSeries(canvas, chartRect, sorted, color, xForTime, yForValue);
      } else {
        _drawBarSeries(
          canvas,
          chartRect,
          sorted,
          color,
          xForTime,
          yForValue,
          si,
          series.length,
        );
      }
    }

    // X-axis labels
    _drawXLabels(canvas, chartRect, minTime, maxTime, textColor);

    // Hover line
    if (hoverX != null &&
        hoverX! >= chartRect.left &&
        hoverX! <= chartRect.right) {
      final hoverPaint = Paint()
        ..color = textColor.withValues(alpha: 0.3)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(hoverX!, chartRect.top),
        Offset(hoverX!, chartRect.bottom),
        hoverPaint,
      );
    }
  }

  void _drawLineSeries(
    Canvas canvas,
    Rect rect,
    List<TimeSeriesPoint> points,
    Color color,
    double Function(DateTime) xFor,
    double Function(double) yFor,
  ) {
    if (points.length < 2) {
      // Single point: draw a dot
      if (points.isNotEmpty) {
        final p = points.first;
        canvas.drawCircle(
          Offset(xFor(p.timestamp), yFor(p.value)),
          4,
          Paint()..color = color,
        );
      }
      return;
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(xFor(points.first.timestamp), yFor(points.first.value));
    for (var i = 1; i < points.length; i++) {
      path.lineTo(xFor(points[i].timestamp), yFor(points[i].value));
    }
    canvas.drawPath(path, linePaint);

    // Fill area under line
    final fillPath = Path.from(path)
      ..lineTo(xFor(points.last.timestamp), rect.bottom)
      ..lineTo(xFor(points.first.timestamp), rect.bottom)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = color.withValues(alpha: 0.08));

    // Dots
    for (final p in points) {
      canvas.drawCircle(
        Offset(xFor(p.timestamp), yFor(p.value)),
        3,
        Paint()..color = color,
      );
    }
  }

  void _drawBarSeries(
    Canvas canvas,
    Rect rect,
    List<TimeSeriesPoint> points,
    Color color,
    double Function(DateTime) xFor,
    double Function(double) yFor,
    int seriesIndex,
    int seriesCount,
  ) {
    if (points.isEmpty) return;

    final maxBarWidth =
        rect.width / (points.length * seriesCount + points.length);
    final barWidth = maxBarWidth.clamp(2.0, 24.0);
    final barPaint = Paint()..color = color;

    for (final p in points) {
      final cx = xFor(p.timestamp) + (seriesIndex - seriesCount / 2) * barWidth;
      final top = yFor(p.value);
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - barWidth / 2, top, cx + barWidth / 2, rect.bottom),
        const Radius.circular(2),
      );
      canvas.drawRRect(barRect, barPaint);
    }
  }

  void _drawXLabels(
    Canvas canvas,
    Rect rect,
    DateTime minTime,
    DateTime maxTime,
    Color color,
  ) {
    const labelCount = 5;
    final span = maxTime.difference(minTime);

    for (var i = 0; i <= labelCount; i++) {
      final t = minTime.add(
        Duration(milliseconds: (span.inMilliseconds * i / labelCount).round()),
      );
      final x = rect.left + (rect.width * i / labelCount);

      final label = _formatTimeLabel(t);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: color, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, rect.bottom + 6));
    }
  }

  String _formatTimeLabel(DateTime t) {
    switch (granularity) {
      case TimeGranularity.minute:
      case TimeGranularity.hour:
        return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      case TimeGranularity.day:
      case TimeGranularity.week:
        return '${t.day}/${t.month}';
      case TimeGranularity.month:
      case TimeGranularity.quarter:
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return months[t.month - 1];
      case TimeGranularity.year:
        return '${t.year}';
      case null:
        return '${t.day}/${t.month}';
    }
  }

  String _formatAxisValue(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant _TimeSeriesPainter old) =>
      old.hoverX != hoverX || old.series != series || old.mode != mode;
}
