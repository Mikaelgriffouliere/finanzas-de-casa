import 'package:flutter/material.dart' hide DateUtils;
import 'package:provider/provider.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/savings_goal.dart';
import '../../domain/entities/savings_goal_status.dart';
import '../../domain/entities/savings_movement.dart';
import '../../utils/formatters.dart';
import '../common/amount_display.dart';
import '../common/confirm_dialog.dart';
import '../common/empty_state.dart';
import '../providers/app_provider.dart';
import '../../core/theme/app_colors.dart';
import '../common/glass_card.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  Future<void> _openGoalForm({SavingsGoal? existing}) async {
    final result = await showDialog<SavingsGoal>(
      context: context,
      builder: (_) => _GoalFormDialog(existing: existing),
    );
    if (result == null || !mounted) return;

    final savings = context.read<AppProvider>().savings;
    if (existing == null) {
      await savings.add(result);
    } else {
      await savings.update(result);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Meta creada' : 'Meta actualizada'),
        ),
      );
    }
  }

  Future<void> _deposit(SavingsGoal goal) async {
    final result = await showDialog<_DepositResult>(
      context: context,
      builder: (_) => const _DepositDialog(),
    );
    if (result == null || goal.id == null || !mounted) return;

    await context.read<AppProvider>().savings.deposit(
      goal.id!,
      result.cents,
      accountId: result.accountId,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Depósito registrado')));
    }
  }

  Future<void> _withdraw(SavingsGoal goal) async {
    if (goal.id == null) return;
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _WithdrawDialog(currentAmount: goal.currentAmount),
    );
    if (result == null || !mounted) return;

    await context.read<AppProvider>().savings.withdraw(goal.id!, result);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Retiro registrado')));
    }
  }

  void _openDetail(SavingsGoal goal) {
    if (goal.id == null) return;
    Navigator.of(
      context,
    ).pushNamed(SavingsGoalDetailScreen.routeName, arguments: {'id': goal.id});
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final goals = app.savings.goals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ahorros'),
        actions: [
          if (goals.isNotEmpty)
            IconButton(
              tooltip: 'Nueva meta',
              icon: const Icon(Icons.add),
              onPressed: () => _openGoalForm(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openGoalForm(),
        tooltip: 'Nueva meta',
        child: const Icon(Icons.add),
      ),
      body: goals.isEmpty
          ? EmptyState(
              icon: Icons.savings_outlined,
              title: 'Sin metas de ahorro',
              subtitle:
                  'Crea una meta para empezar a ahorrar, por ejemplo unas vacaciones o un electrodoméstico.',
              action: FilledButton.icon(
                onPressed: () => _openGoalForm(),
                icon: const Icon(Icons.add),
                label: const Text('Nueva meta'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final goal in goals)
                  _GoalCard(
                    goal: goal,
                    onTap: () => _openDetail(goal),
                    onDeposit: () => _deposit(goal),
                    onWithdraw: () => _withdraw(goal),
                  ),
              ],
            ),
    );
  }
}

class SavingsGoalDetailScreen extends StatefulWidget {
  final int goalId;

  const SavingsGoalDetailScreen({super.key, required this.goalId});

  static const String routeName = '/savings/goal';

  @override
  State<SavingsGoalDetailScreen> createState() =>
      _SavingsGoalDetailScreenState();
}

class _SavingsGoalDetailScreenState extends State<SavingsGoalDetailScreen> {
  late Future<List<SavingsMovement>> _movementsFuture;

  @override
  void initState() {
    super.initState();
    _movementsFuture = context.read<AppProvider>().savings.getMovements(
      widget.goalId,
    );
  }

  void _reloadMovements() {
    setState(() {
      _movementsFuture = context.read<AppProvider>().savings.getMovements(
        widget.goalId,
      );
    });
  }

  SavingsGoal? _goal(AppProvider app) {
    for (final g in app.savings.goals) {
      if (g.id == widget.goalId) return g;
    }
    return null;
  }

