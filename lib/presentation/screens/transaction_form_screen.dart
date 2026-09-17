import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/utils/haptic_helper.dart';
import '../../domain/entities/subcategory.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_type.dart';
import '../../utils/formatters.dart';
import '../providers/app_provider.dart';
import '../common/glass_card.dart';

class TransactionFormScreen extends StatefulWidget {
  final TransactionType? initialType;
  final Transaction? existing;

  const TransactionFormScreen({super.key, this.initialType, this.existing});

  static const String newRoute = '/transactions/new';
  static const String editRoute = '/transactions/edit';

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TransactionType _type;
  final _amountController = TextEditingController();
  DateTime _date = DateTime.now();
  int? _categoryId;
  int? _subcategoryId;
  int? _personId;
  int? _accountId;
  int? _transferAccountId;
  bool _isRecurring = false;
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  List<Subcategory> _subcategories = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _type =
        widget.existing?.type ?? widget.initialType ?? TransactionType.expense;

    final existing = widget.existing;
    if (existing != null) {
      _amountController.text = _amountFromCents(existing.amount);
      _date = existing.date;
      _categoryId = existing.categoryId;
      _subcategoryId = existing.subcategoryId;
      _personId = existing.personId;
      _accountId = existing.accountId;
      _transferAccountId = existing.transferAccountId;
      _isRecurring = existing.isRecurring;
      _descriptionController.text = existing.description;
      _notesController.text = existing.notes;
      if (existing.categoryId != null) {
        _loadSubcategories(existing.categoryId!);
      }
    } else {
      _defaultToLastUsed();
    }
  }

  String _amountFromCents(int cents) {
    final value = MoneyUtils.fromCents(cents);
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
  }

  void _defaultToLastUsed() {
    final app = context.read<AppProvider>();
    final lastIncome = app.transaction.transactions
        .where((t) => t.type == TransactionType.income)
        .toList();
    final lastExpense = app.transaction.transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    if (_type == TransactionType.income && lastIncome.isNotEmpty) {
      final last = lastIncome.first;
      _categoryId =
          last.categoryId ??
          (app.category.incomeCategories.isNotEmpty
              ? app.category.incomeCategories.first.id
              : null);
      _accountId = last.accountId ?? _defaultAccountId(app);
      _personId = last.personId ?? _defaultPersonId(app);
    } else {
      final last = lastExpense.isNotEmpty ? lastExpense.first : null;
      _categoryId =
          last?.categoryId ??
          (app.category.expenseCategories.isNotEmpty
              ? app.category.expenseCategories.first.id
              : null);
      _accountId = last?.accountId ?? _defaultAccountId(app);
      _personId = last?.personId ?? _defaultPersonId(app);
    }

    if (_categoryId != null && _isEditing == false) {
      _loadSubcategories(_categoryId!);
    }
  }

  int? _defaultAccountId(AppProvider app) {
    if (app.account.accounts.isEmpty) return null;
    if (app.account.accounts.any((a) => a.id == _accountId)) return _accountId;
    return app.account.accounts.first.id;
  }

  int? _defaultPersonId(AppProvider app) {
    if (app.person.persons.isEmpty) return null;
    if (app.person.persons.any((p) => p.id == _personId)) return _personId;
    return app.person.persons.first.id;
  }

  Future<void> _loadSubcategories(int categoryId) async {
    final categoryProvider = context.read<AppProvider>().category;
    final result = await categoryProvider.loadByCategory(categoryId);
    if (mounted) {
      setState(() => _subcategories = result);
    }
  }

  void _setType(TransactionType type) {
    if (_isEditing) return;
    setState(() {
      _type = type;
      _subcategories = [];
      _subcategoryId = null;
    });
    _defaultToLastUsed();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final rawAmount = double.tryParse(
      _amountController.text.replaceAll(',', '.'),
    );
    if (rawAmount == null || rawAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido mayor a 0')),
      );
      return;
    }

    final amount = MoneyUtils.toCents(rawAmount);

    if (_type == TransactionType.transfer) {
      if (_accountId == null || _transferAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona cuenta origen y destino')),
        );
        return;
      }
      if (_accountId == _transferAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Las cuentas origen y destino deben ser distintas'),
          ),
        );
        return;
      }
    } else {
      if (_accountId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Selecciona una cuenta')));
        return;
      }
    }

    final transaction = Transaction(
      id: widget.existing?.id,
      type: _type,
      amount: amount,
      date: _date,
      categoryId: _type == TransactionType.transfer ? null : _categoryId,
      subcategoryId: _type == TransactionType.transfer ? null : _subcategoryId,
      personId: _type == TransactionType.transfer ? null : _personId,
      accountId: _accountId,
      transferAccountId: _type == TransactionType.transfer
          ? _transferAccountId
          : null,
      description: _descriptionController.text.trim(),
      notes: _notesController.text.trim(),
      isRecurring: _isRecurring,
      createdAt: widget.existing?.createdAt,
      updatedAt: widget.existing?.updatedAt,
    );

    _submit(transaction);
  }

  Future<void> _submit(Transaction transaction) async {
    final provider = context.read<AppProvider>().transaction;

    if (_isEditing) {
      await provider.update(transaction);
      if (mounted) {
        HapticHelper.medium();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Movimiento actualizado')));
        Navigator.of(context).pop(true);
      }
      return;
    }

    switch (_type) {
      case TransactionType.income:
        await provider.addIncome(transaction);
      case TransactionType.expense:
        await provider.addExpense(transaction);
      case TransactionType.transfer:
        await provider.addTransfer(transaction);
    }

    if (mounted) {
      HapticHelper.medium();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Movimiento guardado')));
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);

    final isIncome = _type == TransactionType.income;
    final isExpense = _type == TransactionType.expense;
    final isTransfer = _type == TransactionType.transfer;

    final categories = isIncome
        ? app.category.incomeCategories
        : app.category.expenseCategories;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Editar movimiento'
              : 'Registrar ${_type.label.toLowerCase()}',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewPadding.bottom + 24,
          ),
          children: [
            if (!_isEditing)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<TransactionType>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Ingreso'),
                      icon: Icon(Icons.trending_up),
                    ),
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Gasto'),
                      icon: Icon(Icons.trending_down),
                    ),
                    ButtonSegment(
                      value: TransactionType.transfer,
                      label: Text('Transferencia'),
                      icon: Icon(Icons.swap_horiz),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (sel) => _setType(sel.first),
                ),
              ),
            const SizedBox(height: 20),
            _FormSection(
              title: 'Monto',
              icon: Icons.payments,
              highlighted: true,
              child: TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto',
                  prefixText: r'$ ',
                  prefixStyle: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 26,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa un monto';
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Monto inválido';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            _FormSection(
              title: 'Fecha',
              icon: Icons.calendar_today,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                leading: Icon(
                  Icons.calendar_today,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  DateFormat('dd/MM/yyyy').format(_date),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text('Tocá para cambiar'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
            ),
            if (isTransfer) ...[
              const SizedBox(height: 14),
              _FormSection(
                title: 'Cuentas',
                icon: Icons.swap_horiz,
                child: Column(
                  children: [
                    DropdownButtonFormField<int?>(
                      initialValue: _accountId,
                      decoration: const InputDecoration(
                        labelText: 'Cuenta origen',
                        prefixIcon: Icon(Icons.call_made),
                      ),
                      items: [
                        for (final a in app.account.accounts.where(
                          (a) => a.id != _transferAccountId,
                        ))
                          DropdownMenuItem<int?>(
                            value: a.id,
                            child: Text(a.name),
                          ),
                      ],
                      onChanged: (v) => setState(() => _accountId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: _transferAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Cuenta destino',
                        prefixIcon: Icon(Icons.call_received),
                      ),
                      items: [
                        for (final a in app.account.accounts.where(
                          (a) => a.id != _accountId,
                        ))
                          DropdownMenuItem<int?>(
                            value: a.id,
                            child: Text(a.name),
                          ),
                      ],
                      onChanged: (v) => setState(() => _transferAccountId = v),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              _FormSection(
                title: 'Clasificación',
                icon: Icons.category,
                child: Column(
                  children: [
                    DropdownButtonFormField<int?>(
                      initialValue: _categoryId,
                      decoration: InputDecoration(
                        labelText: isIncome ? 'Tipo de ingreso' : 'Categoría',
                        prefixIcon: const Icon(Icons.category),
                      ),
                      items: [
                        for (final c in categories)
                          DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _categoryId = v;
                          _subcategoryId = null;
                          _subcategories = [];
                        });
                        if (v != null) _loadSubcategories(v);
                      },
                    ),
                    if (isExpense) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _categoryId == null ? null : _pickSubcategory,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Subcategoría (opcional)',
                            prefixIcon: Icon(Icons.label_outline),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(
                            _subcategoryId == null
                                ? 'Sin subcategoría'
                                : _subcategoryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: _subcategoryId == null
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FormSection(
                title: isIncome ? 'Cuenta destino' : 'Origen',
                icon: Icons.account_balance_wallet,
                child: Column(
                  children: [
                    DropdownButtonFormField<int?>(
                      initialValue: _accountId,
                      decoration: InputDecoration(
                        labelText: isIncome
                            ? 'Cuenta destino'
                            : 'Medio de pago',
                        prefixIcon: const Icon(Icons.account_balance_wallet),
                      ),
                      items: [
                        for (final a in app.account.accounts)
                          DropdownMenuItem<int?>(
                            value: a.id,
                            child: Text(a.name),
                          ),
                      ],
                      onChanged: (v) => setState(() => _accountId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: _personId,
                      decoration: const InputDecoration(
                        labelText: 'Persona',
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sin asignar'),
                        ),
                        for (final p in app.person.persons)
                          DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(p.name),
                          ),
                      ],
                      onChanged: (v) => setState(() => _personId = v),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            _FormSection(
              title: 'Detalles (opcional)',
              icon: Icons.notes,
              child: Column(
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notas',
                      prefixIcon: Icon(Icons.sticky_note_2_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.repeat, color: theme.colorScheme.primary),
              title: const Text('Recurrente'),
              subtitle: const Text('Este movimiento se repite'),
              value: _isRecurring,
              onChanged: (_) => setState(() => _isRecurring = !_isRecurring),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_isEditing ? 'Guardar cambios' : 'Guardar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _subcategoryLabel {
    if (_subcategoryId == null) return 'Sin subcategoría';
    for (final s in _subcategories) {
      if (s.id == _subcategoryId) return s.name;
    }
    return 'Sin subcategoría';
  }

  Future<void> _pickSubcategory() async {
    final categoryId = _categoryId;
    if (categoryId == null) return;
    final pick = await showModalBottomSheet<_SubcategoryPick>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SubcategoryPickerSheet(
        categoryId: categoryId,
        selectedId: _subcategoryId,
      ),
    );
    if (pick == null || !mounted) return;
    setState(() => _subcategoryId = pick.id);
    _loadSubcategories(categoryId);
  }
}

class _SubcategoryPick {
  final int? id;
  final String name;

  const _SubcategoryPick(this.id, this.name);
}

class _SubcategoryPickerSheet extends StatefulWidget {
  final int categoryId;
  final int? selectedId;

  const _SubcategoryPickerSheet({required this.categoryId, this.selectedId});

  @override
  State<_SubcategoryPickerSheet> createState() =>
      _SubcategoryPickerSheetState();
}

class _SubcategoryPickerSheetState extends State<_SubcategoryPickerSheet> {
  final _nameController = TextEditingController();
  List<Subcategory> _subcategories = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await context.read<AppProvider>().category.loadByCategory(
      widget.categoryId,
    );
    if (mounted) setState(() => _subcategories = result);
  }

  void _pick(int? id, String name) {
    HapticHelper.selection();
    Navigator.of(context).pop(_SubcategoryPick(id, name));
  }

  Future<void> _addAndPick() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final provider = context.read<AppProvider>().category;
    await provider.addSubcategory(
      Subcategory(categoryId: widget.categoryId, name: name, isDefault: false),
    );
    final refreshed = await provider.loadByCategory(widget.categoryId);
    if (!mounted) return;
    final created = refreshed.firstWhere(
      (s) => s.name == name,
      orElse: () => refreshed.first,
    );
    _pick(created.id, created.name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selectedId;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Subcategoría', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.block),
            title: const Text('Sin subcategoría'),
            trailing: selected == null
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => _pick(null, 'Sin subcategoría'),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: _subcategories.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Sin subcategorías')),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final s in _subcategories)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.label_outline),
                          title: Text(s.name),
                          trailing: s.id == selected
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () => _pick(s.id, s.name),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Text(
            'Si no existe, creala',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Nueva subcategoría',
                    prefixIcon: const Icon(Icons.add),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onSubmitted: (_) => _addAndPick(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addAndPick,
                child: const Text('Agregar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool highlighted;

  const _FormSection({
    required this.title,
    required this.icon,
    required this.child,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 17, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        highlighted
            ? Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(padding: const EdgeInsets.all(16), child: child),
              )
            : GlassCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(16),
                child: child,
              ),
      ],
    );
  }
}
