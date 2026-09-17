import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide DateUtils;
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_helper.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../data/repositories/recurring_repository_impl.dart';
import '../../data/services/pdf_report_service.dart';
import '../../domain/entities/expense_kind.dart';
import '../../domain/entities/transaction_type.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../utils/formatters.dart';
import '../providers/app_provider.dart';
import '../common/empty_state.dart';
import '../common/section_header.dart';
import '../common/skeleton_loader.dart';
import '../common/animated_money.dart';
import '../common/fade_in_up.dart';
import '../common/glass_card.dart';

enum _Period { month, week, quarter, year, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _txRepo = TransactionRepositoryImpl();
  final _recurringRepo = RecurringTransactionRepositoryImpl();

  _Period _period = _Period.month;
  DateTime _from = DateUtils.startOfMonth(DateTime.now());
  DateTime _to = DateUtils.endOfMonth(DateTime.now());
  DateTimeRange? _customRange;

  ReportsData? _data;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _setPeriod(_Period p) {
    setState(() => _period = p);
    _applyPeriod(p);
  }

  void _applyPeriod(_Period p) {
    final now = DateTime.now();
    switch (p) {
      case _Period.month:
        setState(() {
          _from = DateUtils.startOfMonth(now);
          _to = DateUtils.endOfMonth(now);
        });
      case _Period.week:
        final today = DateTime(now.year, now.month, now.day);
        final monday = today.subtract(Duration(days: today.weekday - 1));
        setState(() {
          _from = monday;
          _to = monday.add(
            const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
          );
        });
      case _Period.quarter:
        final qMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        setState(() {
          _from = DateTime(now.year, qMonth, 1);
          _to = DateUtils.endOfMonth(DateTime(now.year, qMonth + 2));
        });
      case _Period.year:
        setState(() {
          _from = DateTime(now.year, 1, 1);
          _to = DateTime(now.year, 12, 31, 23, 59, 59);
        });
      case _Period.custom:
        return;
    }
    _load();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
      locale: const Locale('es'),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _from = DateUtils.startOfDay(picked.start);
        _to = DateUtils.endOfDay(picked.end);
        _period = _Period.custom;
      });
      _load();
    }
  }

  String _periodLabel() {
    switch (_period) {
      case _Period.month:
        return DateUtils.monthYear(_from);
      case _Period.week:
        return 'Semana del ${DateUtils.shortDate(_from)} al '
            '${DateUtils.shortDate(_to)}';
      case _Period.quarter:
        final qStart = DateUtils.monthName(_from);
        final qEnd = DateUtils.monthName(_to);
        return 'T${((_from.month - 1) ~/ 3) + 1} $qStart–$qEnd ${_from.year}';
      case _Period.year:
        return '${_from.year}';
      case _Period.custom:
        return '${DateUtils.shortDate(_from)} – ${DateUtils.shortDate(_to)}';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final incomeByCategory = await _txRepo.sumByCategory(
        type: TransactionType.income,
        from: _from,
        to: _to,
      );
      final expenseByCategory = await _txRepo.sumByCategory(
        type: TransactionType.expense,
        from: _from,
        to: _to,
      );
      final incomeByPerson = await _txRepo.sumByPerson(
        type: TransactionType.income,
        from: _from,
        to: _to,
      );
      final expenseByPerson = await _txRepo.sumByPerson(
        type: TransactionType.expense,
        from: _from,
        to: _to,
      );
      final incomeByMonth = await _txRepo.sumByMonth(
        type: TransactionType.income,
        from: _from,
        to: _to,
      );
      final expenseByMonth = await _txRepo.sumByMonth(
        type: TransactionType.expense,
        from: _from,
        to: _to,
      );
      final totalIncome = await _txRepo.sumByType(
        type: TransactionType.income,
        from: _from,
        to: _to,
      );
      final totalExpense = await _txRepo.sumByType(
        type: TransactionType.expense,
        from: _from,
        to: _to,
      );

      final expenseByAccount = await _txRepo.getAll(
        filter: TransactionFilter(
          from: _from,
          to: _to,
          type: TransactionType.expense,
        ),
      );
      final groupedByAccount = <int, int>{};
      for (final t in expenseByAccount) {
        if (t.accountId == null) continue;
        groupedByAccount[t.accountId!] =
            (groupedByAccount[t.accountId!] ?? 0) + t.amount;
      }

      final recurring = await _recurringRepo.getAll(onlyActive: true);
      final fixedTotal = recurring
          .where((r) => r.kind == ExpenseKind.fixed && !r.isIncome)
          .fold<int>(0, (s, r) => s + r.amount);
      final variableTotal = recurring
          .where((r) => r.kind == ExpenseKind.variable && !r.isIncome)
          .fold<int>(0, (s, r) => s + r.amount);

      if (!mounted) return;
      final app = context.read<AppProvider>();
      final categories = app.category;
      final persons = app.person.persons;
      final accounts = app.account.accounts;

      setState(() {
        _data = ReportsData(
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          incomeByCategory: incomeByCategory,
          expenseByCategory: expenseByCategory,
          incomeByPerson: incomeByPerson,
          expenseByPerson: expenseByPerson,
          incomeByMonth: incomeByMonth,
          expenseByMonth: expenseByMonth,
          expenseByAccount: groupedByAccount,
          fixedExpenseRecurring: fixedTotal,
          variableExpenseRecurring: variableTotal,
          categories: categories,
          persons: persons,
          accounts: accounts,
        );
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _exportPdf() async {
    final d = _data;
    if (d == null || _exporting) return;

    final sections = await showDialog<Set<PdfReportSection>>(
      context: context,
      builder: (_) => const _PdfSectionPickerDialog(),
    );
    if (sections == null || sections.isEmpty || !mounted) return;

    setState(() => _exporting = true);
    try {
      final app = context.read<AppProvider>();
      final categories = app.category;
      final persons = app.person.persons;
      final accounts = app.account.accounts;

      String personName(int? id) {
        if (id == null) return '';
        for (final p in persons) {
          if (p.id == id) return p.name;
        }
        return '';
      }

      String accountName(int? id) {
        if (id == null) return '';
        for (final a in accounts) {
          if (a.id == id) return a.name;
        }
        return '';
      }

      final txs = await _txRepo.getAll(
        filter: TransactionFilter(from: _from, to: _to),
      );

      final movements = <PdfMovementRow>[];
      for (final t in txs) {
        final isTransfer = t.type == TransactionType.transfer;
        String accountDetail;
        if (isTransfer) {
          final from = accountName(t.accountId);
          final to = accountName(t.transferAccountId);
          if (from.isNotEmpty && to.isNotEmpty) {
            accountDetail = '$from – $to';
          } else {
            accountDetail = from.isNotEmpty ? from : to;
          }
        } else {
          accountDetail = accountName(t.accountId);
        }
        final categoryName = t.categoryId == null
            ? ''
            : (categories.byId(t.categoryId)?.name ?? '');
        movements.add(
          PdfMovementRow(
            date: t.date,
            typeLabel: t.type.label,
            description: t.description,
            category: isTransfer
                ? (categoryName.isEmpty ? 'Transferencia' : categoryName)
                : categoryName,
            subcategory: isTransfer
                ? accountDetail
                : (categories.subcategoryById(t.subcategoryId)?.name ?? ''),
            person: personName(t.personId),
            account: isTransfer ? '' : accountDetail,
            signedCents: t.type == TransactionType.expense
                ? -t.amount
                : t.amount,
          ),
        );
      }

      Map<String, int> byName(
        Map<int, int> byId,
        String Function(int id) name,
      ) {
        return {for (final e in byId.entries) name(e.key): e.value};
      }

      final file = await PdfReportService().generateReport(
        appName: AppConstants.appName,
        periodTitle: _periodLabel(),
        from: _from,
        to: _to,
        totalIncome: d.totalIncome,
        totalExpense: d.totalExpense,
        incomeByCategory: byName(
          d.incomeByCategory,
          (id) => categories.byId(id)?.name ?? 'Categoría',
        ),
        expenseByCategory: byName(
          d.expenseByCategory,
          (id) => categories.byId(id)?.name ?? 'Categoría',
        ),
        incomeByPerson: byName(
          d.incomeByPerson,
          (id) => personName(id).isEmpty ? 'Sin persona' : personName(id),
        ),
        expenseByPerson: byName(
          d.expenseByPerson,
          (id) => personName(id).isEmpty ? 'Sin persona' : personName(id),
        ),
        expenseByAccount: byName(
          d.expenseByAccount,
          (id) => accountName(id).isEmpty ? 'Cuenta' : accountName(id),
        ),
        movements: movements,
        sections: sections,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Informe PDF guardado en ${file.path}')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar el informe PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            tooltip: 'Exportar informe PDF',
            onPressed: _exporting ? null : _exportPdf,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_Period>(
                  segments: const [
                    ButtonSegment(value: _Period.month, label: Text('Mes')),
                    ButtonSegment(value: _Period.week, label: Text('Semana')),
                    ButtonSegment(
                      value: _Period.quarter,
                      label: Text('Trimestre'),
                    ),
                    ButtonSegment(value: _Period.year, label: Text('Año')),
                    ButtonSegment(value: _Period.custom, label: Text('Rango')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) {
                    HapticHelper.selection();
                    final p = s.first;
                    if (p == _Period.custom) {
                      _pickCustomRange();
                    } else {
                      _setPeriod(p);
                    }
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _periodLabel(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(child: SkeletonReportsView())
          else if (_data == null ||
              (_data!.totalIncome == 0 && _data!.totalExpense == 0))
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.assessment_outlined,
                title: 'Sin datos en este periodo',
                subtitle: 'Seleccioná otro rango de fechas para ver reportes.',
              ),
            )
          else
            ..._buildSections(),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<Widget> _buildSections() {
    final d = _data!;
    final balance = d.totalIncome - d.totalExpense;
    final savingsRate = d.totalIncome > 0
        ? (balance / d.totalIncome).clamp(0.0, 1.0)
        : 0.0;

    final sections = <Widget>[
      const SectionHeader(title: 'Resumen'),
      _SummaryCards(
        income: d.totalIncome,
        expense: d.totalExpense,
        balance: balance,
        savingsRate: savingsRate,
      ),
      if (d.incomeByMonth.isNotEmpty || d.expenseByMonth.isNotEmpty) ...[
        const SectionHeader(title: 'Ingresos vs Gastos por mes'),
        _MonthlyBarChart(
          incomeByMonth: d.incomeByMonth,
          expenseByMonth: d.expenseByMonth,
        ),
      ],
      if (d.expenseByCategory.isNotEmpty) ...[
        const SectionHeader(title: 'Gastos por categoría'),
        _CategoryPieChart(
          byCategory: d.expenseByCategory,
          categories: d.categories,
        ),
      ],
      if (d.incomeByPerson.isNotEmpty) ...[
        const SectionHeader(title: 'Ingresos por persona'),
        _PersonBarSection(
          byPerson: d.incomeByPerson,
          persons: d.persons,
        ),
      ],
      if (d.expenseByPerson.isNotEmpty) ...[
        const SectionHeader(title: 'Gastos por persona'),
        _PersonBarSection(
          byPerson: d.expenseByPerson,
          persons: d.persons,
        ),
      ],
      if (d.fixedExpenseRecurring > 0 || d.variableExpenseRecurring > 0) ...[
        const SectionHeader(title: 'Gastos fijos vs variables'),
        _FixedVsVariableCard(
          fixed: d.fixedExpenseRecurring,
          variable: d.variableExpenseRecurring,
        ),
      ],
      if (d.expenseByAccount.isNotEmpty) ...[
        const SectionHeader(title: 'Gastos por cuenta'),
        _AccountList(
          byAccount: d.expenseByAccount,
          accounts: d.accounts,
        ),
      ],
    ];

    return [
      for (var i = 0; i < sections.length; i++)
        SliverToBoxAdapter(
          child: FadeInUp(
            delay: Duration(milliseconds: 50 * i),
            child: sections[i],
          ),
        ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class ReportsData {
  final int totalIncome;
  final int totalExpense;
  final Map<int, int> incomeByCategory;
  final Map<int, int> expenseByCategory;
  final Map<int, int> incomeByPerson;
  final Map<int, int> expenseByPerson;
  final Map<String, int> incomeByMonth;
  final Map<String, int> expenseByMonth;
  final Map<int, int> expenseByAccount;
  final int fixedExpenseRecurring;
  final int variableExpenseRecurring;
  final dynamic categories;
  final List persons;
  final List accounts;

  const ReportsData({
    required this.totalIncome,
    required this.totalExpense,
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.incomeByPerson,
    required this.expenseByPerson,
    required this.incomeByMonth,
    required this.expenseByMonth,
    required this.expenseByAccount,
    required this.fixedExpenseRecurring,
    required this.variableExpenseRecurring,
    required this.categories,
    required this.persons,
    required this.accounts,
  });
}

// ---------------------------------------------------------------------------
// Summary cards
// ---------------------------------------------------------------------------

class _SummaryCards extends StatelessWidget {
  final int income;
  final int expense;
  final int balance;
  final double savingsRate;

  const _SummaryCards({
    required this.income,
    required this.expense,
    required this.balance,
    required this.savingsRate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Ingresos',
              cents: income,
              color: AppColors.income,
              icon: Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Gastos',
              cents: expense,
              color: AppColors.expense,
              icon: Icons.arrow_upward,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int cents;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.cents,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 18,
      tint: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedMoney(
              cents: cents,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly bar chart
// ---------------------------------------------------------------------------

class _MonthlyBarChart extends StatelessWidget {
  final Map<String, int> incomeByMonth;
  final Map<String, int> expenseByMonth;

  const _MonthlyBarChart({
    required this.incomeByMonth,
    required this.expenseByMonth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = <String>{
      ...incomeByMonth.keys,
      ...expenseByMonth.keys,
    }.toList()..sort();
    if (months.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Sin datos para el gráfico mensual.'),
      );
    }

    final maxY = months.fold<double>(0, (m, key) {
      final inc = (incomeByMonth[key] ?? 0).toDouble();
      final exp = (expenseByMonth[key] ?? 0).toDouble();
      return m > inc && m > exp ? m : (inc > exp ? inc : exp);
    });

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < months.length; i++) {
      final key = months[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: (incomeByMonth[key] ?? 0).toDouble(),
              color: AppColors.income,
              width: months.length > 6 ? 6 : 10,
            ),
            BarChartRodData(
              toY: (expenseByMonth[key] ?? 0).toDouble(),
              color: AppColors.expense,
              width: months.length > 6 ? 6 : 10,
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
            const Row(
              children: [
                _LegendDot(color: AppColors.income, label: 'Ingresos'),
                SizedBox(width: 12),
                _LegendDot(color: AppColors.expense, label: 'Gastos'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.2,
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
                          final i = value.toInt();
                          if (i < 0 || i >= months.length) {
                            return const SizedBox.shrink();
                          }
                          final parts = months[i].split('-');
                          if (parts.length != 2) return const SizedBox.shrink();
                          final monthNum = int.tryParse(parts[1]);
                          if (monthNum == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _monthShort(monthNum),
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
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Colors.black12, strokeWidth: 1),
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

  String _monthShort(int m) {
    const names = [
      '',
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return (m >= 1 && m <= 12) ? names[m] : '$m';
  }
}

// ---------------------------------------------------------------------------
// Category pie chart
// ---------------------------------------------------------------------------

class _CategoryPieChart extends StatelessWidget {
  final Map<int, int> byCategory;
  final dynamic categories;

  const _CategoryPieChart({required this.byCategory, required this.categories});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Sin gastos por categoría.'),
      );
    }

    final items = <_PieItem>[];
    for (final e in entries) {
      final cat = categories.byId(e.key);
      items.add(
        _PieItem(
          label: cat?.name ?? 'Categoría ${e.key}',
          value: e.value,
          percent: (e.value / total * 100).round(),
        ),
      );
    }

    final top = items.take(6).toList();
    final otherSum = items.skip(6).fold<int>(0, (s, i) => s + i.value);
    if (otherSum > 0) {
      top.add(
        _PieItem(
          label: 'Otros',
          value: otherSum,
          percent: (otherSum / total * 100).round(),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < top.length; i++) {
      sections.add(
        PieChartSectionData(
          value: top[i].value.toDouble(),
          title: '${top[i].percent}%',
          color: AppColors.chartPalette[i % AppColors.chartPalette.length],
          radius: 40,
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
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 35,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < top.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors
                            .chartPalette[i % AppColors.chartPalette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        top[i].label,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${top[i].percent}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      MoneyUtils.formatCompact(top[i].value),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PieItem {
  final String label;
  final int value;
  final int percent;
  const _PieItem({
    required this.label,
    required this.value,
    required this.percent,
  });
}

// ---------------------------------------------------------------------------
// Person bar sections
// ---------------------------------------------------------------------------

class _PersonBarSection extends StatelessWidget {
  final Map<int, int> byPerson;
  final List persons;

  const _PersonBarSection({required this.byPerson, required this.persons});

  @override
  Widget build(BuildContext context) {
    final entries = byPerson.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) return const SizedBox.shrink();

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              _personRow(
                context,
                personName: _nameById(persons, entries[i].key),
                amount: entries[i].value,
                percent: (entries[i].value / total * 100).round(),
                color:
                    AppColors.chartPalette[i % AppColors.chartPalette.length],
              ),
              if (i < entries.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _personRow(
    BuildContext context, {
    required String personName,
    required int amount,
    required int percent,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                personName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              MoneyUtils.format(amount),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent / 100.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }

  String _nameById(List list, int id) {
    for (final p in list) {
      if (p.id == id) return p.name;
    }
    return 'Sin persona';
  }
}

// ---------------------------------------------------------------------------
// Fixed vs Variable card
// ---------------------------------------------------------------------------

class _FixedVsVariableCard extends StatelessWidget {
  final int fixed;
  final int variable;

  const _FixedVsVariableCard({required this.fixed, required this.variable});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = fixed + variable;
    if (total == 0) return const SizedBox.shrink();

    final fixedPct = total > 0 ? (fixed / total * 100).round() : 0;
    final variablePct = total > 0 ? (variable / total * 100).round() : 0;

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basado en gastos recurrentes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KindCard(
                  label: 'Fijos',
                  amount: fixed,
                  percent: fixedPct,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KindCard(
                  label: 'Variables',
                  amount: variable,
                  percent: variablePct,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KindCard extends StatelessWidget {
  final String label;
  final int amount;
  final int percent;
  final Color color;

  const _KindCard({
    required this.label,
    required this.amount,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      tint: color,
      tintOpacity: 0.10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedMoney(
              cents: amount,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$percent% del total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account list
// ---------------------------------------------------------------------------

class _AccountList extends StatelessWidget {
  final Map<int, int> byAccount;
  final List accounts;

  const _AccountList({required this.byAccount, required this.accounts});

  @override
  Widget build(BuildContext context) {
    final entries = byAccount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) return const SizedBox.shrink();

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              _accountRow(
                context,
                name: _nameById(accounts, entries[i].key),
                amount: entries[i].value,
                percent: (entries[i].value / total * 100).round(),
                color:
                    AppColors.chartPalette[i % AppColors.chartPalette.length],
              ),
              if (i < entries.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _accountRow(
    BuildContext context, {
    required String name,
    required int amount,
    required int percent,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: percent / 100.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 4,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              MoneyUtils.format(amount),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$percent%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _nameById(List list, int id) {
    for (final a in list) {
      if (a.id == id) return a.name;
    }
    return 'Cuenta #$id';
  }
}

// ---------------------------------------------------------------------------
// PDF export options
// ---------------------------------------------------------------------------

class _PdfSectionPickerDialog extends StatefulWidget {
  const _PdfSectionPickerDialog();

  @override
  State<_PdfSectionPickerDialog> createState() =>
      _PdfSectionPickerDialogState();
}

class _PdfSectionPickerDialogState extends State<_PdfSectionPickerDialog> {
  static const _titles = {
    PdfReportSection.summary: 'Resumen del período',
    PdfReportSection.incomeByCategory: 'Ingresos por categoría',
    PdfReportSection.expenseByCategory: 'Gastos por categoría',
    PdfReportSection.incomeByPerson: 'Ingresos por persona',
    PdfReportSection.expenseByPerson: 'Gastos por persona',
    PdfReportSection.expenseByAccount: 'Gastos por cuenta',
    PdfReportSection.movements: 'Movimientos del período',
  };

  final Set<PdfReportSection> _selected = {
    PdfReportSection.summary,
    PdfReportSection.incomeByCategory,
    PdfReportSection.expenseByCategory,
    PdfReportSection.incomeByPerson,
    PdfReportSection.expenseByPerson,
    PdfReportSection.expenseByAccount,
    PdfReportSection.movements,
  };

  void _toggle(PdfReportSection section, bool value) {
    setState(() {
      if (value) {
        _selected.add(section);
      } else {
        _selected.remove(section);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Exportar informe PDF'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seleccioná qué secciones incluir:'),
            const SizedBox(height: 8),
            for (final entry in _titles.entries)
              CheckboxListTile(
                value: _selected.contains(entry.key),
                title: Text(entry.value),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => _toggle(entry.key, v ?? false),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Exportar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Legend dot
// ---------------------------------------------------------------------------

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
