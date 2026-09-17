import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/transaction_type.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../presentation/common/amount_display.dart';
import '../../presentation/common/empty_state.dart';
import '../../presentation/common/person_avatar.dart';
import '../../presentation/providers/app_provider.dart';
import '../../utils/formatters.dart' as fmt;
import '../../core/theme/app_colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  TransactionType? _typeFilter;
  DateTimeRange? _dateRange;
  int? _personId;
  int? _categoryId;
  int? _accountId;
  String? _minAmount;
  String? _maxAmount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().person.loadAll();
      context.read<AppProvider>().account.loadAll();
      context.read<AppProvider>().category.loadAll();
      context.read<AppProvider>().transaction.clearFilter();
      context.read<AppProvider>().transaction.loadAll();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _applyFilter();
    });
  }

  Future<void> _applyFilter() async {
    final min = int.tryParse(_minAmount ?? '') ?? 0;
    final max = int.tryParse(_maxAmount ?? '');
    final filter = TransactionFilter(
      from: _dateRange?.start,
      to: _dateRange?.end,
      personId: _personId,
      categoryId: _categoryId,
      accountId: _accountId,
      type: _typeFilter,
      minAmount: min > 0 ? min * 100 : null,
      maxAmount: max != null ? max * 100 : null,
      searchText: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
    await context.read<AppProvider>().transaction.setFilter(filter);
    if (mounted) setState(() {});
  }

  Future<void> _openFilters() async {
    final app = context.read<AppProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FilterSheet(
        persons: app.person.persons,
        accounts: app.account.accounts,
        categories: app.category.expenseCategories,
        typeFilter: _typeFilter,
        dateRange: _dateRange,
        personId: _personId,
        categoryId: _categoryId,
        accountId: _accountId,
        minAmount: _minAmount,
        maxAmount: _maxAmount,
        onApplied: (result) {
          _typeFilter = result.typeFilter;
          _dateRange = result.dateRange;
          _personId = result.personId;
          _categoryId = result.categoryId;
          _accountId = result.accountId;
          _minAmount = result.minAmount;
          _maxAmount = result.maxAmount;
        },
      ),
    );
    await _applyFilter();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _searchController.clear();
      _typeFilter = null;
      _dateRange = null;
      _personId = null;
      _categoryId = null;
      _accountId = null;
      _minAmount = null;
      _maxAmount = null;
    });
    await context.read<AppProvider>().transaction.clearFilter();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final transactions = app.transaction.transactions;
    final category = app.category;

    return Scaffold(
      appBar: AppBar(title: const Text('Búsqueda')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Buscar por descripción...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _openFilters,
                  tooltip: 'Filtros',
                  icon: Badge(
                    isLabelVisible: _hasActiveFilters,
                    child: const Icon(Icons.tune),
                  ),
                ),
              ],
            ),
          ),
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Filtros activos')),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: transactions.isEmpty
                ? EmptyState(
                    icon: Icons.search_off,
                    title: 'Sin resultados',
                    subtitle: 'Probá con otra búsqueda o ajustá los filtros.',
                  )
                : ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (_, i) =>
                        Divider(height: 1, indent: 72, endIndent: 16),
                    itemBuilder: (context, i) {
                      final t = transactions[i];
                      return _SearchResultTile(
                        transaction: t,
                        categoryName: category.byId(t.categoryId)?.name,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/transactions/edit',
                            arguments: {'id': t.id},
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  bool get _hasActiveFilters =>
      _typeFilter != null ||
      _dateRange != null ||
      _personId != null ||
      _categoryId != null ||
      _accountId != null ||
      (_minAmount?.isNotEmpty ?? false) ||
      (_maxAmount?.isNotEmpty ?? false);
}

class _SearchResultTile extends StatelessWidget {
  final dynamic transaction;
  final String? categoryName;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.transaction,
    required this.categoryName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = transaction.type as TransactionType;
    final (IconData icon, Color color) = switch (type) {
      TransactionType.income => (Icons.trending_up, AppColors.income),
      TransactionType.expense => (Icons.trending_down, AppColors.expense),
      TransactionType.transfer => (Icons.swap_horiz, AppColors.transfer),
    };

    final title = transaction.description.isNotEmpty
        ? transaction.description
        : (categoryName ?? type.label);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${fmt.DateUtils.shortDate(transaction.date)} · ${type.label}',
      ),
      trailing: AmountDisplay(
        cents: transaction.amount as int,
        showSign: true,
        positiveColor: AppColors.income,
        negativeColor: AppColors.expense,
      ),
      onTap: onTap,
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final List<dynamic> persons;
  final List<dynamic> accounts;
  final List<dynamic> categories;
  final TransactionType? typeFilter;
  final DateTimeRange? dateRange;
  final int? personId;
  final int? categoryId;
  final int? accountId;
  final String? minAmount;
  final String? maxAmount;
  final void Function(_FilterResult result) onApplied;

  const _FilterSheet({
    required this.persons,
    required this.accounts,
    required this.categories,
    required this.typeFilter,
    required this.dateRange,
    required this.personId,
    required this.categoryId,
    required this.accountId,
    required this.minAmount,
    required this.maxAmount,
    required this.onApplied,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterResult {
  final TransactionType? typeFilter;
  final DateTimeRange? dateRange;
  final int? personId;
  final int? categoryId;
  final int? accountId;
  final String? minAmount;
  final String? maxAmount;

  const _FilterResult({
    this.typeFilter,
    this.dateRange,
    this.personId,
    this.categoryId,
    this.accountId,
    this.minAmount,
    this.maxAmount,
  });
}

class _FilterSheetState extends State<_FilterSheet> {
  late TransactionType? _type;
  late DateTimeRange? _range;
  late int? _personId;
  late int? _categoryId;
  late int? _accountId;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _type = widget.typeFilter;
    _range = widget.dateRange;
    _personId = widget.personId;
    _categoryId = widget.categoryId;
    _accountId = widget.accountId;
    _minCtrl = TextEditingController(text: widget.minAmount ?? '');
    _maxCtrl = TextEditingController(text: widget.maxAmount ?? '');
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  void _apply() {
    Navigator.of(context).pop();
    widget.onApplied(
      _FilterResult(
        typeFilter: _type,
        dateRange: _range,
        personId: _personId,
        categoryId: _categoryId,
        accountId: _accountId,
        minAmount: _minCtrl.text.trim(),
        maxAmount: _maxCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtros', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in [
                  (null, 'Todos'),
                  (TransactionType.income, 'Ingresos'),
                  (TransactionType.expense, 'Gastos'),
                  (TransactionType.transfer, 'Transferencias'),
                ])
                  ChoiceChip(
                    label: Text(e.$2),
                    selected: _type == e.$1,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _type = e.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.date_range),
              title: Text(
                _range == null
                    ? 'Rango de fechas'
                    : '${fmt.DateUtils.shortDate(_range!.start)} - ${fmt.DateUtils.shortDate(_range!.end)}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: _pickRange,
              ),
            ),
            DropdownButtonFormField<int>(
              initialValue: _personId,
              decoration: const InputDecoration(labelText: 'Persona'),
              items: [
                const DropdownMenuItem<int>(value: null, child: Text('Todas')),
                ...widget.persons.map(
                  (p) => DropdownMenuItem<int>(
                    value: p.id as int,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PersonAvatar(
                          name: p.name as String,
                          color: p.color as String? ?? '',
                          avatar: p.avatar as String? ?? '',
                          radius: 12,
                        ),
                        const SizedBox(width: 8),
                        Text(p.name as String),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _personId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                const DropdownMenuItem<int>(value: null, child: Text('Todas')),
                ...widget.categories.map(
                  (c) => DropdownMenuItem<int>(
                    value: c.id as int,
                    child: Text(c.name as String),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Cuenta'),
              items: [
                const DropdownMenuItem<int>(value: null, child: Text('Todas')),
                ...widget.accounts.map(
                  (a) => DropdownMenuItem<int>(
                    value: a.id as int,
                    child: Text(a.name as String),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto mín.',
                      prefixText: r'$ ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto máx.',
                      prefixText: r'$ ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _apply,
                child: const Text('Aplicar filtros'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
