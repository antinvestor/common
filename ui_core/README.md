# antinvestor_ui_core

Shared design system and infrastructure for Antinvestor service UIs. Provides the Stitch theme, admin widgets, analytics framework, permission system, and routing composition.

## Installation

```yaml
dependencies:
  antinvestor_ui_core: ^0.1.0
```

## Features

- **Theme**: Material 3 Stitch color scheme with Manrope/Inter typography (`AppTheme`)
- **Admin Widgets**: `AdminEntityListPage` with DataTable, CSV export, glassmorphic edit panels
- **Analytics**: Declarative `AnalyticsDashboard` with KPI cards, time-series/distribution charts, and top-N lists
- **Permissions**: `PermissionManifest`, `PermissionGuard`, batch checking support
- **Navigation**: `AppShell`, `AppSidebar`, `RouteModule` composition for host apps
- **Routing**: Abstract `RouteModule` base class for service UI packages
- **Widgets**: `StatusBadge`, `ProfileBadge`, `GradientButton`, `FormFieldCard`, `AmountDisplay`, `MetadataRow`, `Breadcrumb`, `PageHeader`, `SignaturePad`
- **Auth**: Token management, role guards, tenancy context, audit context
- **API**: Paginated streams, Connect RPC helpers
- **Responsive**: Breakpoint system and `ResponsiveLayout`

## Usage

```dart
import 'package:antinvestor_ui_core/antinvestor_ui_core.dart';

// Apply the Stitch theme
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
);

// Declarative analytics dashboard
AnalyticsDashboard(
  service: 'payment',
  title: 'Payment Analytics',
  metrics: ['total_payments', 'total_volume'],
  charts: [ChartConfig.timeSeries('volume', label: 'Volume')],
);

// Permission-guarded action
PermissionGuard(
  permissions: {'payment_send'},
  child: FilledButton(onPressed: send, child: Text('Send')),
);

// Compose service modules into your app
final modules = [ProfileRouteModule(), PaymentRouteModule()];
ShellRoute(
  routes: [...ownRoutes, for (final m in modules) ...m.buildRoutes()],
);
```

## Architecture

All service UI packages (`antinvestor_ui_profile`, `antinvestor_ui_payment`, etc.) depend on this package and extend `RouteModule` to provide routes, navigation items, and permission manifests to the host application.
