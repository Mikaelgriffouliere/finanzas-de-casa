import 'package:flutter/material.dart';

import '../../utils/formatters.dart';
import '../../core/theme/app_colors.dart';

class AmountDisplay extends StatelessWidget {
  final int cents;
  final TextStyle? style;
  final String symbol;
  final bool showSign;
  final Color? positiveColor;
  final Color? negativeColor;

  const AmountDisplay({
    super.key,
    required this.cents,
    this.style,
    this.symbol = r'$',
    this.showSign = false,
    this.positiveColor,
    this.negativeColor,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = MoneyUtils.format(cents, symbol: symbol);
    final prefix = !showSign
        ? ''
        : cents > 0
        ? '+'
        : cents < 0
        ? '-'
        : '';

    Color? color;
    if (showSign) {
      if (cents > 0) {
        color = positiveColor ?? AppColors.income;
      } else if (cents < 0) {
        color = negativeColor ?? AppColors.expense;
      }
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '$prefix$formatted',
        style:
            style?.copyWith(color: color) ??
            TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
