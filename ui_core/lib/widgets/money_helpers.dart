import 'package:antinvestor_api_common/antinvestor_api_common.dart';
import 'package:fixnum/fixnum.dart';

/// Formats a [Money] object for display. Returns "---" if null or zero.
String formatMoney(Money? money) {
  if (money == null) return '\u2014';
  final units = money.units.toInt();
  final nanos = money.nanos;
  final currency = money.currencyCode;

  if (units == 0 && nanos == 0) return '\u2014';

  // Format with 2 decimal places for display
  final cents = nanos ~/ 10000000;
  final formatted = '$units.${cents.toString().padLeft(2, '0')}';

  if (currency.isEmpty) return formatted;
  return '$currency $formatted';
}

/// Creates a [Money] object from a decimal string and currency code.
/// e.g. "50000.00" with "KES" -> Money(currencyCode: "KES", units: 50000, nanos: 0)
///
/// Returns a zero-value Money if [amount] is empty or unparseable.
Money moneyFromString(String amount, String currencyCode) {
  final money = Money();
  money.currencyCode = currencyCode;

  final cleaned = amount.trim();
  if (cleaned.isEmpty) return money;

  // Strip anything that isn't digit, dot, or leading minus
  final sanitized = cleaned.replaceAll(RegExp(r'[^\d.\-]'), '');
  if (sanitized.isEmpty) return money;

  try {
    final parts = sanitized.split('.');
    money.units = Int64.parseInt(parts[0].isEmpty ? '0' : parts[0]);
    if (parts.length > 1) {
      // Pad or truncate to 9 digits (nanos)
      final fracStr = parts[1].padRight(9, '0').substring(0, 9);
      money.nanos = int.parse(fracStr);
    }
  } catch (_) {
    // Return zero-value on any parse failure
  }

  return money;
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

/// Extracts the display amount from a Money as a plain string (no currency).
String moneyToAmountString(Money? money) {
  if (money == null) return '0';
  final units = money.units.toInt();
  final nanos = money.nanos;
  if (nanos == 0) return '$units';
  final cents = nanos ~/ 10000000;
  return '$units.${cents.toString().padLeft(2, '0')}';
}

/// Extracts currency code from Money, with fallback.
String moneyCurrency(Money? money, [String fallback = '']) {
  if (money == null || money.currencyCode.isEmpty) return fallback;
  return money.currencyCode;
}
