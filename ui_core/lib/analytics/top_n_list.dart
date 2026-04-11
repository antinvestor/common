import 'package:flutter/material.dart';

import 'analytics_models.dart';
import 'metric_card.dart';

/// A ranked list of top-N items with value bars and optional metadata chips.
class TopNList extends StatelessWidget {
  const TopNList({
    super.key,
    required this.items,
    this.title,
    this.onViewAll,
  });

  final List<TopNItem> items;
  final String? title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('No data', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }

    final maxValue =
        items.fold(0.0, (m, item) => item.value > m ? item.value : m);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || onViewAll != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (onViewAll != null)
                    TextButton(
                      onPressed: onViewAll,
                      child: const Text('View All'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          ...List.generate(items.length, (i) {
            final item = items[i];
            final fraction = maxValue > 0 ? item.value / maxValue : 0.0;

            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Label + metadata
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        if (item.metadata != null &&
                            item.metadata!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Wrap(
                              spacing: 6,
                              children: item.metadata!.entries
                                  .map((e) => Chip(
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        labelPadding: EdgeInsets.zero,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                        label: Text('${e.key}: ${e.value}',
                                            style: theme.textTheme.labelSmall),
                                      ))
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Value bar
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatMetricValue(item.value, null),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 4,
                            backgroundColor:
                                cs.primary.withValues(alpha: 0.08),
                            valueColor:
                                AlwaysStoppedAnimation(cs.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
