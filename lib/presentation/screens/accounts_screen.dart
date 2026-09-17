import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/account_repository_impl.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/account_type.dart';
import '../../utils/formatters.dart';
import '../common/amount_display.dart';
import '../common/confirm_dialog.dart';
import '../common/empty_state.dart';
import '../providers/app_provider.dart';
import '../../core/theme/app_colors.dart';
import '../common/glass_card.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _repository = AccountRepositoryImpl();

  Future<void> _addAccount() async {
    await _showAccountForm();
  }

  Future<void> _editAccount(Account account) async {
    await _showAccountForm(account: account);
  }

  Future<void> _showAccountForm({Account? account}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AccountFormSheet(account: account),
    );
  }

  Future<void> _deleteAccount(Account account) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar cuenta',
      message:
          '¿Eliminar "${account.name}"? Los movimientos asociados se conservarán sin cuenta.',
    );
    if (!confirmed || !mounted) return;
    await context.read<AppProvider>().account.delete(account.id!);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AppProvider>().account.accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas'),
        actions: [
          IconButton(
            tooltip: 'Agregar cuenta',
            icon: const Icon(Icons.add),
            onPressed: _addAccount,
          ),
        ],
      ),
      body: accounts.isEmpty
          ? EmptyState(
              icon: Icons.account_balance_wallet,
              title: 'Sin cuentas',
              subtitle: 'Agrega tus cuentas y medios de pago',
              action: FilledButton.icon(
                onPressed: _addAccount,
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  return _AccountCard(
                    account: account,
                    balanceFuture: _repository.getAccountBalance(account.id!),
                    onTap: () => _editAccount(account),
                    onDelete: () => _deleteAccount(account),
                  );
                },
              ),
            ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  final Future<int> balanceFuture;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.account,
    required this.balanceFuture,
    required this.onTap,
    required this.onDelete,
  });

  IconData get _icon {
    switch (account.type) {
      case AccountType.cash:
        return Icons.currency_exchange;
      case AccountType.bankAccount:
        return Icons.account_balance;
      case AccountType.wallet:
        return Icons.wallet;
      case AccountType.card:
        return Icons.credit_card;
      case AccountType.savings:
        return Icons.savings;
      case AccountType.investment:
        return Icons.trending_up;
    }
  }

  Color _iconColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!account.isActive) return scheme.outline;
    switch (account.type) {
      case AccountType.cash:
        return AppColors.warning;
      case AccountType.bankAccount:
        return AppColors.transfer;
      case AccountType.wallet:
        return AppColors.primary;
      case AccountType.card:
        return AppColors.secondary;
      case AccountType.savings:
        return AppColors.income;
      case AccountType.investment:
        return AppColors.slate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        onLongPress: onDelete,
        leading: CircleAvatar(
          backgroundColor: _iconColor(context).withValues(alpha: 0.15),
          child: Icon(_icon, color: _iconColor(context)),
        ),
        title: Text(
          account.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: account.isActive ? null : const TextStyle(color: Colors.grey),
        ),
        subtitle: Text(account.type.label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!account.isActive)
              Chip(
                label: const Text('Inactiva'),
                visualDensity: VisualDensity.compact,
                labelStyle: theme.textTheme.labelSmall,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: FutureBuilder<int>(
                future: balanceFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  final balance = snapshot.data ?? 0;
                  return AmountDisplay(
                    cents: balance,
                    showSign: true,
                    style: theme.textTheme.titleMedium,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountFormSheet extends StatefulWidget {
  final Account? account;

  const _AccountFormSheet({this.account});

  @override
  State<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<_AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late AccountType _type;
  late bool _isActive;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _balanceController = TextEditingController(
      text: account != null ? _amountFromCents(account.initialBalance) : '',
    );
    _type = account?.type ?? AccountType.cash;
    _isActive = account?.isActive ?? true;
  }

  String _amountFromCents(int cents) {
    final value = MoneyUtils.fromCents(cents);
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final rawBalance = double.tryParse(
      _balanceController.text.trim().replaceAll(',', '.'),
    );

    final account = Account(
      id: widget.account?.id,
      name: _nameController.text.trim(),
      type: _type,
      isActive: _isActive,
      initialBalance: rawBalance == null
          ? (widget.account?.initialBalance ?? 0)
          : MoneyUtils.toCents(rawBalance),
      createdAt: widget.account?.createdAt,
      updatedAt: widget.account?.updatedAt,
    );

    final provider = context.read<AppProvider>().account;
    if (_isEditing) {
      await provider.update(account);
    } else {
      await provider.add(account);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Editar cuenta' : 'Nueva cuenta',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: Icon(Icons.sell),
                ),
                items: [
                  for (final type in AccountType.values)
                    DropdownMenuItem<AccountType>(
                      value: type,
                      child: Text(type.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Saldo inicial',
                  prefixText: r'$ ',
                  prefixIcon: Icon(Icons.payments),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final parsed = double.tryParse(value.replaceAll(',', '.'));
                  if (parsed == null) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activa'),
                subtitle: const Text('Se puede usar en los movimientos'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(_isEditing ? 'Guardar cambios' : 'Agregar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
