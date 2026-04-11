import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable key-value metadata row with optional copy-to-clipboard.
///
/// Replaces the `_metadataRow` helper duplicated across detail screens.
///
/// ```dart
/// MetadataRow(label: 'ID', value: device.id)
/// MetadataRow(label: 'Email', value: user.email, copiable: true)
/// MetadataRow(label: 'Status', valueWidget: StatusBadge(status: s))
/// ```
class MetadataRow extends StatelessWidget {
  const MetadataRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.labelWidth = 120,
    this.copiable = false,
    this.padding = const EdgeInsets.only(bottom: 8),
  }) : assert(
          value != null || valueWidget != null,
          'Either value or valueWidget must be provided',
        );

  final String label;

  /// Plain text value. Hidden when empty.
  final String? value;

  /// Custom widget to display instead of a text value.
  final Widget? valueWidget;

  /// Width of the label column.
  final double labelWidth;

  /// Whether to show a copy icon that copies [value] to clipboard.
  final bool copiable;

  /// Outer padding. Defaults to bottom-8 for vertical stacking.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Hide row when value is empty and no custom widget is provided.
    if (valueWidget == null && (value == null || value!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: valueWidget ??
                Text(
                  value!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
          ),
          if (copiable && value != null && value!.isNotEmpty) ...[
            const SizedBox(width: 4),
            _CopyButton(text: value!),
          ],
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Copy',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              width: 200,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.copy_rounded,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
