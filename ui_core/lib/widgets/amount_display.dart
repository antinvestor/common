import 'package:flutter/material.dart';

import 'money_helpers.dart';

/// Displays a `Money`-shaped value with proper formatting, optional currency
/// prefix, and directional coloring (green for credit, red for debit).
///
/// Accepts any generated proto `Money` (from any service SDK) via dynamic
/// dispatch. Drop this into ANY screen to render a monetary amount
/// consistently.
///
/// ```dart
/// AmountDisplay(amount: transaction.amount)
/// AmountDisplay(amount: tx.amount, direction: AmountDirection.credit)
/// AmountDisplay.compact(amount: tx.amount)
/// ```
enum AmountDirection { none, credit, debit }

class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    super.key,
    required this.amount,
    this.direction = AmountDirection.none,
    this.style,
    this.showCurrency = true,
    this.placeholder = '\u2014',
    this.compact = false,
    this.prefix = '',
    this.suffix = '',
  });

  /// Compact constructor for inline use.
  const AmountDisplay.compact({
    super.key,
    required this.amount,
    this.direction = AmountDirection.none,
    this.style,
    this.showCurrency = true,
    this.placeholder = '\u2014',
    this.prefix = '',
    this.suffix = '',
  }) : compact = true;

  final dynamic amount;
  final AmountDirection direction;
  final TextStyle? style;
  final bool showCurrency;
  final String placeholder;
  final bool compact;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isPlaceholder(amount)) {
      return Text(
        '$prefix$placeholder$suffix',
        style: style ??
            (compact
                ? theme.textTheme.bodySmall
                : theme.textTheme.bodyMedium),
      );
    }

    final formatted =
        showCurrency ? formatMoney(amount) : moneyToAmountString(amount);
    final display = '$prefix$formatted$suffix';

    Color? textColor;
    String? directionPrefix;
    switch (direction) {
      case AmountDirection.credit:
        textColor = Colors.green.shade700;
        directionPrefix = '+ ';
        break;
      case AmountDirection.debit:
        textColor = Colors.red.shade700;
        directionPrefix = '- ';
        break;
      case AmountDirection.none:
        directionPrefix = '';
        break;
    }

    final baseStyle = style ??
        (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium);

    return Text(
      '$directionPrefix$display',
      style: baseStyle?.copyWith(
        color: textColor ?? baseStyle.color,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static bool _isPlaceholder(dynamic money) {
    if (money == null) return true;
    try {
      return money.units.toInt() == 0 && money.nanos == 0;
    } catch (_) {
      return true;
    }
  }
}
