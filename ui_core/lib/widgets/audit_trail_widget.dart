import 'package:flutter/material.dart';

/// Displays a single audit trail entry with who, what, when, why, and where.
class AuditTrailEntry extends StatelessWidget {
  const AuditTrailEntry({
    super.key,
    required this.action,
    required this.timestamp,
    this.performedBy,
    this.reason,
    this.location,
    this.coordinates,
    this.details,
    this.icon,
    this.color,
  });

  final String action; // "Approved", "Rejected", "Verified", etc.
  final String timestamp; // RFC3339 or display date
  final String? performedBy; // who did it
  final String? reason; // why
  final String? location; // where -- "Nairobi, Kenya"
  final String? coordinates; // lat,long if available
  final Map<String, String>? details; // additional context
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = color ?? theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: badgeColor.withValues(alpha: 0.1),
              child: Icon(icon ?? Icons.history, size: 18, color: badgeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // What + When
                  Text(
                    action,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timestamp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  // Who
                  if (performedBy != null && performedBy!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _iconRow(Icons.person_outline, 'By: $performedBy', theme),
                  ],

                  // Where -- location
                  if (location != null && location!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _iconRow(Icons.location_on_outlined, location!, theme),
                  ],

                  // Coordinates
                  if (coordinates != null && coordinates!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _iconRow(
                      Icons.gps_fixed,
                      coordinates!,
                      theme,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ],

                  // Why
                  if (reason != null && reason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notes_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Reason: $reason',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Extra details
                  if (details != null && details!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: details!.entries
                          .map(
                            (e) => Chip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                '${e.key}: ${e.value}',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconRow(
    IconData iconData,
    String text,
    ThemeData theme, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(
          iconData,
          size: 14,
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Displays a list of audit trail entries.
class AuditTrailList extends StatelessWidget {
  const AuditTrailList({
    super.key,
    required this.entries,
    this.title = 'Activity History',
  });

  final List<AuditTrailEntry> entries;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No activity recorded yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) => entries[index],
    );
  }
}
