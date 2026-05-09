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
