import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../data/services/avatar_storage.dart';
import '../../domain/entities/person.dart';
import '../common/confirm_dialog.dart';
import '../common/empty_state.dart';
import '../common/person_avatar.dart';
import '../providers/app_provider.dart';
import '../common/glass_card.dart';

class PersonsScreen extends StatefulWidget {
  const PersonsScreen({super.key});

  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends State<PersonsScreen> {
  Future<void> _addPerson() async {
    await _showPersonForm();
  }

  Future<void> _editPerson(Person person) async {
    await _showPersonForm(person: person);
  }

  Future<void> _showPersonForm({Person? person}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PersonFormSheet(person: person),
    );
  }

  Future<void> _deletePerson(Person person) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar persona',
      message:
          '¿Eliminar a "${person.name}"? Los movimientos asociados a esta persona se conservarán sin asignar.',
    );
    if (!confirmed || !mounted) return;
    await context.read<AppProvider>().person.delete(person.id!);
  }

  Future<void> _toggleActive(Person person, bool value) async {
    await context.read<AppProvider>().person.update(
      person.copyWith(isActive: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final persons = context.watch<AppProvider>().person.persons;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personas del hogar'),
        actions: [
          IconButton(
            tooltip: 'Agregar persona',
            icon: const Icon(Icons.add),
            onPressed: _addPerson,
          ),
        ],
      ),
      body: persons.isEmpty
          ? EmptyState(
              icon: Icons.group,
              title: 'Sin personas',
              subtitle: 'Agrega a las personas del hogar',
              action: FilledButton.icon(
                onPressed: _addPerson,
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: persons.length,
              itemBuilder: (context, index) {
                final person = persons[index];
                return GlassCard(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    onTap: () => _editPerson(person),
                    leading: PersonAvatar(
                      name: person.name,
                      color: person.color,
                      avatar: person.avatar,
                      radius: 22,
                    ),
                    title: Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: person.isActive
                          ? null
                          : const TextStyle(
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                    ),
                    subtitle: person.description.isNotEmpty
                        ? Text(
                            person.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: Switch(
                      value: person.isActive,
                      onChanged: (value) => _toggleActive(person, value),
                    ),
                    onLongPress: () => _deletePerson(person),
                  ),
                );
              },
            ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  final String avatar;
  final String name;
  final String color;
  final bool pickingPhoto;
  final VoidCallback onPickPhoto;
  final ValueChanged<String> onSelectEmoji;
  final VoidCallback onClear;

  const _AvatarSection({
    required this.avatar,
    required this.name,
    required this.color,
    required this.pickingPhoto,
    required this.onPickPhoto,
    required this.onSelectEmoji,
    required this.onClear,
  });

  bool get _hasAvatar => avatar.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedEmoji = avatar.startsWith(AppConstants.avatarEmojiPrefix)
        ? avatar.substring(AppConstants.avatarEmojiPrefix.length)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PersonAvatar(name: name, color: color, avatar: avatar, radius: 30),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: pickingPhoto ? null : onPickPhoto,
                icon: pickingPhoto
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined),
                label: const Text('Elegir foto'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'O elegí un avatar:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final emoji in AppConstants.avatarEmojis)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onSelectEmoji(emoji),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedEmoji == emoji
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      width: 2,
                    ),
                    color: selectedEmoji == emoji
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
          ],
        ),
        if (_hasAvatar) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear),
            label: const Text('Quitar avatar'),
          ),
        ],
      ],
    );
  }
}

class _PersonFormSheet extends StatefulWidget {
  final Person? person;

  const _PersonFormSheet({this.person});

  @override
  State<_PersonFormSheet> createState() => _PersonFormSheetState();
}

class _PersonFormSheetState extends State<_PersonFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _color;
  late String _avatar;
  late bool _isActive;
  bool _pickingPhoto = false;

  bool get _isEditing => widget.person != null;

  @override
  void initState() {
    super.initState();
    final person = widget.person;
    _nameController = TextEditingController(text: person?.name ?? '');
    _descriptionController = TextEditingController(
      text: person?.description ?? '',
    );
    _color = person?.color ?? AppConstants.personColors.first;
    _avatar = person?.avatar ?? '';
    _isActive = person?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.path == null) return;
      final path = await AvatarStorage.saveImage(File(file.path!));
      if (!mounted) return;
      setState(() => _avatar = '${AppConstants.avatarPhotoPrefix}$path');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar la foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _delete() async {
    final person = widget.person;
    if (person == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar persona',
      message:
          '¿Eliminar a "${person.name}"? Los movimientos asociados se conservarán sin asignar.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;
    await context.read<AppProvider>().person.delete(person.id!);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final person = Person(
      id: widget.person?.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      color: _color,
      avatar: _avatar,
      isActive: _isActive,
      createdAt: widget.person?.createdAt,
      updatedAt: widget.person?.updatedAt,
    );

    final provider = context.read<AppProvider>().person;
    if (_isEditing) {
      await provider.update(person);
    } else {
      await provider.add(person);
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
                _isEditing ? 'Editar persona' : 'Nueva persona',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 20),
              Text('Avatar', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 12),
              _AvatarSection(
                avatar: _avatar,
                name: _nameController.text,
                color: _color,
                onPickPhoto: _pickPhoto,
                onSelectEmoji: (emoji) => setState(() {
                  _avatar = '${AppConstants.avatarEmojiPrefix}$emoji';
                }),
                onClear: () => setState(() => _avatar = ''),
                pickingPhoto: _pickingPhoto,
              ),
              const SizedBox(height: 20),
              Text('Color', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
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
                                ? Theme.of(context).colorScheme.onSurface
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
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activa'),
                subtitle: const Text('Se puede asignar en los movimientos'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(_isEditing ? 'Guardar cambios' : 'Agregar'),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar persona'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
