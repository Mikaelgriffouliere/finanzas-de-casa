import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/subcategory.dart';
import '../common/confirm_dialog.dart';
import '../common/empty_state.dart';
import '../providers/app_provider.dart';
import '../common/glass_card.dart';

const _categoryIcons = [
  Icons.home,
  Icons.restaurant,
  Icons.directions_bus,
  Icons.school,
  Icons.medical_services,
  Icons.celebration,
  Icons.movie,
  Icons.pets,
  Icons.checkroom,
  Icons.receipt_long,
  Icons.account_balance,
  Icons.payments,
  Icons.category,
  Icons.work,
  Icons.schedule,
  Icons.card_giftcard,
  Icons.verified,
  Icons.storefront,
  Icons.percent,
  Icons.trending_up,
  Icons.shopping_cart,
  Icons.water_drop,
  Icons.bolt,
  Icons.phone_iphone,
  Icons.credit_card,
  Icons.fitness_center,
  Icons.local_taxi,
  Icons.flight,
  Icons.hotel,
  Icons.content_cut,
];

IconData iconFor(String? code) {
  if (code != null && code.isNotEmpty) {
    final codepoint = int.tryParse(code);
    if (codepoint != null) {
      return IconData(codepoint, fontFamily: 'MaterialIcons');
    }
  }
  return AppConstants.iconData(code ?? '');
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _isIncome = false;

  List<Category> get _categories => _isIncome
      ? context.watch<AppProvider>().category.incomeCategories
      : context.watch<AppProvider>().category.expenseCategories;

  Future<void> _addCategory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CategoryFormSheet(isIncome: _isIncome),
    );
  }

  Future<void> _editCategory(Category category) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _CategoryFormSheet(category: category, isIncome: _isIncome),
    );
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar categoría',
      message:
          '¿Eliminar "${category.name}"? Los movimientos asociados se conservarán.',
    );
    if (!confirmed || !mounted) return;
    await context.read<AppProvider>().category.delete(category.id!);
  }

  Future<void> _openSubcategories(Category category) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SubcategoriesSheet(category: category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            tooltip: 'Agregar categoría',
            icon: const Icon(Icons.add),
            onPressed: _addCategory,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Gastos'),
                  icon: Icon(Icons.trending_down),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Ingresos'),
                  icon: Icon(Icons.trending_up),
                ),
              ],
              selected: {_isIncome},
              onSelectionChanged: (selection) {
                setState(() => _isIncome = selection.first);
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: categories.isEmpty
                ? EmptyState(
                    icon: Icons.category,
                    title: _isIncome
                        ? 'Sin categorías de ingreso'
                        : 'Sin categorías de gasto',
                    subtitle: 'Agrega una categoría',
                    action: FilledButton.icon(
                      onPressed: _addCategory,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return GlassCard(
                        padding: EdgeInsets.zero,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: category.color != null
                                ? AppConstants.parseColor(
                                    category.color!,
                                  ).withValues(alpha: 0.2)
                                : Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                            child: Icon(
                              iconFor(category.icon),
                              color: category.color != null
                                  ? AppConstants.parseColor(category.color!)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: category.isDefault
                              ? const Text('Por defecto')
                              : null,
                          trailing: IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteCategory(category),
                          ),
                          onTap: () => _openSubcategories(category),
                          onLongPress: () => _editCategory(category),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SubcategoriesSheet extends StatefulWidget {
  final Category category;

  const _SubcategoriesSheet({required this.category});

  @override
  State<_SubcategoriesSheet> createState() => _SubcategoriesSheetState();
}

class _SubcategoriesSheetState extends State<_SubcategoriesSheet> {
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
      widget.category.id!,
    );
    if (mounted) setState(() => _subcategories = result);
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final provider = context.read<AppProvider>().category;
    await provider.addSubcategory(
      Subcategory(
        categoryId: widget.category.id!,
        name: name,
        isDefault: false,
      ),
    );
    _nameController.clear();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Subcategoría "$name" agregada'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _delete(Subcategory subcategory) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar subcategoría',
      message: '¿Eliminar "${subcategory.name}"?',
    );
    if (!confirmed || !mounted) return;
    await context.read<AppProvider>().category.deleteSubcategory(
      subcategory.id!,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(iconFor(widget.category.icon)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.category.name,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              'Subcategorías',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _subcategories.isEmpty
                  ? const Center(child: Text('Sin subcategorías'))
                  : ListView(
                      children: [
                        for (final subcategory in _subcategories)
                          ListTile(
                            leading: const Icon(Icons.label_outline),
                            title: Text(subcategory.name),
                            trailing: IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(subcategory),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nueva subcategoría',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final Category? category;
  final bool isIncome;

  const _CategoryFormSheet({this.category, required this.isIncome});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late IconData _icon;
  String? _color;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _icon = category != null ? iconFor(category.icon) : _categoryIcons.first;
    _color = category?.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final category = Category(
      id: widget.category?.id,
      name: _nameController.text.trim(),
      icon: _icon.codePoint.toString(),
      color: _color,
      isDefault: widget.category?.isDefault ?? false,
      createdAt: widget.category?.createdAt,
      updatedAt: widget.category?.updatedAt,
    );

    final provider = context.read<AppProvider>().category;
    if (_isEditing) {
      await provider.update(category, isIncome: widget.isIncome);
    } else {
      await provider.add(category, isIncome: widget.isIncome);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                _isEditing ? 'Editar categoría' : 'Nueva categoría',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: Icon(Icons.category),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Ícono', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final icon in _categoryIcons)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _icon = icon),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _icon.codePoint == icon.codePoint
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _icon.codePoint == icon.codePoint
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: _icon.codePoint == icon.codePoint
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Color (opcional)', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _color = null),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: _color == null
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.clear,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final hex in AppConstants.personColors)
                    GestureDetector(
                      onTap: () => setState(() => _color = hex),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppConstants.parseColor(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == hex
                                ? theme.colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: _color == hex
                            ? const Icon(
                                Icons.check,
                                size: 20,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
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
