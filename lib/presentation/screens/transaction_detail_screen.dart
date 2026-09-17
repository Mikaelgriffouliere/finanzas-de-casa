import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/subcategory.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_type.dart';
import '../../utils/formatters.dart' as fmt;
import '../common/amount_display.dart';
import '../common/confirm_dialog.dart';
import '../providers/app_provider.dart';
import 'transaction_form_screen.dart';
import '../../core/theme/app_colors.dart';
import '../common/glass_card.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  static const String routeName = '/transactions/edit';

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  Transaction? _transaction;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
  }

  Future<void> _edit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(existing: _transaction),
      ),
    );
    if (result == true || result != null) {
      await _reload();
    }
  }

  Future<void> _reload() async {
    final provider = context.read<AppProvider>().transaction;
    final t = _transaction;
    if (t?.id == null) return;
    final found = provider.transactions.where((x) => x.id == t!.id).toList();
    if (found.isNotEmpty) {
      setState(() => _transaction = found.first);
    }
  }

  Future<void> _delete() async {
    final t = _transaction;
    if (t?.id == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar movimiento',
      message: '¿Seguro que deseas eliminar este movimiento?',
    );
    if (!confirmed || !mounted) return;
    await context.read<AppProvider>().transaction.delete(t!.id!);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = _transaction!;
    final app = context.watch<AppProvider>();

    final category = app.category.byId(t.categoryId);
    final subcategory = _subcategoryById(
      app.category.subcategories,
      t.subcategoryId,
    );
    final person = _personById(app.person.persons, t.personId);
    final account = _accountById(app.account.accounts, t.accountId);
    final transferAccount = _accountById(
      app.account.accounts,
      t.transferAccountId,
    );

    final signedCents = t.type == TransactionType.expense
        ? -t.amount
        : t.amount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del movimiento'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(transaction: t, signedCents: signedCents),
          const SizedBox(height: 16),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(label: 'Tipo', value: t.type.label),
                  _DetailRow(
                    label: 'Fecha',
                    value: fmt.DateUtils.shortDateTime(t.date),
                  ),
                  if (category != null)
                    _DetailRow(label: 'Categoría', value: category.name),
                  if (subcategory != null)
                    _DetailRow(label: 'Subcategoría', value: subcategory.name),
                  if (person != null)
                    _DetailRow(label: 'Persona', value: person.name),
                  if (account != null && t.type != TransactionType.transfer)
                    _DetailRow(label: 'Cuenta', value: account.name),
                  if (t.type == TransactionType.transfer) ...[
                    if (account != null)
                      _DetailRow(label: 'Cuenta origen', value: account.name),
                    if (transferAccount != null)
                      _DetailRow(
                        label: 'Cuenta destino',
                        value: transferAccount.name,
                      ),
                  ],
                  if (t.description.isNotEmpty)
                    _DetailRow(label: 'Descripción', value: t.description),
                  if (t.notes.isNotEmpty)
                    _DetailRow(label: 'Notas', value: t.notes),
                  _DetailRow(
                    label: 'Recurrente',
                    value: t.isRecurring ? 'Sí' : 'No',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Subcategory? _subcategoryById(List<Subcategory> subcategories, int? id) {
    if (id == null) return null;
    for (final s in subcategories) {
      if (s.id == id) return s;
    }
    return null;
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
}

class _Header extends StatelessWidget {
  final Transaction transaction;
  final int signedCents;

  const _Header({required this.transaction, required this.signedCents});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: _color(context).withValues(alpha: 0.15),
              child: Icon(_icon, size: 36, color: _color(context)),
            ),
            const SizedBox(height: 12),
            Text(transaction.type.label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            AmountDisplay(
              cents: signedCents,
              showSign: true,
              style: theme.textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