  Future<void> _edit(SavingsGoal goal) async {
    final result = await showDialog<SavingsGoal>(
      context: context,
      builder: (_) => _GoalFormDialog(existing: goal),
    );
    if (result == null || goal.id == null || !mounted) return;
    await context.read<AppProvider>().savings.update(result);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meta actualizada')));
    }
  }

  Future<void> _delete(SavingsGoal goal) async {
    if (goal.id == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar meta',
      message: '¿Seguro que deseas eliminar esta meta y sus movimientos?',
    );
    if (!confirmed || !mounted) return;
    await context.read<AppProvider>().savings.delete(goal.id!);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _deposit(SavingsGoal goal) async {
    final result = await showDialog<_DepositResult>(
      context: context,
      builder: (_) => const _DepositDialog(),
    );
    if (result == null || goal.id == null || !mounted) return;

    await context.read<AppProvider>().savings.deposit(
      goal.id!,
      result.cents,
      accountId: result.accountId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Depósito registrado')));
    _reloadMovements();
  }

  Future<void> _withdraw(SavingsGoal goal) async {
    if (goal.id == null) return;
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _WithdrawDialog(currentAmount: goal.currentAmount),
    );
    if (result == null || !mounted) return;

    await context.read<AppProvider>().savings.withdraw(goal.id!, result);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Retiro registrado')));
    _reloadMovements();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final goal = _goal(app);
    final accounts = app.account.accounts;

    if (goal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meta de ahorro')),
        body: const Center(child: Text('Meta no encontrada')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(goal),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(goal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GoalHeader(goal: goal),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _withdraw(goal),
                  icon: const Icon(Icons.remove),
                  label: const Text('Retirar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _deposit(goal),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Movimientos',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<SavingsMovement>>(
            future: _movementsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final movements = snapshot.data ?? [];
              if (movements.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    icon: Icons.swap_horiz,
                    title: 'Sin movimientos todavía',
                    subtitle:
                        'Agrega o retira dinero para registrar movimientos.',
                  ),
                );
              }

              final ordered = movements.toList()
                ..sort((a, b) => b.date.compareTo(a.date));
              return Column(
                children: [
                  for (final movement in ordered)
                    _MovementTile(
                      movement: movement,
                      account: _findAccount(accounts, movement.accountId),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

Account? _findAccount(List<Account> accounts, int? id) {
  if (id == null) return null;
  for (final a in accounts) {
    if (a.id == id) return a;
  }
  return null;
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final VoidCallback onTap;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;

  const _GoalCard({
    required this.goal,
    required this.onTap,
    required this.onDeposit,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (goal.progress * 100).round();

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (goal.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            goal.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: goal.status),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: goal.progress),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$percent% · ${MoneyUtils.format(goal.currentAmount)} de ${MoneyUtils.format(goal.targetAmount)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (goal.targetDate != null || goal.priority != 2) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (goal.targetDate != null)
                      _Pill(
                        icon: Icons.event,
                        label:
                            'Fecha: ${DateUtils.shortDate(goal.targetDate!)}',
                      ),
                    _Pill(
                      icon: _priorityIcon,
                      label: _priorityLabel,
                      color: _priorityColor,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onWithdraw,
                    icon: const Icon(Icons.remove),
                    label: const Text('Retirar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onDeposit,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _priorityIcon {
    switch (goal.priority) {
      case 1:
        return Icons.flag;
      case 2:
        return Icons.flag_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  String get _priorityLabel {
    switch (goal.priority) {
      case 1:
        return 'Prioridad alta';
      case 2:
        return 'Prioridad media';
      default:
        return 'Prioridad baja';
    }
  }

  Color get _priorityColor {
    switch (goal.priority) {
      case 1:
        return AppColors.expense;
      case 2:
        return AppColors.warning;
      default:
        return AppColors.slate;
    }
  }
}

class _GoalHeader extends StatelessWidget {
  final SavingsGoal goal;

  const _GoalHeader({required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (goal.progress * 100).round();

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusChip(status: goal.status),
              ],
            ),
            if (goal.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                goal.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: goal.progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$percent% · ${MoneyUtils.format(goal.currentAmount)} de ${MoneyUtils.format(goal.targetAmount)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (goal.targetDate != null || goal.priority != 2) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (goal.targetDate != null)
                    _Pill(
                      icon: Icons.event,
                      label: 'Fecha: ${DateUtils.shortDate(goal.targetDate!)}',
                    ),
                  _Pill(
                    icon: Icons.flag_outlined,
                    label: _priorityLabel,
                    color: _priorityColor,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _priorityLabel {
    switch (goal.priority) {
      case 1:
        return 'Prioridad alta';
      case 2:
        return 'Prioridad media';
      default:
        return 'Prioridad baja';
    }
  }

  Color get _priorityColor {
    switch (goal.priority) {
      case 1:
        return AppColors.expense;
      case 2:
        return AppColors.warning;
      default:
        return AppColors.slate;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final SavingsGoalStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case SavingsGoalStatus.active:
        color = AppColors.income;
      case SavingsGoalStatus.completed:
        color = AppColors.transfer;
      case SavingsGoalStatus.paused:
        color = AppColors.warning;
    }
    return _Pill(icon: Icons.circle, label: status.label, color: color);
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Pill({
    required this.icon,
    required this.label,
    this.color = AppColors.slate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == Icons.circle)
            Icon(icon, size: 10, color: color)
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final SavingsMovement movement;
  final Account? account;

  const _MovementTile({required this.movement, this.account});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDeposit = movement.isDeposit;
    final color = isDeposit ? AppColors.income : AppColors.expense;

    final parts = <String>[
      DateUtils.shortDateTime(movement.date),
      if (account != null) account!.name,
      if (movement.description.isNotEmpty) movement.description,
    ];

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(isDeposit ? Icons.add : Icons.remove, color: color),
        ),
        title: Text(isDeposit ? 'Depósito' : 'Retiro'),
        subtitle: Text(
          parts.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        trailing: AmountDisplay(
          cents: isDeposit ? movement.amount : -movement.amount,
          showSign: true,
        ),
      ),
    );
  }
}

class _GoalFormDialog extends StatefulWidget {
  final SavingsGoal? existing;

  const _GoalFormDialog({this.existing});

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late DateTime? _targetDate;
  late int _priority;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _amountController = TextEditingController(
      text: existing == null
          ? ''
          : MoneyUtils.fromCents(existing.targetAmount).toString(),
    );
    _targetDate = existing?.targetDate;
    _priority = existing?.priority ?? 2;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final raw = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (raw == null || raw <= 0) return;

    final existing = widget.existing;
    Navigator.of(context).pop(
      SavingsGoal(
        id: existing?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        targetAmount: MoneyUtils.toCents(raw),
        currentAmount: existing?.currentAmount ?? 0,
        targetDate: _targetDate,
        priority: _priority,
        status: existing?.status ?? SavingsGoalStatus.active,
        createdAt: existing?.createdAt,
        updatedAt: existing?.updatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar meta' : 'Nueva meta de ahorro'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: !_isEditing,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.savings_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa un nombre';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto objetivo',
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(
                        _targetDate == null
                            ? 'Fecha objetivo'
                            : DateUtils.shortDate(_targetDate!),
                      ),
                    ),
                  ),
                  if (_targetDate != null)
                    IconButton(
                      tooltip: 'Quitar fecha',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _targetDate = null),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Prioridad'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SegmentedButton<int>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: 1,
                          label: Text('Alta'),
                          icon: Icon(Icons.arrow_drop_up),
                        ),
                        ButtonSegment(value: 2, label: Text('Media')),
                        ButtonSegment(value: 3, label: Text('Baja')),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (selection) =>
                          setState(() => _priority = selection.first),
                    ),
                  ),
                ],
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
}

class _DepositResult {
  final int cents;
  final int? accountId;

  const _DepositResult(this.cents, this.accountId);
}

class _DepositDialog extends StatefulWidget {
  const _DepositDialog();

  @override
  State<_DepositDialog> createState() => _DepositDialogState();
}

class _DepositDialogState extends State<_DepositDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  int? _accountId;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final raw = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (raw == null || raw <= 0) return;
    Navigator.of(
      context,
    ).pop(_DepositResult(MoneyUtils.toCents(raw), _accountId));
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AppProvider>().account.accounts;

    return AlertDialog(
      title: const Text('Agregar dinero'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amountController,
                autofocus: true,
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
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Cuenta (opcional)',
                  prefixIcon: Icon(Icons.account_balance_wallet),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Confirmar')),
      ],
    );
  }
}

class _WithdrawDialog extends StatefulWidget {
  final int currentAmount;

  const _WithdrawDialog({required this.currentAmount});

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final raw = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (raw == null || raw <= 0) return;
    Navigator.of(context).pop(MoneyUtils.toCents(raw));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Retirar dinero'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _amountController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto',
            prefixText: r'$ ',
            prefixIcon: Icon(Icons.payments),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa un monto';
            final parsed = double.tryParse(v.replaceAll(',', '.'));
            if (parsed == null || parsed <= 0) return 'Monto inválido';
            if (MoneyUtils.toCents(parsed) > widget.currentAmount) {
              return 'No puede superar ${MoneyUtils.format(widget.currentAmount)}';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Confirmar')),
      ],
    );
  }
}
