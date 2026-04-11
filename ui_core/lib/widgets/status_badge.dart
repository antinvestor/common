import 'package:flutter/material.dart';

/// A generic colored status badge that can be used with any enum or string.
///
/// Usage with an enum:
/// ```dart
/// StatusBadge.fromEnum(
///   value: PaymentState.completed,
///   mapper: (state) => switch (state) {
///     PaymentState.pending => ('Pending', Colors.orange, null),
///     PaymentState.completed => ('Completed', Colors.green, null),
///     PaymentState.failed => ('Failed', Colors.red, null),
///   },
/// )
/// ```
///
/// Usage with a string:
/// ```dart
/// StatusBadge(label: 'Active', color: Colors.green)
/// ```
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  /// Create a badge from any value using a mapper function.
  static StatusBadge fromEnum<T>({
    Key? key,
    required T value,
    required (String label, Color color, IconData? icon) Function(T) mapper,
  }) {
    final (label, color, icon) = mapper(value);
    return StatusBadge(key: key, label: label, color: color, icon: icon);
  }

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
