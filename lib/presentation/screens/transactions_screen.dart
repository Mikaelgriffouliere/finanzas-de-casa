import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/utils/haptic_helper.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/subcategory.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_type.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../utils/formatters.dart' as fmt;
import '../common/amount_display.dart';
import '../common/empty_state.dart';
import '../providers/app_provider.dart';
import 'transaction_form_screen.dart';
import 'transaction_detail_screen.dart';
import '../../core/theme/app_colors.dart';
import '../common/glass_card.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  static const String routeName = '/transactions';

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  TransactionType? _type;

  DateTime? _filterFrom;
  DateTime? _filterTo;
  int? _filterPersonId;
  int? _filterCategoryId;
  int? _filterAccountId;
  int? _filterMin;
  int? _filterMax;
  bool _hasCustomRange = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>().transaction;
    TransactionFilter base;

    if (_hasCustomRange) {
      base = TransactionFilter(from: _filterFrom, to: _filterTo);
    } else {
      base = TransactionFilter(
        from: fmt.DateUtils.startOfMonth(_month),
        to: fmt.DateUtils.endOfMonth(_month),
      );
    }

    base = base.copyWith(
      personId: _filterPersonId,
      categoryId: _filterCategoryId,
      accountId: _filterAccountId,
      minAmount: _filterMin,
      maxAmount: _filterMax,
      type: _type,
    );

    await provider.setFilter(base);
  }

  void _changeMonth(int delta) {
    setState(() {
      _hasCustomRange = false;
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
    _load();
  }

  Future<void> _openFilters() async {
    final app = context.read<AppProvider>();
    final results = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FilterSheet(
        from: _filterFrom,
        to: _filterTo,
        personId: _filterPersonId,
        categoryId: _filterCategoryId,
        accountId: _filterAccountId,
        min: _filterMin,
        max: _filterMax,
        hasCustomRange: _hasCustomRange,
        persons: app.person.persons,
        categories: app.category.expenseCategories,
        accounts: app.account.accounts,
      ),
    );

    if (results == null) return;

    setState(() {
      _filterFrom = results.from;
      _filterTo = results.to;
      _filterPersonId = results.personId;
      _filterCategoryId = results.categoryId;
      _filterAccountId = results.accountId;
      _filterMin = results.min;
      _filterMax = results.max;
      _hasCustomRange = results.useCustomRange;
    });
    _load();
  }

  void _clearFilters() {
    if (_filterFrom == null &&
        _filterTo == null &&
        _filterPersonId == null &&
        _filterCategoryId == null &&
        _filterAccountId == null &&
        _filterMin == null &&
        _filterMax == null &&
        !_hasCustomRange) {
      return;
    }
    setState(() {
      _filterFrom = null;
      _filterTo = null;
      _filterPersonId = null;
      _filterCategoryId = null;
      _filterAccountId = null;
      _filterMin = null;
      _filterMax = null;
      _hasCustomRange = false;
    });
    _load();
  }

  Future<void> _goToForm() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          initialType: _type ?? TransactionType.expense,
        ),
      ),
    );
    _load();
  }

  Future<void> _openTransaction(Transaction transaction) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transaction: transaction),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final transactions = app.transaction.transactions;

    final List<_DayGroup> groups = _groupByDay(transactions);

    final hasActiveFilters =
        _hasCustomRange ||
        _filterPersonId != null ||
        _filterCategoryId != null ||
        _filterAccountId != null ||
        _filterMin != null ||
        _filterMax != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        actions: [
          IconButton(
            tooltip: 'Filtros',
            icon: Badge(
              isLabelVisible: hasActiveFilters,
              smallSize: 8,
              child: const Icon(Icons.search),
            ),
            onPressed: _openFilters,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToForm,
        icon: const Icon(Icons.add),
        label: const Text('Movimiento'),
      ),
      body: Column(
        children: [
          _MonthSelector(
            month: _month,
            highlighted: hasActiveFilters,
            onPrevious: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
            onClearFilters: hasActiveFilters ? _clearFilters : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<TransactionType?>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Tipo de movimiento',
                prefixIcon: Icon(Icons.filter_alt_outlined),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todos')),
                DropdownMenuItem(
                  value: TransactionType.income,
                  child: Text('Ingresos'),
                ),
                DropdownMenuItem(
                  value: TransactionType.expense,
                  child: Text('Gastos'),
                ),
                DropdownMenuItem(
                  value: TransactionType.transfer,
                  child: Text('Transferencias'),
                ),
              ],
              onChanged: (value) {
                HapticHelper.selection();
                setState(() => _type = value);
                _load();
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: transactions.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long,
                    title: 'Sin movimientos',
                    subtitle: hasActiveFilters
                        ? 'No hay movimientos que coincidan con los filtros.'
                        : 'Registra tu primer movimiento',
                    action: FilledButton.icon(
                      onPressed: _goToForm,
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () {
                      HapticHelper.light();
                      return _load();
                    },
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        for (final group in groups) ...[
                          _DayHeader(date: group.date),
                          for (final transaction in group.transactions)
                            _TransactionListItem(
                              transaction: transaction,
                              category: app.category.byId(
                                transaction.categoryId,
                              ),
                              subcategory: app.category.subcategoryById(
                                transaction.subcategoryId,
                              ),
                              person: _personById(
                                app.person.persons,
                                transaction.personId,
                              ),
                              account: _accountById(
                                app.account.accounts,
                                transaction.accountId,
                              ),
                              transferAccount: _accountById(
                                app.account.accounts,
                                transaction.transferAccountId,
                              ),
                              onTap: () => _openTransaction(transaction),
                            ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Person? _personById(List<Person> persons, int? id) {
    if (id == null) return null;
    for (final p in persons) {
      if (p.id == id) return p;
    }
    return null;
  }

  Account? _accountById(List<Account> accounts, int? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<_DayGroup> _groupByDay(List<Transaction> transactions) {
    final groups = <String, _DayGroup>{};
    for (final t in transactions) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      final key = '${day.year}-${day.month}-${day.day}';
      final group = groups.putIfAbsent(
        key,
        () => _DayGroup(date: day, transactions: []),
      );
      group.transactions.add(t);
    }
    final result = groups.values.toList();
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }
}

class _DayGroup {
  final DateTime date;
  final List<Transaction> transactions;

  _DayGroup({required this.date, required this.transactions});
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final bool highlighted;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onClearFilters;

  const _MonthSelector({
    required this.month,
    required this.highlighted,
    required this.onPrevious,
    required this.onNext,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Center(
              child: Text(
                fmt.DateUtils.monthYear(month),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          if (onClearFilters != null)
            IconButton(
              tooltip: 'Limpiar filtros',
              icon: const Icon(Icons.filter_alt_off),
              onPressed: onClearFilters,
            ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime date;

  const _DayHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    String label;
    final today = DateTime(now.year, now.month, now.day);
    if (date == today) {
      label = 'Hoy';
    } else if (date == today.subtract(const Duration(days: 1))) {
      label = 'Ayer';
    } else {
      label = DateFormat('d MMM').format(date);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final Subcategory? subcategory;
  final Person? person;
  final Account? account;
  final Account? transferAccount;
  final VoidCallback onTap;

  const _TransactionListItem({
    required this.transaction,
    this.category,
    this.subcategory,
    this.person,
    this.account,
    this.transferAccount,
    required this.onTap,
  });

  IconData get _icon {
    switch (transaction.type) {
      case TransactionType.income:
        return Icons.trending_up;
      case TransactionType.expense:
        return Icons.trending_down;
      case TransactionType.transfer:
        return Icons.swap_horiz;
    }
  }

  Color _color(BuildContext context) {
    switch (transaction.type) {
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.transfer:
        return AppColors.transfer;
    }
  }

  String get _title {
    if (transaction.description.isNotEmpty) return transaction.description;
    if (category != null) return category!.name;
    return transaction.type.label;
  }

  String? get _subtitle {
    final parts = <String>[];
    if (subcategory != null) parts.add(subcategory!.name);
    if (person != null) parts.add(person!.name);
    if (transaction.type == TransactionType.transfer) {
      final from = account?.name;
      final to = transferAccount?.name;
      if (from != null && to != null) {
        parts.add('$from → $to');
      } else if (from != null) {
        parts.add('Desde $from');
      } else if (to != null) {
        parts.add('Hacia $to');
      }
    } else {
      if (account != null) parts.add(account!.name);
    }
    return parts.isEmpty ? null : parts.join(' - ');
  }

  @override
  Widget build(BuildContext context) {
    final signedCents = transaction.type == TransactionType.expense
        ? -transaction.amount
        : transaction.amount;

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _color(context).withValues(alpha: 0.15),
          child: Icon(_icon, color: _color(context)),
        ),
        title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: _subtitle == null
            ? null
            : Text(_subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: AmountDisplay(cents: signedCents, showSign: true),
      ),
    );
  }
}

class _FilterResult {
  final DateTime? from;
  final DateTime? to;
  final int? personId;
  final int? categoryId;
  final int? accountId;
  final int? min;
  final int? max;
  final bool useCustomRange;

  _FilterResult({
    this.from,
    this.to,
    this.personId,
    this.categoryId,
    this.accountId,
    this.min,
    this.max,
    required this.useCustomRange,
  });
}

class _FilterSheet extends StatefulWidget {
  final DateTime? from;
  final DateTime? to;
  final int? personId;
  final int? categoryId;
  final int? accountId;
  final int? min;
  final int? max;
  final bool hasCustomRange;
  final List<Person> persons;
  final List<Category> categories;
  final List<Account> accounts;

  const _FilterSheet({
    required this.from,
    required this.to,
    required this.personId,
    required this.categoryId,
    required this.accountId,
    required this.min,
    required this.max,
    required this.hasCustomRange,
    required this.persons,
    required this.categories,
    required this.accounts,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DateTime? _from;
  late DateTime? _to;
  late int? _personId;
  late int? _categoryId;
  late int? _accountId;
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  late bool _useCustomRange;

  @override
  void initState() {
    super.initState();
    _from = widget.from;
    _to = widget.to;
    _personId = widget.personId;
    _categoryId = widget.categoryId;
    _accountId = widget.accountId;
    _useCustomRange = widget.hasCustomRange;
    if (widget.min != null) {
      _minController.text = (fmt.MoneyUtils.fromCents(widget.min!)).toString();
    }
    if (widget.max != null) {
      _maxController.text = (fmt.MoneyUtils.fromCents(widget.max!)).toString();
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final initial = _from != null && _to != null
        ? DateTimeRange(start: _from!, end: _to!)
        : null;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() {
        _from = fmt.DateUtils.startOfDay(picked.start);
        _to = fmt.DateUtils.endOfDay(picked.end);
        _useCustomRange = true;
      });
    }
  }

  void _apply() {
    Navigator.of(context).pop(
      _FilterResult(
        from: _from,
        to: _to,
        personId: _personId,
        categoryId: _categoryId,
        accountId: _accountId,
        min: _minController.text.trim().isEmpty
            ? null
            : fmt.MoneyUtils.toCents(double.tryParse(_minController.text) ?? 0),
        max: _maxController.text.trim().isEmpty
            ? null
            : fmt.MoneyUtils.toCents(double.tryParse(_maxController.text) ?? 0),
        useCustomRange: _useCustomRange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rango personalizado'),
                    value: _useCustomRange,
                    onChanged: (v) => setState(() => _useCustomRange = v),
                  ),
                ),
                if (_useCustomRange)
                  IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: _pickRange,
                  ),
              ],
            ),
            if (_useCustomRange)
              TextButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range),
                label: Text(
                  _from != null && _to != null
                      ? '${DateFormat('dd/MM/yyyy').format(_from!)} - ${DateFormat('dd/MM/yyyy').format(_to!)}'
                      : 'Seleccionar rango',
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _personId,
              decoration: const InputDecoration(
                labelText: 'Persona',
                prefixIcon: Icon(Icons.person),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                for (final p in widget.persons)
                  DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _personId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                prefixIcon: Icon(Icons.category),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                for (final c in widget.categories)
                  DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _accountId,
              decoration: const InputDecoration(
                labelText: 'Cuenta',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                for (final a in widget.accounts)
                  DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto mínimo',
                      prefixText: r'$ ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto máximo',
                      prefixText: r'$ ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _apply,
              child: const Text('Aplicar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}
