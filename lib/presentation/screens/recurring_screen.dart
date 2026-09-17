import 'package:flutter/material.dart' hide DateUtils;
import 'package:provider/provider.dart';

import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/recurring_frequency.dart';
import '../../domain/entities/expense_kind.dart';
import '../../utils/formatters.dart';
import '../common/amount_display.dart';
import '../common/confirm_dialog.dart';
import '../common/empty_state.dart';
import '../providers/app_provider.dart';
import '../../core/theme/app_colors.dart';
import '../common/glass_card.dart';

enum _Filter { all, fixed, variable, income }

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  _Filter _filter = _Filter.all;

  List<RecurringTransaction> _filtered(List<RecurringTransaction> all) {
    switch (_filter) {
      case _Filter.all:
        return all;
      case _Filter.fixed:
        return all
            .where((r) => !r.isIncome && r.kind == ExpenseKind.fixed)
            .toList();
      case _Filter.variable:
        return all
            .where((r) => !r.isIncome && r.kind == ExpenseKind.variable)
            .toList();
      case _Filter.income:
        return all.where((r) => r.isIncome).toList();
    }
  }

  DateTime _nextDueDate(RecurringTransaction r) {
    final now = DateTime.now();
    final currentDay = now.day;

    switch (r.frequency) {
      case RecurringFrequency.weekly:
        final daysAhead = (r.dueDay - currentDay) % 7;
        return now.add(Duration(days: daysAhead == 0 ? 7 : daysAhead));
      case RecurringFrequency.fortnightly:
        final base = r.startDate;
        final diff = now.difference(base).inDays;
        final period = 14;
        final elapsed = diff % period;
        final daysUntil = period - elapsed;
        return now.add(Duration(days: daysUntil));
      case RecurringFrequency.monthly:
        final targetDay = r.dueDay.clamp(1, 28);
        if (currentDay <= targetDay) {
          return DateTime(now.year, now.month, targetDay);
        } else {
          return DateTime(now.year, now.month + 1, targetDay);
        }
      case RecurringFrequency.yearly:
        final targetDay = r.dueDay.clamp(1, 28);
        final nextYear =
            now.month < r.startDate.month ||
                (now.month == r.startDate.month && now.day < targetDay)
            ? now.year
            : now.year + 1;
        return DateTime(nextYear, r.startDate.month, targetDay);
    }
  }

  Future<void> _openForm({RecurringTransaction? existing}) async {
    final result = await showModalBottomSheet<RecurringTransaction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RecurringFormSheet(existing: existing),
    );
    if (result == null || !mounted) return;

    final provider = context.read<AppProvider>().recurring;
    if (existing == null) {
      await provider.add(result);
    } else {
      await provider.update(result);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Recurrente creado' : 'Recurrente actualizado',
          ),
        ),
      );
    }
  }

  Future<void> _delete(RecurringTransaction r) async {
    if (r.id == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar recurrente',
      message: '¿Seguro que deseas eliminar "${r.name}"?',
    );
    if (!confirmed || !mounted) return;
    await context.read<AppProvider>().recurring.delete(r.id!);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recurrente eliminado')));
    }
  }

  Future<void> _toggleActive(RecurringTransaction r) async {
    if (r.id == null) return;
    await context.read<AppProvider>().recurring.update(
      r.copyWith(isActive: !r.isActive),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final all = app.recurring.recurringTransactions;
    final filtered = _filtered(all);
    final catProvider = app.category;
    final accProvider = app.account;

    final expenses = all.where((r) => !r.isIncome && r.isActive).toList();
    final upcoming = expenses.map((r) => (r, _nextDueDate(r))).where((pair) {
      final d = pair.$2;
      final now = DateTime.now();
      final endOfNextMonth = DateTime(now.year, now.month + 2, 0);
      return !d.isBefore(DateTime(now.year, now.month, 1)) &&
          !d.isAfter(endOfNextMonth);
    }).toList()..sort((a, b) => a.$2.compareTo(b.$2));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurrentes'),
        actions: [
          IconButton(
            tooltip: 'Nuevo recurrente',
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: all.isEmpty
          ? EmptyState(
              icon: Icons.replay_outlined,
              title: 'Sin movimientos recurrentes',
              subtitle:
                  'Crea gastos fijos, variables o ingresos recurrentes para llevar el control automático.',
              action: FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo recurrente'),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_Filter>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: _Filter.all, label: Text('Todos')),
                        ButtonSegment(
                          value: _Filter.fixed,
                          label: Text('Fijos'),
                        ),
                        ButtonSegment(
                          value: _Filter.variable,
                          label: Text('Variables'),
                        ),
                        ButtonSegment(
                          value: _Filter.income,
                          label: Text('Ingresos'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (sel) =>
                          setState(() => _filter = sel.first),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (upcoming.isNotEmpty && _filter != _Filter.income) ...[
                        Text(
                          'Próximos vencimientos',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        for (final pair in upcoming)
                          _UpcomingTile(
                            transaction: pair.$1,
                            dueDate: pair.$2,
                            category: catProvider.byId(pair.$1.categoryId),
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: EmptyState(
                            icon: Icons.replay_outlined,
                            title: 'Sin resultados',
                            subtitle:
                                'No hay recurrentes para el filtro seleccionado.',
                          ),
                        )
                      else ...[
                        Text(
                          'Lista de recurrentes',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        for (final r in filtered)
                          _RecurringCard(
                            transaction: r,
                            category: catProvider.byId(r.categoryId),
                            account: accProvider.accounts
                                .where((a) => a.id == r.accountId)
                                .firstOrNull,
                            onTap: () => _openForm(existing: r),
                            onLongPress: () => _delete(r),
                            onToggle: () => _toggleActive(r),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final RecurringTransaction transaction;
  final DateTime dueDate;
  final dynamic category;

  const _UpcomingTile({
    required this.transaction,
    required this.dueDate,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = transaction;
    final dayStr =
        '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}';

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: r.isIncome
              ? AppColors.income.withValues(alpha: 0.12)
              : AppColors.expense.withValues(alpha: 0.12),
          child: Icon(
            r.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            size: 18,
            color: r.isIncome ? AppColors.income : AppColors.expense,
          ),
        ),
        title: Text(
          r.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '$dayStr · ${r.frequency.label}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!r.isIncome) _KindChip(kind: r.kind),
            const SizedBox(width: 8),
            AmountDisplay(
              cents: r.isIncome ? r.amount : -r.amount,
              showSign: true,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  final ExpenseKind kind;

  const _KindChip({required this.kind});

  @override
  Widget build(BuildContext context) {
    final color = kind == ExpenseKind.fixed
        ? AppColors.transfer
        : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        kind.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  final RecurringTransaction transaction;
  final dynamic category;
  final dynamic account;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;

  const _RecurringCard({
    required this.transaction,
    this.category,
    this.account,
    required this.onTap,
    required this.onLongPress,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = transaction;

    return Opacity(
      opacity: r.isActive ? 1.0 : 0.5,
      child: GlassCard(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (r.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              r.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Switch(value: r.isActive, onChanged: (_) => onToggle()),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AmountDisplay(
                      cents: r.isIncome ? r.amount : -r.amount,
                      showSign: true,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${r.frequency.label} · Día ${r.dueDay}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (category != null)
                      _InfoChip(
                        icon: Icons.category_outlined,
                        label: category!.name,
                      ),
                    if (account != null)
                      _InfoChip(
                        icon: Icons.account_balance_wallet_outlined,
                        label: account!.name,
                      ),
                    if (!r.isIncome) _KindChip(kind: r.kind),
                    if (r.startDate != DateTime(2000))
                      _InfoChip(
                        icon: Icons.event,
                        label: 'Inicio: ${DateUtils.shortDate(r.startDate)}',
                      ),
                    if (r.endDate != null)
                      _InfoChip(
                        icon: Icons.event_busy,
                        label: 'Fin: ${DateUtils.shortDate(r.endDate!)}',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringFormSheet extends StatefulWidget {
  final RecurringTransaction? existing;

  const _RecurringFormSheet({this.existing});

  @override
  State<_RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends State<_RecurringFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _dueDayCtrl;
  late final TextEditingController _descCtrl;

  late bool _isIncome;
  late RecurringFrequency _frequency;
  late ExpenseKind _kind;
  int? _categoryId;
  int? _accountId;
  int? _personId;
  late DateTime _startDate;
  DateTime? _endDate;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _amountCtrl = TextEditingController(
      text: r == null ? '' : MoneyUtils.fromCents(r.amount).toString(),
    );
    _dueDayCtrl = TextEditingController(text: r?.dueDay.toString() ?? '1');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _isIncome = r?.isIncome ?? false;
    _frequency = r?.frequency ?? RecurringFrequency.monthly;
    _kind = r?.kind ?? ExpenseKind.variable;
    _categoryId = r?.categoryId;
    _accountId = r?.accountId;
    _personId = r?.personId;
    _startDate = r?.startDate ?? DateTime.now();
    _endDate = r?.endDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _dueDayCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final raw = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (raw == null || raw <= 0) return;

    final dueDay = int.tryParse(_dueDayCtrl.text);
    if (dueDay == null || dueDay < 1 || dueDay > 31) return;

    final existing = widget.existing;
    Navigator.of(context).pop(
      RecurringTransaction(
        id: existing?.id,
        name: _nameCtrl.text.trim(),
        amount: MoneyUtils.toCents(raw),
        isIncome: _isIncome,
        categoryId: _categoryId,
        accountId: _accountId,
        personId: _personId,
        frequency: _frequency,
        dueDay: dueDay,
        startDate: _startDate,
        endDate: _endDate,
        isActive: existing?.isActive ?? true,
        kind: _isIncome ? ExpenseKind.variable : _kind,
        description: _descCtrl.text.trim(),
        createdAt: existing?.createdAt,
        updatedAt: existing?.updatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final categories = _isIncome
        ? app.category.incomeCategories
        : app.category.expenseCategories;
    final accounts = app.account.accounts;
    final persons = app.person.persons;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomPadding),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Editar recurrente' : 'Nuevo recurrente',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Gasto')),
                  ButtonSegment(value: true, label: Text('Ingreso')),
                ],
                selected: {_isIncome},
                onSelectionChanged: (sel) => setState(() {
                  _isIncome = sel.first;
                  _categoryId = null;
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa un nombre';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: r'$ ',
                  prefixIcon: Icon(Icons.payments),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa un monto';
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sin categoría'),
                  ),
                  for (final c in categories)
                    DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Cuenta',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sin cuenta'),
                  ),
                  for (final a in accounts)
                    DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              if (persons.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _personId,
                  decoration: const InputDecoration(
                    labelText: 'Persona (opcional)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Ninguna'),
                    ),
                    for (final p in persons)
                      DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => setState(() => _personId = v),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurringFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Frecuencia',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: [
                  for (final f in RecurringFrequency.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _frequency = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dueDayCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Día de vencimiento (1-31)',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingresa un día';
                  }
                  final d = int.tryParse(v);
                  if (d == null || d < 1 || d > 31) return 'Día inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.event),
                      label: Text('Inicio: ${DateUtils.shortDate(_startDate)}'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.event_busy),
                      label: Text(
                        _endDate == null
                            ? 'Sin fecha de fin'
                            : 'Fin: ${DateUtils.shortDate(_endDate!)}',
                      ),
                    ),
                  ),
                  if (_endDate != null)
                    IconButton(
                      tooltip: 'Quitar fecha de fin',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _endDate = null),
                    ),
                ],
              ),
              if (!_isIncome) ...[
                const SizedBox(height: 8),
                SegmentedButton<ExpenseKind>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ExpenseKind.fixed,
                      label: Text('Fijo'),
                    ),
                    ButtonSegment(
                      value: ExpenseKind.variable,
                      label: Text('Variable'),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (sel) =>
                      setState(() => _kind = sel.first),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? 'Guardar' : 'Crear'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
