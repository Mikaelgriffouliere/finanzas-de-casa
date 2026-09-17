import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/services/statistics_service.dart';
import '../../utils/formatters.dart' as fmt;
import '../common/amount_display.dart';
import '../common/empty_state.dart';
import '../providers/app_provider.dart';
import '../../core/theme/app_colors.dart';
import '../common/glass_card.dart';

class ContributionsScreen extends StatefulWidget {
  const ContributionsScreen({super.key});

  @override
  State<ContributionsScreen> createState() => _ContributionsScreenState();
}

class _ContributionsScreenState extends State<ContributionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final statistics = context.read<AppProvider>().statistics;
    final from = fmt.DateUtils.startOfMonth(statistics.selectedMonth);
    final to = fmt.DateUtils.endOfMonth(statistics.selectedMonth);
    await statistics.loadIncomeByPerson(from, to);
    await statistics.loadExpensesByPerson(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final statistics = context.watch<AppProvider>().statistics;
    final month = statistics.selectedMonth;
    final income = statistics.incomeByPerson;
    final expenses = statistics.expensesByPerson;

    final isEmpty = income.isEmpty && expenses.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen de aportes')),
      body: isEmpty
          ? EmptyState(
              icon: Icons.pie_chart,
              title: 'Sin aportes',
              subtitle:
                  'No hay aportes registrados en ${fmt.DateUtils.monthYear(month).toLowerCase()}',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _SectionCard(
                    title: 'Aportes (ingresos)',
                    icon: Icons.trending_up,
                    color: AppColors.income,
                    contributions: income,
                  ),
                  _SectionCard(
                    title: 'Gastos por persona',
                    icon: Icons.trending_down,
                    color: AppColors.expense,
                    contributions: expenses,
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<PersonContribution> contributions;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.contributions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = contributions.fold<int>(0, (sum, c) => sum + c.amount);

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: AmountDisplay(
                    cents: total,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (contributions.isEmpty)
              Text(
                'Sin datos',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              )
            else
              for (final contribution in contributions) ...[
                _ContributionRow(contribution: contribution),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _ContributionRow extends StatelessWidget {
  final PersonContribution contribution;

  const _ContributionRow({required this.contribution});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                contribution.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: AmountDisplay(cents: contribution.amount)),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: Text(
                '${(contribution.percent * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: 0,
              end: contribution.percent.clamp(0.0, 1.0),
            ),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      ],
    );
  }
}
