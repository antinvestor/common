import 'package:flutter/material.dart';

/// Reusable entity list page with search bar, action button, item count,
/// and paginated item list with optional "Load More".
class EntityListPage<T> extends StatelessWidget {
  const EntityListPage({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.itemBuilder,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.searchHint,
    this.onSearchChanged,
    this.actionLabel,
    this.onAction,
    this.canAction = true,
    this.filterWidget,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    this.totalHint,
  });

  final String title;
  final IconData icon;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool canAction;
  final Widget? filterWidget;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final String? totalHint;

  /// Maximum content width to prevent stretching on ultra-wide screens.
  static const double _maxContentWidth = 1080.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Row(
                children: [
                  Icon(icon, size: 28, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (items.isNotEmpty)
                          Text(
                            totalHint ??
                                '${items.length} items${hasMore ? '+' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (actionLabel != null && canAction)
                    FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(actionLabel!),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Row(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: TextField(
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: searchHint ?? 'Search...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                      ),
                    ),
                  ),
                  if (filterWidget != null) ...[
                    const SizedBox(width: 12),
                    filterWidget!,
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth + 48),
              child: _buildContent(context, theme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(error!, style: theme.textTheme.bodyLarge),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 28,
                color: theme.colorScheme.primary.withAlpha(160),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No $title found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && canAction) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      );
    }

    final itemCount = items.length + (hasMore ? 1 : 0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            hasMore &&
            !isLoadingMore &&
            onLoadMore != null) {
          final metrics = notification.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 200) {
            onLoadMore!();
          }
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index < items.length) {
            return itemBuilder(context, items[index]);
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: isLoadingMore
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: onLoadMore,
                      child: const Text('Load More'),
                    ),
            ),
          );
        },
      ),
    );
  }
}
