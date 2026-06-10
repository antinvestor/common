import 'package:flutter/material.dart';

import 'analytics_models.dart';

/// Preset time range options.
enum TimeRangePreset {
  last24h('24h'),
  last7d('7d'),
  last30d('30d'),
  last90d('90d'),
  lastYear('1y'),
  custom('Custom');

  const TimeRangePreset(this.label);
  final String label;
}

/// A compact time range selector with preset buttons and custom date picker.
class TimeRangeSelector extends StatefulWidget {
  const TimeRangeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.initialPreset = TimeRangePreset.last30d,
  });

  final AnalyticsTimeRange value;
  final ValueChanged<AnalyticsTimeRange> onChanged;
  final TimeRangePreset initialPreset;

  @override
  State<TimeRangeSelector> createState() => _TimeRangeSelectorState();
}

class _TimeRangeSelectorState extends State<TimeRangeSelector> {
  late TimeRangePreset _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialPreset;
  }

  AnalyticsTimeRange _rangeForPreset(TimeRangePreset preset) {
    return switch (preset) {
      TimeRangePreset.last24h => AnalyticsTimeRange.last24Hours(),
      TimeRangePreset.last7d => AnalyticsTimeRange.last7Days(),
      TimeRangePreset.last30d => AnalyticsTimeRange.last30Days(),
      TimeRangePreset.last90d => AnalyticsTimeRange.last90Days(),
      TimeRangePreset.lastYear => AnalyticsTimeRange.lastYear(),
      TimeRangePreset.custom => widget.value, // keep current
    };
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: widget.value.start,
        end: widget.value.end,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selected = TimeRangePreset.custom);
      widget.onChanged(
        AnalyticsTimeRange(
          start: picked.start,
          end: picked.end,
          granularity: _inferGranularity(picked.duration),
        ),
      );
    }
  }

  TimeGranularity _inferGranularity(Duration d) {
    if (d.inDays > 365) return TimeGranularity.month;
    if (d.inDays > 90) return TimeGranularity.week;
    if (d.inDays > 7) return TimeGranularity.day;
    if (d.inDays > 1) return TimeGranularity.hour;
    return TimeGranularity.minute;
  }

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TimeRangePreset>(
      segments: [
        for (final preset in TimeRangePreset.values)
          ButtonSegment(value: preset, label: Text(preset.label)),
      ],
      selected: {_selected},
      onSelectionChanged: (selected) {
        final preset = selected.first;
        if (preset == TimeRangePreset.custom) {
          _pickCustomRange();
        } else {
          setState(() => _selected = preset);
          widget.onChanged(_rangeForPreset(preset));
        }
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
