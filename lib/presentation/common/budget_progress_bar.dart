import 'package:flutter/material.dart';

import '../../utils/formatters.dart';
import '../../core/theme/app_colors.dart';

class BudgetProgressBar extends StatelessWidget {
  final int spent;
  final int budget;
  final bool isWarning;
  final bool isExceeded;

  const BudgetProgressBar({
    super.key,
    required this.spent,
    required this.budget,
    this.isWarning = false,
    this.isExceeded = false,
  });

  double get _progress {
    if (budget <= 0) return 0;
    return (spent / budget).clamp(0.0, 1.0);
  }

  Color _color(ThemeData theme) {
    if (isExceeded) return AppColors.expense;
    if (isWarning) return AppColors.warning;
    return AppColors.income;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(theme);
    final percentage = (_progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: _progress),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$percentage% utilizado · ${MoneyUtils.format(spent)} de ${MoneyUtils.format(budget)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}
