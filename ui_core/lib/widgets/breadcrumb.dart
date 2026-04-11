import 'package:flutter/material.dart';

class Breadcrumb extends StatelessWidget {
  const Breadcrumb({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final activeColor = theme.colorScheme.onSurface;

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '/',
                style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
              ),
            ),
          Text(
            items[i],
            style: theme.textTheme.bodySmall?.copyWith(
              color: i == items.length - 1 ? activeColor : mutedColor,
              fontWeight:
                  i == items.length - 1 ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}
