import 'dart:convert';

import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
import 'package:antinvestor_ui_core/analytics/analytics_provider.dart';
import 'package:antinvestor_ui_core/analytics/service_analytics_spec.dart';
import 'package:antinvestor_ui_core/analytics/thesa_analytics_data_source.dart';
import 'package:antinvestor_ui_core/analytics/time_series_chart.dart';
import 'package:antinvestor_ui_core/analytics/top_n_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const spec = ServiceAnalyticsSpec(
  service: 'payment',
  baseFilters: {'service': 'payment'},
  kpis: [
    KpiSpec(
      'total',
      label: 'Total Payments',
      metric: 'payment_transactions_total',
      unit: 'count',
    ),
  ],
  charts: [
    ChartConfig.timeSeries(
      'payment_transactions_total',
      label: 'Payment Volume',
    ),
  ],
  tables: [
    TableConfig.topN(
      'payment_transactions_total',
      label: 'Top Recipients',
      groupBy: 'recipient',
    ),
  ],
);

http.Response _ok(Object payload) => http.Response(
  json.encode(payload),
  200,
  headers: {'content-type': 'application/json'},
);

/// Routes each analytics endpoint to a canned successful payload.
Future<http.Response> _happyTransport(String path, {Object? body}) async {
  switch (path) {
    case '/api/analytics/query/scalar':
      return _ok({'value': 1234});
    case '/api/analytics/query/timeseries':
      return _ok({
        'points': [
          {'timestamp': '2026-06-01T00:00:00Z', 'value': 10},
          {'timestamp': '2026-06-02T00:00:00Z', 'value': 20},
          {'timestamp': '2026-06-03T00:00:00Z', 'value': 15},
        ],
      });
    case '/api/analytics/query/topn':
      return _ok({
        'items': [
          {'label': 'M-Pesa Till 5512', 'value': 420},
        ],
      });
    default:
      return http.Response('{"error":"unexpected path"}', 404);
  }
}

Future<http.Response> _failingTransport(String path, {Object? body}) async =>
    http.Response('{"error":"internal server error"}', 500);

Widget _dashboard(ThesaAnalyticsDataSource source) {
  return ProviderScope(
    overrides: [analyticsDataSourceProvider.overrideWithValue(source)],
    child: MaterialApp(
      home: Scaffold(
        body: AnalyticsDashboard(
          service: spec.service,
          title: 'Payments',
          metrics: spec.metricKeys,
          charts: spec.charts,
          tables: spec.tables,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders KPIs, chart, and top-N from the thesa data source', (
    tester,
  ) async {
    final source = ThesaAnalyticsDataSource(
      _happyTransport,
      specs: const [spec],
    );

    await tester.pumpWidget(_dashboard(source));

    // Loading state first: chart placeholder spinner, no KPI value yet.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('1.2K'), findsNothing);

    await tester.pumpAndSettle();

    // KPI card rendered from the scalar query (1234 -> "1.2K").
    expect(find.text('Total Payments'), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);

    // Time series chart rendered with its configured label and data.
    // The label appears twice: section header + chart legend entry.
    expect(find.text('Payment Volume'), findsNWidgets(2));
    final chart = tester.widget<TimeSeriesChart>(find.byType(TimeSeriesChart));
    expect(chart.series.single.points, hasLength(3));

    // Top-N table rendered with its item.
    expect(find.byType(TopNList), findsOneWidget);
    expect(find.text('Top Recipients'), findsOneWidget);
    expect(find.text('M-Pesa Till 5512'), findsOneWidget);

    // No error cards anywhere.
    expect(find.textContaining('Failed to load'), findsNothing);
  });

  testWidgets('renders error cards when the analytics API fails', (
    tester,
  ) async {
    final source = ThesaAnalyticsDataSource(
      _failingTransport,
      specs: const [spec],
    );

    await tester.pumpWidget(_dashboard(source));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load metrics'), findsOneWidget);
    expect(find.textContaining('Failed to load chart'), findsOneWidget);
    expect(find.textContaining('Failed to load data'), findsOneWidget);
    expect(find.text('1.2K'), findsNothing);
  });

  testWidgets('renders empty chart state when the API returns no points', (
    tester,
  ) async {
    Future<http.Response> emptyTransport(String path, {Object? body}) async {
      switch (path) {
        case '/api/analytics/query/scalar':
          return _ok({'value': 0});
        case '/api/analytics/query/topn':
          return _ok({'items': <Object>[]});
        default:
          return _ok({'points': <Object>[]});
      }
    }

    final source = ThesaAnalyticsDataSource(
      emptyTransport,
      specs: const [spec],
    );

    await tester.pumpWidget(_dashboard(source));
    await tester.pumpAndSettle();

    expect(find.text('No data'), findsWidgets);
    expect(find.textContaining('Failed to load'), findsNothing);
  });
}
