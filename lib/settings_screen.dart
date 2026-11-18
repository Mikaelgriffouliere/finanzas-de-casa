import 'package:flutter/material.dart';

import 'package:finanzas_personales/app_settings.dart';

/// Pantalla de personalización de la app.
///
/// Todos los cambios se guardan solos (paleta y logo) o con un botón
/// explícito (credenciales) usando [AppSettings].
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({this.onReplayIntro, super.key});

  /// Opcional: lo provee la navegación principal para volver a mostrar la
  /// introducción sin acoplar esta pantalla al módulo de onboarding.
  final VoidCallback? onReplayIntro;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final settings = AppSettings.instance.current;
    _user.text = settings.username;
    _password.text = settings.password;
  }

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _saveCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    final current = AppSettings.instance.current;
    await AppSettings.instance.update(
      current.copyWith(username: _user.text.trim(), password: _password.text),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Credenciales actualizadas')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configuración')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<AppSettingsData>(
            valueListenable: AppSettings.instance.values,
            builder: (context, settings, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingsSection(
                  title: 'Tema de la app',
                  icon: Icons.palette_outlined,
                  description:
                      'Elegí el color principal de toda la interfaz. '
                      'El cambio se aplica al instante.',
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var index = 0; index < appPalettes.length; index++)
                          _PaletteTile(
                            palette: appPalettes[index],
                            selected: settings.paletteIndex == index,
                            onTap: () => AppSettings.instance.update(
                              settings.copyWith(paletteIndex: index),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SettingsSection(
                  title: 'Logo de la app',
                  icon: Icons.auto_awesome_outlined,
                  description:
                      'Este ícono se muestra en el inicio de sesión y en la '
                      'barra principal.',
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: paletteFor(settings.paletteIndex)
                            .accent,
                        child: Icon(
                          logoIcon(settings.logoKey),
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final option in logoOptions)
                          _LogoTile(
                            option: option,
                            selected: settings.logoKey == option.key,
                            onTap: () => AppSettings.instance.update(
                              settings.copyWith(logoKey: option.key),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: 'Usuario y contraseña',
            icon: Icons.lock_outline_rounded,
            description:
                'Se usan para entrar a la app en este dispositivo. '
                'Guardá los cambios antes de cerrar sesión.',
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _user,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Ingresá un usuario'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) => (value?.isEmpty ?? true)
                          ? 'Ingresá una contraseña'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saveCredentials,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar credenciales'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: 'Introducción',
            icon: Icons.auto_awesome_rounded,
            description:
                'Volvé a ver los cuatro pasos que explican cómo funciona '
                'Cuentas Claras.',
            children: [
              OutlinedButton.icon(
                onPressed: widget.onReplayIntro,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Volver a ver la introducción'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.description,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF155C4B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.seed : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected ? palette.seed.withValues(alpha: 0.06) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: palette.seed,
              child: selected
                  ? const Icon(Icons.check, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              palette.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              palette.description,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final LogoOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF155C4B) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              option.icon,
              color: selected ? const Color(0xFF155C4B) : Colors.grey.shade600,
            ),
            const SizedBox(height: 6),
            Text(
              option.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
