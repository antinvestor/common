import 'package:flutter/material.dart';

import 'package:antinvestor_ui_core/responsive/breakpoints.dart';
import 'page_header.dart';

/// Data model for a KPI card on the service analytics page.
class ServiceKpi {
  const ServiceKpi({
    required this.label,
    required this.value,
    this.change,
    this.changePositive = true,
    this.icon,
  });

  final String label;
  final String value;
  final String? change;
  final bool changePositive;
  final IconData? icon;
}

/// Data model for a recent event entry.
class ServiceEvent {
  const ServiceEvent({
    required this.title,
    required this.timeAgo,
    this.icon,
    this.severity = EventSeverity.info,
  });

  final String title;
  final String timeAgo;
  final IconData? icon;
  final EventSeverity severity;
}

enum EventSeverity { info, warning, error, success }

/// A reusable service analytics dashboard page.
///
/// Layout:
/// - KPI cards row at top
/// - Main chart area + recent events side panel
/// - Optional bottom section (e.g., top performers table)
///
/// Services provide their data via constructor parameters.
class ServiceAnalyticsPage extends StatelessWidget {
  const ServiceAnalyticsPage({
    super.key,
    required this.title,
    required this.breadcrumbs,
    required this.kpis,
    this.chartWidget,
    this.chartTitle,
    this.chartSubtitle,
    this.events = const [],
    this.bottomSection,
    this.actions,
    this.onViewAllEvents,
  });

  final String title;
  final List<String> breadcrumbs;
  final List<ServiceKpi> kpis;
  final Widget? chartWidget;
  final String? chartTitle;
  final String? chartSubtitle;
  final List<ServiceEvent> events;
  final Widget? bottomSection;
  final List<Widget>? actions;
  final VoidCallback? onViewAllEvents;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = AppBreakpoints.isDesktop(width);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: title,
            breadcrumbs: breadcrumbs,
            actions: actions ?? [],
          ),
          const SizedBox(height: 20),
          // KPI cards
          _buildKpiRow(context, isDesktop),
          const SizedBox(height: 20),
          // Chart + Events
          if (isDesktop)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: _buildChartCard(context)),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: _buildEventsCard(context)),
                ],
              ),
            )
          else ...[
            _buildChartCard(context),
            const SizedBox(height: 20),
            _buildEventsCard(context),
          ],
          // Bottom section
          if (bottomSection != null) ...[
            const SizedBox(height: 20),
            bottomSection!,
          ],
        ],
      ),
    );
  }

  Widget _buildKpiRow(BuildContext context, bool isDesktop) {
    if (isDesktop) {
      final children = <Widget>[];
      for (var i = 0; i < kpis.length; i++) {
        if (i > 0) children.add(const SizedBox(width: 16));
        children.add(Expanded(child: _KpiCard(kpi: kpis[i])));
      }
      return Row(children: children);
    }
    return Column(
      children: kpis
          .map((kpi) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _KpiCard(kpi: kpi),
              ))
          .toList(),
    );
  }

  Widget _buildChartCard(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outlineVariant;
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chartTitle != null)
            Text(chartTitle!,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          if (chartSubtitle != null) ...[
            const SizedBox(height: 4),
            Text(chartSubtitle!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: mutedColor)),
          ],
          if (chartTitle != null || chartSubtitle != null)
            const SizedBox(height: 16),
          if (chartWidget != null)
            SizedBox(height: 240, child: chartWidget!)
          else
            SizedBox(
              height: 240,
              child: Center(
                child: Text('Chart placeholder',
                    style: TextStyle(color: mutedColor)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventsCard(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outlineVariant;
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Events',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No recent events',
                    style: TextStyle(color: mutedColor)),
              ),
            )
          else
            ...events.map((e) => _EventTile(event: e)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onViewAllEvents ?? () {},
            child: const Text('View All Audit Logs'),
          ),
        ],
      ),
    );
  }
}

// --- KPI Card ----------------------------------------------------------------

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final ServiceKpi kpi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outlineVariant;
    final accentColor = theme.colorScheme.tertiary;

    final changeColor = kpi.changePositive
        ? Colors.green.shade600
        : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (kpi.icon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(kpi.icon, size: 18, color: accentColor),
                ),
              const Spacer(),
              if (kpi.change != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      kpi.change!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(kpi.label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            kpi.value,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// --- Event Tile --------------------------------------------------------------

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final ServiceEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    final (color, icon) = switch (event.severity) {
      EventSeverity.info => (theme.colorScheme.primary, Icons.info_outline),
      EventSeverity.warning => (Colors.orange.shade600, Icons.warning_amber),
      EventSeverity.error => (theme.colorScheme.error, Icons.error_outline),
      EventSeverity.success =>
        (Colors.green.shade600, Icons.check_circle_outline),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(event.icon ?? icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500)),
                Text(event.timeAgo,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: mutedColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
