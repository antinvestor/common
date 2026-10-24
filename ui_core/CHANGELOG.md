## 0.6.0

- **Breaking:** moves to connect-dart 2 and the protobuf 6 runtime:
  `connectrpc ^2.0.0`, `protobuf ^6.1.0`, `antinvestor_api_common ^2.0.0`,
  `fixnum ^1.1.1`. Apps that depend on ui_core must use the 2.x
  `antinvestor_api_*` SDKs; well-known types now come from
  `package:protobuf/well_known_types/...` through `antinvestor_api_common`.
  No ui_core API changes.

## 0.5.1

- `AdminEntityListPage` gains an optional `filters` slot, rendered below
  the header/search so per-page filter chips sit under the breadcrumb
  instead of floating above the page. Backwards compatible (defaults to none).

## 0.5.0

- Add `ThesaAnalyticsDataSource`, the standard `AnalyticsDataSource` backed
  by the Thesa BFF analytics API (`POST /api/analytics/query/{scalar,
  timeseries,grouped,topn}`). Takes an `AnalyticsTransport` function so each
  app plugs in its own authenticated client; ui_core stays auth-agnostic.
  Requests follow the server contract exactly (nested `time_range`, `step`
  granularity) and reserved tenancy filters (`tenant_id`/`partition_id`,
  any dot or underscore spelling) are stripped client-side — tenant scoping
  is injected server-side from the JWT.
- Add `AnalyticsQueryException` carrying the HTTP status and server error
  message for non-200 analytics responses.
- Add `ServiceAnalyticsSpec` + `KpiSpec`: a per-service metric catalog
  (KPI scalar queries, charts, top-N tables) composing the existing
  `ChartConfig`/`TableConfig` dashboard config types.
- Add `AnalyticsAggregation` enum with API wire names.
- `ChartConfig` and `TableConfig` gain optional `aggregation` and `filters`;
  `TableConfig.topN` gains `groupBy` (required by the Thesa top-N endpoint).

## 0.4.0

- Make money display helpers polymorphic over generated `Money` types from
  any service SDK (`formatMoney`, `moneyToAmountString`, `moneyCurrency`,
  `AmountDisplay.amount` now accept `dynamic`). Eliminates per-package
  `bridgeMoney`/`fmtMoney` shims.
- Add `setMoneyFields(target, amount, currencyCode)` for populating an
  existing service-specific `Money` proto in place — preferred over
  `moneyFromString` when constructing request fields.

## 0.1.0

- Initial release
- Shared design system with Stitch theme, AdminEntityListPage, analytics framework, permission system
