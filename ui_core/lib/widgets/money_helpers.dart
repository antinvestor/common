import 'package:antinvestor_api_common/antinvestor_api_common.dart';
import 'package:fixnum/fixnum.dart';

/// Money helpers are intentionally polymorphic: every Antinvestor service
/// SDK regenerates `google.type.Money` as its own Dart class, so a single
/// typed signature would only accept one of them. These helpers read the
/// three structural fields (`units`, `nanos`, `currencyCode`) via dynamic
/// dispatch, which works against any generated `Money` (or [Money] from
/// `antinvestor_api_common`).

const String _emDash = '—';

({Int64 units, int nanos, String currencyCode})? _readMoney(dynamic money) {
  if (money == null) return null;
  try {
    final units = money.units as Int64;
    final nanos = money.nanos as int;
    final currencyCode = money.currencyCode as String;
    return (units: units, nanos: nanos, currencyCode: currencyCode);
  } catch (_) {
    return null;
  }
}

/// Formats a `Money`-shaped object for display. Returns `—` if null or zero.
///
/// Accepts any object with `units`/`nanos`/`currencyCode` fields — typically
/// a generated proto `Money` from any service SDK.
String formatMoney(dynamic money) {
  final m = _readMoney(money);
  if (m == null) return _emDash;

  final units = m.units.toInt();
  final nanos = m.nanos;
  if (units == 0 && nanos == 0) return _emDash;

  // Display with 2 fractional digits. Locale-aware formatting is intentionally
  // not done here so the helper stays dependency-free; callers that need
  // locale formatting should use a domain-specific NumberFormat.
  final cents = nanos ~/ 10000000;
  final formatted = '$units.${cents.toString().padLeft(2, '0')}';

  if (m.currencyCode.isEmpty) return formatted;
  return '${m.currencyCode} $formatted';
}

/// Creates a [Money] (`antinvestor_api_common.Money`) from a decimal string
/// and currency code.
///
/// For service-specific request fields, prefer [setMoneyFields] which mutates
/// an existing typed proto in place rather than constructing a common-typed
/// instance that would then need to be copied.
Money moneyFromString(String amount, String currencyCode) {
  final money = Money();
  setMoneyFields(money, amount, currencyCode);
  return money;
}

/// Populates the `currencyCode`/`units`/`nanos` fields on an existing
/// `Money`-shaped proto from a decimal string. Use this to build a request
/// field without leaving the request's own `Money` Dart type:
///
/// ```dart
/// final req = WithdrawalRequest();
/// setMoneyFields(req.amount, '50.00', 'KES');
/// ```
///
/// On any parse failure, leaves the target with zero `units`/`nanos`.
void setMoneyFields(dynamic target, String amount, String currencyCode) {
  target.currencyCode = currencyCode;

  final cleaned = amount.trim();
  if (cleaned.isEmpty) return;

  final sanitized = cleaned.replaceAll(RegExp(r'[^\d.\-]'), '');
  if (sanitized.isEmpty) return;

  try {
    final parts = sanitized.split('.');
    target.units = Int64.parseInt(parts[0].isEmpty ? '0' : parts[0]);
    if (parts.length > 1) {
      final fracStr = parts[1].padRight(9, '0').substring(0, 9);
      target.nanos = int.parse(fracStr);
    }
  } catch (_) {
    // Leave zero-value on any parse failure.
  }
}

/// Validates that [value] is a valid positive decimal amount string.
/// Returns an error message or null if valid.
String? validateAmount(String? value) {
  if (value == null || value.trim().isEmpty) return 'Amount is required';
  final cleaned = value.trim().replaceAll(',', '');
  final parsed = double.tryParse(cleaned);
  if (parsed == null) return 'Enter a valid number';
  if (parsed <= 0) return 'Amount must be positive';
  return null;
}

/// Validates a phone number (basic: non-empty, digits/+ only, min length).
String? validatePhone(String? value) {
  if (value == null || value.trim().isEmpty) return 'Phone number is required';
  final cleaned = value.trim();
  if (!RegExp(r'^[+\d\s\-()]+$').hasMatch(cleaned)) {
    return 'Enter a valid phone number';
  }
  final digitsOnly = cleaned.replaceAll(RegExp(r'[^\d]'), '');
  if (digitsOnly.length < 7) return 'Phone number is too short';
  if (digitsOnly.length > 15) return 'Phone number is too long';
  return null;
}

/// Validates a non-empty required field.
String? validateRequired(String? value, [String field = 'This field']) {
  if (value == null || value.trim().isEmpty) return '$field is required';
  return null;
}

/// Validates a currency code (3 uppercase letters).
String? validateCurrency(String? value) {
  if (value == null || value.trim().isEmpty) return 'Currency is required';
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(value.trim())) {
    return 'Enter a 3-letter currency code (e.g. KES)';
  }
  return null;
}

/// Extracts the display amount from a `Money`-shaped object as a plain
/// string (no currency).
String moneyToAmountString(dynamic money) {
  final m = _readMoney(money);
  if (m == null) return '0';
  final units = m.units.toInt();
  if (m.nanos == 0) return '$units';
  final cents = m.nanos ~/ 10000000;
  return '$units.${cents.toString().padLeft(2, '0')}';
}

/// Extracts currency code from a `Money`-shaped object, with fallback.
String moneyCurrency(dynamic money, [String fallback = '']) {
  final m = _readMoney(money);
  if (m == null || m.currencyCode.isEmpty) return fallback;
  return m.currencyCode;
}
