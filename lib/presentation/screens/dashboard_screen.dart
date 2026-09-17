import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide DateUtils;
import 'package:provider/provider.dart';

import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/savings_goal.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_type.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/subcategory.dart';
import '../../domain/services/statistics_service.dart';
import '../../utils/formatters.dart';
import '../providers/app_provider.dart';
import '../common/amount_display.dart';
import '../common/empty_state.dart';
import '../common/section_header.dart';
import '../common/skeleton_loader.dart';
import '../common/animated_money.dart';
import '../common/fade_in_up.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_helper.dart';
import '../common/glass_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final transactions = app.transaction.transactions;

    final sections = <Widget>[
      _MonthSelector(
        month: app.statistics.selectedMonth,
        onPrevious: () => _changeMonth(context, -1),
        onNext: () => _changeMonth(context, 1),
      ),
      _SummaryCard(month: app.statistics.selectedMonth),
      const SectionHeader(title: 'Ingresos vs Gastos'),
      _IncomeExpenseChart(transactions: transactions),
      const SectionHeader(title: 'Gastos por categoría'),
      _CategoryChart(),
      const SectionHeader(title: 'Progreso de ahorro'),
      _SavingsProgress(),
      const SectionHeader(title: 'Próximos gastos'),
      _UpcomingExpenses(),
      const SectionHeader(title: 'Últimos movimientos'),
      _RecentMovements(transactions: transactions),
    ];

    return CustomScrollView(
      slivers: [
        for (var i = 0; i < sections.length; i++)
          SliverToBoxAdapter(
            child: FadeInUp(
              delay: Duration(milliseconds: 50 * i),
              child: sections[i],
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  void _changeMonth(BuildContext context, int delta) {
    HapticHelper.selection();
    final stats = context.read<AppProvider>().statistics;
    final current = stats.selectedMonth;
    stats.setMonth(DateTime(current.year, current.month + delta, 1));
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Mes anterior',
          ),
          Text(
            DateUtils.monthYear(month),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Siguiente mes',
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DateTime month;

  const _SummaryCard({required this.month});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppProvider>();
    final summary = app.statistics.summary;
    if (summary == null) {
      return const SkeletonDashboardSummary();
    }
    final balance = app.account.totalBalance;
    final isDark = theme.brightness == Brightness.dark;

    final savingsRate = summary.income > 0
        ? (summary.savingsRate * 100).toStringAsFixed(0)
        : null;

    final gradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3543B8), Color(0xFF15798F), Color(0xFF13826C)],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.heroGradient,
          );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _GlassPill(
                  icon: Icons.calendar_month,
                  label: DateUtils.monthYear(month),
                ),
                if (savingsRate != null) ...[
                  const Spacer(),
                  _GlassPill(
                    icon: Icons.trending_up,
                    label: '$savingsRate% ahorrado',
                    emphasized: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Balance total',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedMoney(
                cents: balance,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'Ingresos',
                    amount: summary.income,
                    icon: Icons.arrow_downward,
                    accent: const Color(0xFF8EF7CD),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HeroStat(
                    label: 'Gastos',
                    amount: summary.expense,
                    icon: Icons.arrow_upward,
                    accent: const Color(0xFFFFB3C4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'Ahorro',
                    amount: summary.savings,
                    icon: Icons.savings,
                    accent: const Color(0xFFC6D6FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HeroStat(
                    label: 'Disponible mes',
                    amount: summary.available,
                    icon: Icons.account_balance_wallet,
                    accent: const Color(0xFFFFE0A0),
                  ),
                ),
              ],
            ),
            if (summary.previousExpense != null &&
                summary.previousExpense! > 0) ...[
              const SizedBox(height: 12),
              _EvolutionIndicator(summary: summary),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool emphasized;

  const _GlassPill({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: emphasized ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.95)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final int amount;
  final IconData icon;
  final Color accent;

  const _HeroStat({
    required this.label,
    required this.amount,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedMoney(
              cents: amount,
              style: theme.textTheme.titleMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvolutionIndicator extends StatelessWidget {
  final MonthlySummary summary;

  const _EvolutionIndicator({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = summary.expenseDeltaPercent;
    final increased = delta > 0;
    final text = increased
        ? 'Gastos +${delta.abs().toStringAsFixed(0)}% vs. mes anterior'
        : 'Gastos ${delta.abs().toStringAsFixed(0)}% menos que el mes anterior';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            increased ? Icons.trending_up : Icons.trending_down,
            color: increased
                ? const Color(0xFFFFB3C4)
                : const Color(0xFF8EF7CD),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeExpenseChart extends StatelessWidget {
  final List<Transaction> transactions;

  const _IncomeExpenseChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _buildDailyData(transactions);

    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Sin datos para el período',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < data.length; i++) {
      final day = data[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: day.income.toDouble(),
              color: AppColors.income,
              width: 7,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
            BarChartRodData(
              toY: day.expense.toDouble(),
              color: AppColors.expense,
              width: 7,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ChartLegend(),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _maxY(data) * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${data[index].day.day}',
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: groups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _maxY(List<_DayData> data) {
    double max = 0;
    for (final d in data) {
      if (d.income > max) max = d.income;
      if (d.expense > max) max = d.expense;
    }
    return max == 0 ? 1 : max;
  }

  List<_DayData> _buildDailyData(List<Transaction> transactions) {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 6));
    final result = <_DayData>[];

    for (var i = 0; i < 7; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      result.add(_DayData(day: day));
    }

    for (final t in transactions) {
      final tDay = DateTime(t.date.year, t.date.month, t.date.day);
      for (final d in result) {
        if (tDay == d.day) {
          if (t.type == TransactionType.income) {
            d.income += t.amount;
          } else if (t.type == TransactionType.expense) {
            d.expense += t.amount;
          }
        }
      }
    }
    return result;
  }
}

class _DayData {
  final DateTime day;
  double income = 0;
  double expense = 0;

  _DayData({required this.day});
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _LegendItem(color: AppColors.income, label: 'Ingresos'),
        SizedBox(width: 16),
        _LegendItem(color: AppColors.expense, label: 'Gastos'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final categories = app.statistics.categoryExpenses;
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: EmptyState(
          icon: Icons.pie_chart_outline,
          title: 'Sin gastos en el mes',
          subtitle: 'La distribución por categoría aparecerá aquí.',
        ),
      );
    }

    final total = categories.fold<int>(0, (s, c) => s + c.amount);

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 42,
                  sections: [
                    for (var i = 0; i < categories.length; i++)
                      PieChartSectionData(
                        color: _categoryColors[i % _categoryColors.length],
                        value: categories[i].amount.toDouble(),
                        title: total > 0
                            ? '${(categories[i].amount / total * 100).round()}%'
                            : '',
                        radius: 42,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (var i = 0; i < categories.length; i++)
                  _LegendItem(
                    color: _categoryColors[i % _categoryColors.length],
                    label:
                        '${categories[i].name} '
                        '(${MoneyUtils.formatCompact(categories[i].amount)})',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _categoryColors = [
  Color(0xFF6C7BFF),
  Color(0xFFEF6B8C),
  Color(0xFFF0A437),
  Color(0xFF1FB98A),
  Color(0xFF8B5CF6),
  Color(0xFF4D9DE8),
  Color(0xFFF2617F),
  Color(0xFF2BB3A3),
];

class _SavingsProgress extends StatelessWidget {
  const _SavingsProgress();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final goals = app.savings.goals
        .where((g) => g.status.name == 'active')
        .toList();
    if (goals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: EmptyState(
          icon: Icons.savings_outlined,
          title: 'Sin metas de ahorro',
          subtitle: 'Creá una meta para ver tu progreso.',
        ),
      );
    }

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < goals.length; i++) ...[
              _GoalProgressTile(goal: goals[i]),
              if (i < goals.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalProgressTile extends StatelessWidget {
  final SavingsGoal goal;

  const _GoalProgressTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (goal.progress * 100).round().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$pct%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: goal.progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${MoneyUtils.format(goal.currentAmount)} de '
          '${MoneyUtils.format(goal.targetAmount)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _UpcomingExpenses extends StatelessWidget {
  const _UpcomingExpenses();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppProvider>();
    final recurring = app.recurring.recurringTransactions
        .where((r) => r.isActive || r.isIncome == false)
        .toList();

    if (recurring.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: EmptyState(
          icon: Icons.event_repeat,
          title: 'Sin gastos recurrentes',
          subtitle: 'Los gastos fijos programados aparecerán aquí.',
        ),
      );
    }

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < recurring.length; i++) ...[
            _UpcomingTile(recurring: recurring[i]),
            if (i < recurring.length - 1)
              Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final RecurringTransaction recurring;

  const _UpcomingTile({required this.recurring});

  @override
  Widget build(BuildContext context) {
    final color = recurring.isIncome ? AppColors.income : AppColors.expense;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          recurring.isIncome ? Icons.south_west : Icons.north_east,
          size: 20,
          color: color,
        ),
      ),
      title: Text(recurring.name),
      subtitle: Text('Día ${recurring.dueDay} de cada mes'),
      trailing: AmountDisplay(
        cents: recurring.isIncome ? recurring.amount : -recurring.amount,
        showSign: true,
      ),
    );
  }
}

class _RecentMovements extends StatelessWidget {
  final List<Transaction> transactions;

  const _RecentMovements({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: EmptyState(
          icon: Icons.receipt_long,
          title: 'Sin movimientos',
          subtitle: 'Registra tu primer movimiento para empezar.',
        ),
      );
    }

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (
            var i = 0;
            i < (transactions.length > 5 ? 5 : transactions.length);
            i++
          ) ...[
            _RecentTile(
              transaction: transactions[i],
              category: context.watch<AppProvider>().category.byId(
                transactions[i].categoryId,
              ),
              subcategory: context
                  .watch<AppProvider>()
                  .category
                  .subcategoryById(transactions[i].subcategoryId),
              person: _personById(
                context.watch<AppProvider>().person.persons,
                transactions[i].personId,
              ),
            ),
            if (i < transactions.length - 1 &&
                i < (transactions.length > 5 ? 5 : transactions.length) - 1)
              Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }

  Person? _personById(List<Person> persons, int? id) {
    for (final p in persons) {
      if (p.id == id) return p;
    }
    return null;
  }
}

class _RecentTile extends StatelessWidget {
  final Transaction transaction;
  final Person? person;
  final Category? category;
  final Subcategory? subcategory;

  const _RecentTile({
    required this.transaction,
    this.person,
    this.category,
    this.subcategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _iconForType(transaction.type);
    final negative = transaction.type == TransactionType.expense;
    final parts = <String>[
      if (category != null) category!.name,
      if (subcategory != null) subcategory!.name,
      if (person != null) person!.name,
    ];
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        transaction.description.isEmpty
            ? 'Movimiento'
            : transaction.description,
      ),
      subtitle: parts.isEmpty
          ? null
          : Text(
              parts.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
      trailing: AmountDisplay(
        cents: negative ? -transaction.amount : transaction.amount,
        showSign: true,
      ),
    );
  }

  (IconData, Color) _iconForType(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return (Icons.arrow_downward, AppColors.income);
      case TransactionType.expense:
        return (Icons.arrow_upward, AppColors.expense);
      case TransactionType.transfer:
        return (Icons.swap_horiz, AppColors.transfer);
    }
  }
}
