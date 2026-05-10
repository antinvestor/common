import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:antinvestor_ui_core/navigation/nav_items.dart';
import 'package:antinvestor_ui_core/navigation/nav_state.dart';

// ---------------------------------------------------------------------------
// Configuration models
// ---------------------------------------------------------------------------

class SidebarConfig {
  const SidebarConfig({
    this.brandName = 'AntInvestor',
    this.brandSubtitle = 'Platform',
    this.brandIcon = Icons.account_balance,
    this.tenancyWidget,
  });

  final String brandName;
  final String brandSubtitle;
  final IconData brandIcon;
  final Widget? tenancyWidget;
}

class UserInfo {
  const UserInfo({this.displayName, this.profileId});

  final String? displayName;
  final String? profileId;
}

// ---------------------------------------------------------------------------
// Providers – host apps override these with ProviderScope.overrides
// ---------------------------------------------------------------------------

final sidebarConfigProvider = Provider<SidebarConfig>(
  (ref) => const SidebarConfig(),
);

final sidebarNavItemsProvider = FutureProvider<List<NavItem>>(
  (ref) async => [],
);

final currentUserInfoProvider = FutureProvider<UserInfo>(
  (ref) async => const UserInfo(),
);

// ---------------------------------------------------------------------------
// AppSidebar
// ---------------------------------------------------------------------------

class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.currentRoute,
    this.onNavigate,
    this.isDrawer = false,
  });

  final String currentRoute;
  final VoidCallback? onNavigate;
  final bool isDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(sidebarConfigProvider);
    final navItemsAsync = ref.watch(sidebarNavItemsProvider);
    final expansionState = ref.watch(sidebarExpansionProvider);

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _BrandHeader(config: config),
          if (config.tenancyWidget != null) config.tenancyWidget!,
          const Divider(height: 1),
          Expanded(
            child: navItemsAsync.when(
              data: (items) => _NavList(
                items: items,
                currentRoute: currentRoute,
                expansionState: expansionState,
                onNavigate: onNavigate,
                isDrawer: isDrawer,
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Center(
                child: Text('Error loading nav: $e'),
              ),
            ),
          ),
          const Divider(height: 1),
          _UserFooter(onNavigate: onNavigate),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _BrandHeader
// ---------------------------------------------------------------------------

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.config});

  final SidebarConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Icon(config.brandIcon, size: 32, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.brandName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  config.brandSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NavList
// ---------------------------------------------------------------------------

class _NavList extends StatelessWidget {
  const _NavList({
    required this.items,
    required this.currentRoute,
    required this.expansionState,
    this.onNavigate,
    this.isDrawer = false,
  });

  final List<NavItem> items;
  final String currentRoute;
  final SidebarExpansionState expansionState;
  final VoidCallback? onNavigate;
  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final item in items)
          if (item.hasChildren)
            _SectionTile(
              item: item,
              currentRoute: currentRoute,
              expansionState: expansionState,
              onNavigate: onNavigate,
              isDrawer: isDrawer,
            )
          else
            _LeafTile(
              item: item,
              currentRoute: currentRoute,
              onNavigate: onNavigate,
              isDrawer: isDrawer,
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _SectionTile
// ---------------------------------------------------------------------------

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.item,
    required this.currentRoute,
    required this.expansionState,
    this.onNavigate,
    this.isDrawer = false,
  });

  final NavItem item;
  final String currentRoute;
  final SidebarExpansionState expansionState;
  final VoidCallback? onNavigate;
  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    final isExpanded = expansionState.isExpanded(item.id);
    final isActive = item.matchesRoute(currentRoute);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Icon(
            isActive ? (item.activeIcon ?? item.icon) : item.icon,
            color: isActive ? theme.colorScheme.primary : null,
          ),
          title: Text(
            item.label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? theme.colorScheme.primary : null,
            ),
          ),
          trailing: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
          ),
          onTap: () => expansionState.toggle(item.id),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: [
                for (final child in item.children)
                  _LeafTile(
                    item: child,
                    currentRoute: currentRoute,
                    onNavigate: onNavigate,
                    isDrawer: isDrawer,
                    indent: true,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _LeafTile
// ---------------------------------------------------------------------------

class _LeafTile extends StatelessWidget {
  const _LeafTile({
    required this.item,
    required this.currentRoute,
    this.onNavigate,
    this.isDrawer = false,
    this.indent = false,
  });

  final NavItem item;
  final String currentRoute;
  final VoidCallback? onNavigate;
  final bool isDrawer;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final isActive =
        item.route != null && currentRoute.startsWith(item.route!);
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.only(left: indent ? 28 : 16, right: 16),
      leading: Icon(
        isActive ? (item.activeIcon ?? item.icon) : item.icon,
        color: isActive ? theme.colorScheme.primary : null,
        size: 20,
      ),
      title: Text(
        item.label,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: isActive ? theme.colorScheme.primary : null,
          fontSize: 14,
        ),
      ),
      trailing: item.badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.badge!,
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 11,
                ),
              ),
            )
          : null,
      selected: isActive,
      onTap: () {
        if (item.route != null) {
          context.go(item.route!);
          onNavigate?.call();
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _UserFooter
// ---------------------------------------------------------------------------

class _UserFooter extends ConsumerWidget {
  const _UserFooter({this.onNavigate});

  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userInfoAsync = ref.watch(currentUserInfoProvider);
    final theme = Theme.of(context);

    return userInfoAsync.when(
      data: (userInfo) {
        final displayName = userInfo.displayName ?? 'User';
        final profileId = userInfo.profileId ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  displayName.isNotEmpty
                      ? displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profileId.isNotEmpty)
                      Text(
                        profileId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
