import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../utils/formatters.dart' as fmt;
import '../common/confirm_dialog.dart';
import '../common/empty_state.dart';
import '../providers/app_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../../core/theme/app_colors.dart';
import '../common/glass_card.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  Future<void> _openForm({Budget? budget}) async {
    final app = context.read<AppProvider>();
    if (app.category.expenseCategories.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primero crea categorías de gastos')),
        );
      }
      return;
    }

    final result = await showDialog<Budget>(
      context: context,
      builder: (_) => _BudgetFormDialog(existing: budget, month: _month),
    );
    if (result == null || !mounted) return;

    if (budget == null) {
      await app.budget.add(result);
    } else {
      await app.budget.update(result);
    }
  }

  Future<void> _deleteBudget(Budget budget) async {
    if (budget.id == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar presupuesto',
      message: '¿Seguro que deseas eliminar este presupuesto?',
    );
    if (!confirmed || !mounted) return;
    await context.read<AppProvider>().budget.delete(budget.id!);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final budgets = app.budget.budgets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presupuestos'),
        actions: [
          IconButton(
            tooltip: 'Nuevo presupuesto',
            icon: const Icon(Icons.add),
            onPressed: _openForm,
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthSelector(
            month: _month,
            onPrevious: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          Expanded(
            child: budgets.isEmpty
                ? EmptyState(
                    icon: Icons.pie_chart_outline,
                    title: 'Sin presupuestos este mes',
                    subtitle:
                        'Crea presupuestos por categoría para controlar tus gastos mensuales.',
                    action: FilledButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear presupuesto'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final budget in budgets)
                        _BudgetCard(
                          provider: app.budget,
                          categoryProvider: app.category,
                          budget: budget,
                          month: _month,
                          onEdit: () => _openForm(budget: budget),
                          onDelete: () => _deleteBudget(budget),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Mes anterior',
            onPressed: onPrevious,
          ),
          Expanded(
            child: Center(
              child: Text(
                fmt.DateUtils.monthYear(month),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Siguiente mes',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatefulWidget {
  final BudgetProvider provider;
  final CategoryProvider categoryProvider;
  final Budget budget;
  final DateTime month;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.provider,
    required this.categoryProvider,
    required this.budget,
    required this.month,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends State<_BudgetCard> {
  late Future<BudgetStatus> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _load();
  }

  @override
  void didUpdateWidget(covariant _BudgetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month || oldWidget.budget != widget.budget) {
      _statusFuture = _load();
    }
  }

  Future<BudgetStatus> _load() {
    return widget.provider.getStatus(widget.budget, month: widget.month);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = widget.categoryProvider.byId(widget.budget.categoryId);
    final accent = _accentColor(category);

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.zero,
      child: FutureBuilder<BudgetStatus>(
        future: _statusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }

          final status =
              snapshot.data ??
              const BudgetStatus(
                budget: 0,
                spent: 0,
                remaining: 0,
                percentUsed: 0,
                isWarning: false,
                isExceeded: false,
              );

          final progressColor = status.isExceeded
              ? AppColors.expense
              : status.isWarning
              ? AppColors.warning
              : AppColors.income;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: accent.withValues(alpha: 0.12),
                      child: Icon(
                        AppConstants.iconData(category?.icon ?? 'category'),
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category?.name ?? 'Sin categoría',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuButton<_BudgetAction>(
                      tooltip: 'Opciones',
                      onSelected: (action) {
                        switch (action) {
                          case _BudgetAction.edit:
                            widget.onEdit();
                          case _BudgetAction.delete:
                            widget.onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _BudgetAction.edit,
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Editar'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _BudgetAction.delete,
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('Eliminar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _BudgetStat(
                      label: 'Presupuesto',
                      value: fmt.MoneyUtils.format(status.budget),
                    ),
                    _BudgetStat(
                      label: 'Gastado',
                      value: fmt.MoneyUtils.format(status.spent),
                    ),
                    _BudgetStat(
                      label: 'Restante',
                      value: fmt.MoneyUtils.format(status.remaining),
                      color: status.remaining < 0
                          ? AppColors.expense
                          : AppColors.income,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: status.percentUsed.clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      color: progressColor,
                      backgroundColor: progressColor.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${(status.percentUsed * 100).toStringAsFixed(0)}% utilizado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (status.isExceeded) _ExceededBadge(),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _accentColor(Category? category) {
    if (category?.color != null) {
      return AppConstants.parseColor(category!.color!);
    }
    return Theme.of(context).colorScheme.primary;
  }
}

class _ExceededBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: AppColors.expense,
          ),
          const SizedBox(width: 4),
          Text(
            'Excedido',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.expense,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _BudgetStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BudgetAction { edit, delete }

class _BudgetFormDialog extends StatefulWidget {
  final Budget? existing;
  final DateTime month;

  const _BudgetFormDialog({this.existing, required this.month});

  @override
  State<_BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends State<_BudgetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  Category? _category;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing == null
          ? ''
          : fmt.MoneyUtils.fromCents(existing.amount).toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) return;

    final raw = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (raw == null || raw <= 0) return;

    final existing = widget.existing;
    Navigator.of(context).pop(
      Budget(
        id: existing?.id,
        categoryId: _category!.id!,
        amount: fmt.MoneyUtils.toCents(raw),
        startDate: existing?.startDate ?? widget.month,
        endDate: existing?.endDate,
        isActive: existing?.isActive ?? true,
        createdAt: existing?.createdAt,
        updatedAt: existing?.updatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final categories = app.category.expenseCategories;
    _category ??= _initialCategory(categories);

    return AlertDialog(
      title: Text(_isEditing ? 'Editar presupuesto' : 'Nuevo presupuesto'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: DropdownMenu<Category>(
                  initialSelection: _category,
                  requestFocusOnTap: true,
                  label: const Text('Categoría'),
                  leadingIcon: const Icon(Icons.category),
                  onSelected: (c) => setState(() => _category = c),
                  dropdownMenuEntries: [
                    for (final c in categories)
                      DropdownMenuEntry(
                        value: c,
                        label: c.name,
                        leadingIcon: Icon(
                          AppConstants.iconData(c.icon ?? 'category'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                autofocus: widget.existing == null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto mensual',
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  Category? _initialCategory(List<Category> categories) {
    final existing = widget.existing;
    if (existing != null) {
      for (final c in categories) {
        if (c.id == existing.categoryId) return c;
      }
    }
    if (categories.isEmpty) return null;
    return categories.first;
  }
}
