import 'package:antinvestor_api_common/antinvestor_api_common.dart';
import 'package:flutter/material.dart';

/// Displays a colored badge for entity state.
class StateBadge extends StatelessWidget {
  const StateBadge({super.key, required this.state});

  final STATE state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _stateInfo(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static (String, Color) _stateInfo(STATE state) {
    return switch (state) {
      STATE.CREATED => ('Created', Colors.blue),
      STATE.CHECKED => ('Checked', Colors.orange),
      STATE.ACTIVE => ('Active', Colors.green),
      STATE.INACTIVE => ('Inactive', Colors.grey),
      STATE.DELETED => ('Deleted', Colors.red),
      _ => ('Unknown', Colors.grey),
    };
  }
}

String stateLabel(STATE state) {
  return switch (state) {
    STATE.CREATED => 'Created',
    STATE.CHECKED => 'Checked',
    STATE.ACTIVE => 'Active',
    STATE.INACTIVE => 'Inactive',
    STATE.DELETED => 'Deleted',
    _ => 'Unknown',
  };
}
