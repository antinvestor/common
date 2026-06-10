import 'dart:convert';

import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:antinvestor_ui_core/analytics/service_analytics_spec.dart';
import 'package:antinvestor_ui_core/analytics/thesa_analytics_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// A transport call recorded with its decoded JSON body.
class RecordedRequest {
  RecordedRequest(this.path, this.body);
  final String path;
  final Map<String, dynamic> body;
}

/// Records every request and answers via a per-test handler.
class MockTransport {
  MockTransport(this.handler);

  final http.Response Function(String path, Map<String, dynamic> body) handler;
  final List<RecordedRequest> requests = [];

  Future<http.Response> call(String path, {Object? body}) async {
    final decoded = json.decode(body! as String) as Map<String, dynamic>;
    requests.add(RecordedRequest(path, decoded));
    return handler(path, decoded);
  }
}

http.Response ok(Object payload) => http.Response(
  json.encode(payload),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response apiError(int status, String message) => http.Response(
  json.encode({'error': message}),
  status,
  headers: {'content-type': 'application/json'},
);

final fixedRange = AnalyticsTimeRange(
  start: DateTime.utc(2026, 6, 1),
  end: DateTime.utc(2026, 6, 8),
  granularity: TimeGranularity.day,
);

const fixedRangeJson = {
  'start': '2026-06-01T00:00:00.000Z',
  'end': '2026-06-08T00:00:00.000Z',
};

const paymentSpec = ServiceAnalyticsSpec(
  service: 'payment',
  baseFilters: {'service': 'payment'},
  kpis: [
    KpiSpec(
      'total',
      label: 'Total Payments',
      metric: 'payment_transactions_total',
      filters: {'status': 'success'},
      unit: 'count',
    ),
    KpiSpec(
      'avg_amount',
      label: 'Average Amount',
      metric: 'payment_amount',
      aggregation: AnalyticsAggregation.avg,
      unit: 'currency',
    ),
  ],
  charts: [
    ChartConfig.timeSeries(
      'payment_transactions_total',
      label: 'Payment Volume',
      granularity: TimeGranularity.hour,
      aggregation: AnalyticsAggregation.count,
      filters: {'channel': 'mobile'},
    ),
    ChartConfig.distribution(
      'payment_transactions_total',
      label: 'By Route',
      groupBy: 'route',
      aggregation: AnalyticsAggregation.avg,
      filters: {'region': 'east'},
    ),
  ],
  tables: [
    TableConfig.topN(
      'payment_transactions_total',
      label: 'Top Recipients',
      groupBy: 'recipient',
      aggregation: AnalyticsAggregation.countDistinct,
      filters: {'kind': 'p2p'},
    ),
  ],
);

void main() {
  group('scalar queries (getMetrics)', () {
    test('sends exact path and JSON body per KPI and parses values', () async {
      final transport = MockTransport((path, body) {
        return body['metric'] == 'payment_transactions_total'
            ? ok({'value': 1234})
            : ok({'value': 56.5});
      });
      final source = ThesaAnalyticsDataSource(
        transport.call,
        specs: const [paymentSpec],
      );

      final metrics = await source.getMetrics('payment', timeRange: fixedRange);

      expect(transport.requests, hasLength(2));
      expect(transport.requests.map((r) => r.path).toSet(), {
        '/api/analytics/query/scalar',
      });
      expect(transport.requests[0].body, {
        'metric': 'payment_transactions_total',
        'aggregation': 'sum',
        'filters': {'service': 'payment', 'status': 'success'},
        'time_range': fixedRangeJson,
      });
      expect(transport.requests[1].body, {
        'metric': 'payment_amount',
        'aggregation': 'avg',
        'filters': {'service': 'payment'},
        'time_range': fixedRangeJson,
      });

      expect(metrics, hasLength(2));
      expect(metrics[0].key, 'total');
      expect(metrics[0].label, 'Total Payments');
      expect(metrics[0].value, 1234.0);
      expect(metrics[0].unit, 'count');
      expect(metrics[1].key, 'avg_amount');
      expect(metrics[1].value, 56.5);
      expect(metrics[1].unit, 'currency');
    });

    test('omits time_range when no range is given', () async {
      final transport = MockTransport((_, _) => ok({'value': 1}));
      final source = ThesaAnalyticsDataSource(
        transport.call,
        specs: const [paymentSpec],
      );

      await source.getMetrics('payment');

      expect(transport.requests.first.body.containsKey('time_range'), isFalse);
      expect(transport.requests.first.body.containsKey('step'), isFalse);
    });

    test('returns empty list without requests for unknown service', () async {
      final transport = MockTransport((_, _) => ok({'value': 1}));
      final source = ThesaAnalyticsDataSource(transport.call);

      final metrics = await source.getMetrics('unknown');

      expect(metrics, isEmpty);
      expect(transport.requests, isEmpty);
    });

    test('integer and double values both parse to double', () async {
      final transport = MockTransport((_, _) => ok({'value': 7}));
      final source = ThesaAnalyticsDataSource(transport.call);

      final value = await source.queryScalar(metric: 'm');

      expect(value, isA<double>());
      expect(value, 7.0);
    });
  });

  group('timeseries queries', () {
    test('sends exact body with step and parses ISO timestamps', () async {
      final transport = MockTransport(
        (_, _) => ok({
          'points': [
            {'timestamp': '2026-06-01T00:00:00Z', 'value': 10},
            {'timestamp': '2026-06-02T00:00:00Z', 'value': 12.5},
            {
              'timestamp': '2026-06-03T00:00:00Z',
              'value': 0,
              'label': 'holiday',
            },
          ],
        }),
      );
      final source = ThesaAnalyticsDataSource(transport.call);

      final points = await source.queryTimeSeries(
        metric: 'payment_transactions_total',
        filters: {'status': 'success'},
        timeRange: fixedRange,
      );

      expect(transport.requests.single.path, '/api/analytics/query/timeseries');
      expect(transport.requests.single.body, {
        'metric': 'payment_transactions_total',
        'aggregation': 'sum',
        'filters': {'status': 'success'},
        'time_range': fixedRangeJson,
        'step': 'day',
      });

      expect(points, hasLength(3));
      expect(points[0].timestamp, DateTime.utc(2026, 6, 1));
      expect(points[0].value, 10.0);
      expect(points[0].label, isNull);
      expect(points[1].value, 12.5);
      expect(points[2].label, 'holiday');
    });

    test('getTimeSeries applies chart spec: label, aggregation, filters, '
        'granularity override', () async {
      final transport = MockTransport((_, _) => ok({'points': []}));
      final source = ThesaAnalyticsDataSource(
        transport.call,
        specs: const [paymentSpec],
      );

      final series = await source.getTimeSeries(
        'payment',
        'payment_transactions_total',
        timeRange: fixedRange,
      );

      expect(transport.requests.single.body, {
        'metric': 'payment_transactions_total',
        'aggregation': 'count',
        'filters': {'service': 'payment', 'channel': 'mobile'},
        'time_range': fixedRangeJson,
        // Chart granularity (hour) wins over the range granularity (day).
        'step': 'hour',
      });
      expect(series.single.key, 'payment_transactions_total');
      expect(series.single.label, 'Payment Volume');
      expect(series.single.points, isEmpty);
    });

    test(
      'falls back to metric name and range granularity without a spec',
      () async {
        final transport = MockTransport((_, _) => ok({'points': []}));
        final source = ThesaAnalyticsDataSource(transport.call);

        final series = await source.getTimeSeries(
          'payment',
          'm',
          timeRange: fixedRange,
        );

        expect(transport.requests.single.body['step'], 'day');
        expect(series.single.label, 'm');
      },
    );

    test('missing points key parses as empty series', () async {
      final transport = MockTransport((_, _) => ok(<String, dynamic>{}));
      final source = ThesaAnalyticsDataSource(transport.call);

      final points = await source.queryTimeSeries(metric: 'm');

      expect(points, isEmpty);
    });

    test(
      'every TimeGranularity maps to an allowed server step value',
      () async {
        const allowed = {
          'minute', 'hour', 'day', 'week', 'month', 'quarter', 'year', //
        };
        for (final granularity in TimeGranularity.values) {
          final transport = MockTransport((_, _) => ok({'points': []}));
          final source = ThesaAnalyticsDataSource(transport.call);

          await source.queryTimeSeries(metric: 'm', granularity: granularity);

          final step = transport.requests.single.body['step'];
          expect(step, granularity.name);
          expect(allowed, contains(step));
        }
      },
    );
  });

  group('grouped queries', () {
    test('sends exact body with group_by and parses segments', () async {
      final transport = MockTransport(
        (_, _) => ok({
          'segments': [
            {'label': 'mpesa', 'value': 60},
            {'label': 'bank', 'value': 40.5},
          ],
        }),
      );
      final source = ThesaAnalyticsDataSource(transport.call);

      final segments = await source.queryGrouped(
        metric: 'payment_transactions_total',
        groupBy: 'route',
        timeRange: fixedRange,
      );

      expect(transport.requests.single.path, '/api/analytics/query/grouped');
      expect(transport.requests.single.body, {
        'metric': 'payment_transactions_total',
        'aggregation': 'sum',
        'group_by': 'route',
        'time_range': fixedRangeJson,
      });
      expect(segments, hasLength(2));
      expect(segments[0].label, 'mpesa');
      expect(segments[0].value, 60.0);
      expect(segments[1].value, 40.5);
    });

    test(
      'getDistribution applies chart spec aggregation and filters',
      () async {
        final transport = MockTransport((_, _) => ok({'segments': []}));
        final source = ThesaAnalyticsDataSource(
          transport.call,
          specs: const [paymentSpec],
        );

        await source.getDistribution(
          'payment',
          'payment_transactions_total',
          'route',
          timeRange: fixedRange,
        );

        expect(transport.requests.single.body, {
          'metric': 'payment_transactions_total',
          'aggregation': 'avg',
          'filters': {'service': 'payment', 'region': 'east'},
          'group_by': 'route',
          'time_range': fixedRangeJson,
        });
      },
    );

    test('missing segments key parses as empty list', () async {
      final transport = MockTransport((_, _) => ok(<String, dynamic>{}));
      final source = ThesaAnalyticsDataSource(transport.call);

      final segments = await source.queryGrouped(metric: 'm', groupBy: 'g');

      expect(segments, isEmpty);
    });
  });

  group('top-N queries', () {
    test('sends exact body with group_by and limit and parses items', () async {
      final transport = MockTransport(
        (_, _) => ok({
          'items': [
            {
              'label': 'acct-1',
              'value': 99,
              'metadata': {'currency': 'KES'},
            },
            {'label': 'acct-2', 'value': 12.25},
          ],
        }),
      );
      final source = ThesaAnalyticsDataSource(
        transport.call,
        specs: const [paymentSpec],
      );

      final items = await source.getTopN(
        'payment',
        'payment_transactions_total',
        limit: 5,
        timeRange: fixedRange,
      );

      expect(transport.requests.single.path, '/api/analytics/query/topn');
      expect(transport.requests.single.body, {
        'metric': 'payment_transactions_total',
        'aggregation': 'count_distinct',
        'filters': {'service': 'payment', 'kind': 'p2p'},
        'group_by': 'recipient',
        'limit': 5,
        'time_range': fixedRangeJson,
      });
      expect(items, hasLength(2));
      expect(items[0].label, 'acct-1');
      expect(items[0].value, 99.0);
      expect(items[0].metadata, {'currency': 'KES'});
      expect(items[1].metadata, isNull);
    });

    test('getTopN without a group_by spec throws before any request', () async {
      final transport = MockTransport((_, _) => ok({'items': []}));
      final source = ThesaAnalyticsDataSource(transport.call);

      await expectLater(
        () => source.getTopN('payment', 'payment_transactions_total'),
        throwsArgumentError,
      );
      expect(transport.requests, isEmpty);
    });

    test('missing items key parses as empty list', () async {
      final transport = MockTransport((_, _) => ok(<String, dynamic>{}));
      final source = ThesaAnalyticsDataSource(transport.call);

      final items = await source.queryTopN(metric: 'm', groupBy: 'g');

      expect(items, isEmpty);
    });
  });

  group('error propagation', () {
    test('400 surfaces the server error message, not a silent zero', () async {
      final transport = MockTransport(
        (_, _) => apiError(400, 'invalid granularity "fortnight"'),
      );
      final source = ThesaAnalyticsDataSource(transport.call);

      await expectLater(
        () => source.queryScalar(metric: 'm'),
        throwsA(
          isA<AnalyticsQueryException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.message,
                'message',
                'invalid granularity "fortnight"',
              )
              .having((e) => e.path, 'path', '/api/analytics/query/scalar'),
        ),
      );
    });

    test('403 tenant-scope rejection propagates', () async {
      final transport = MockTransport(
        (_, _) => apiError(403, 'analytics queries require tenant scope'),
      );
      final source = ThesaAnalyticsDataSource(transport.call);

      await expectLater(
        () => source.queryTimeSeries(metric: 'm'),
        throwsA(
          isA<AnalyticsQueryException>().having(
            (e) => e.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });

    test('500 with non-JSON body falls back to HTTP status message', () async {
      final transport = MockTransport(
        (_, _) => http.Response('upstream exploded', 500),
      );
      final source = ThesaAnalyticsDataSource(transport.call);

      await expectLater(
        () => source.queryGrouped(metric: 'm', groupBy: 'g'),
        throwsA(
          isA<AnalyticsQueryException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'HTTP 500'),
        ),
      );
    });

    test('200 with a non-object payload is rejected', () async {
      final transport = MockTransport((_, _) => ok([1, 2, 3]));
      final source = ThesaAnalyticsDataSource(transport.call);

      await expectLater(
        () => source.queryScalar(metric: 'm'),
        throwsA(isA<AnalyticsQueryException>()),
      );
    });

    test('a failing KPI query fails getMetrics as a whole', () async {
      final transport = MockTransport((_, body) {
        return body['metric'] == 'payment_amount'
            ? apiError(500, 'internal server error')
            : ok({'value': 1});
      });
      final source = ThesaAnalyticsDataSource(
        transport.call,
        specs: const [paymentSpec],
      );

      await expectLater(
        () => source.getMetrics('payment'),
        throwsA(isA<AnalyticsQueryException>()),
      );
    });
  });

  group('tenancy filter stripping', () {
    test('tenant_id and partition_id are stripped in all spellings', () async {
      final transport = MockTransport((_, _) => ok({'value': 1}));
      final source = ThesaAnalyticsDataSource(transport.call);

      await source.queryScalar(
        metric: 'm',
        filters: {
          'tenant_id': 't-1',
          'partition_id': 'p-1',
          'tenant.id': 't-2',
          'partition.id': 'p-2',
          'status': 'success',
        },
      );

      expect(transport.requests.single.body['filters'], {'status': 'success'});
    });

    test(
      'filters key is omitted entirely when everything is reserved',
      () async {
        final transport = MockTransport((_, _) => ok({'value': 1}));
        final source = ThesaAnalyticsDataSource(transport.call);

        await source.queryScalar(
          metric: 'm',
          filters: {'tenant_id': 't-1', 'partition.id': 'p-1'},
        );

        expect(transport.requests.single.body.containsKey('filters'), isFalse);
      },
    );

    test('reserved labels in spec base filters never reach the wire', () async {
      const sneakySpec = ServiceAnalyticsSpec(
        service: 'sneaky',
        baseFilters: {'tenant_id': 'other-tenant', 'service': 'sneaky'},
        kpis: [KpiSpec('k', label: 'K', metric: 'm')],
      );
      final transport = MockTransport((_, _) => ok({'value': 1}));
      final source = ThesaAnalyticsDataSource(
        transport.call,
        specs: const [sneakySpec],
      );

      await source.getMetrics('sneaky');

      expect(transport.requests.single.body['filters'], {'service': 'sneaky'});
    });

    test('non-reserved labels that merely contain the words survive', () async {
      final transport = MockTransport((_, _) => ok({'value': 1}));
      final source = ThesaAnalyticsDataSource(transport.call);

      await source.queryScalar(
        metric: 'm',
        filters: {'tenant_id_hash': 'h', 'my_partition_id': 'x'},
      );

      expect(transport.requests.single.body['filters'], {
        'tenant_id_hash': 'h',
        'my_partition_id': 'x',
      });
    });
  });

  group('ServiceAnalyticsSpec', () {
    test('metricKeys preserves KPI declaration order', () {
      expect(paymentSpec.metricKeys, ['total', 'avg_amount']);
    });

    test('chartFor and tableFor resolve by metric name', () {
      expect(
        paymentSpec.chartFor('payment_transactions_total')?.label,
        'Payment Volume',
      );
      expect(
        paymentSpec
            .chartFor(
              'payment_transactions_total',
              type: ChartType.distribution,
            )
            ?.label,
        'By Route',
      );
      expect(paymentSpec.chartFor('nope'), isNull);
      expect(
        paymentSpec.tableFor('payment_transactions_total')?.groupBy,
        'recipient',
      );
      expect(paymentSpec.tableFor('nope'), isNull);
    });
  });
}
