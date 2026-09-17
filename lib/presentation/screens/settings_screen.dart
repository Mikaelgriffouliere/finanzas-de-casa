import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptic_helper.dart';
import '../common/glass_card.dart';
import '../../data/database/app_database.dart';
import '../../data/services/seed_data_service.dart';
import '../../domain/entities/currency.dart';
import '../../presentation/common/confirm_dialog.dart';
import '../../presentation/providers/app_provider.dart';
import 'auth/pin_dialog.dart';

/// Configuración de la moneda por defecto (en memoria por ahora).
class CurrencySettings {
  static final ValueNotifier<String> defaultCurrency = ValueNotifier<String>(
    Currency.ars.code,
  );

  static String get symbol {
    return Currency.fromCode(defaultCurrency.value).symbol;
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _resetting = false;
  bool _biometricSupported = false;
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    var supported = false;
    try {
      supported =
          await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics;
    } catch (_) {
      supported = false;
    }
    if (mounted) setState(() => _biometricSupported = supported);
  }

  Future<void> _enablePin() async {
    final pin = await showSetPinDialog(context);
    if (pin == null || !mounted) return;
    try {
      await context.read<AppProvider>().security.setPin(pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN configurado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo configurar el PIN: $e')),
        );
      }
    }
  }

  Future<void> _disablePin() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Desactivar bloqueo PIN',
      message:
          'Se quitará el PIN y la biometría. La app se abrirá sin bloqueo.',
      confirmLabel: 'Desactivar',
    );
    if (!ok || !mounted) return;
    await context.read<AppProvider>().security.disablePin();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bloqueo desactivado')));
    }
  }

  Future<void> _changePin() async {
    final security = context.read<AppProvider>().security;
    final oldPin = await showAskPinDialog(context);
    if (oldPin == null || !mounted) return;
    if (!await security.verifyPin(oldPin)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El PIN actual es incorrecto')),
        );
      }
      return;
    }
    if (!mounted) return;
    final newPin = await showSetPinDialog(context);
    if (newPin == null || !mounted) return;
    await security.setPin(newPin);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN actualizado')));
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    final security = context.read<AppProvider>().security;
    if (enabled && !_biometricSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La biometría no está disponible en este dispositivo'),
        ),
      );
      return;
    }
    await security.setBiometricEnabled(enabled);
  }

  Future<void> _resetData() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Resetear datos',
      message:
          'Se eliminarán todas las personas, cuentas, movimientos, presupuestos y ahorros. Esta acción no se puede deshacer.',
      confirmLabel: 'Resetear',
    );
    if (!ok) return;

    setState(() => _resetting = true);
    try {
      final db = await AppDatabase.instance.getDatabase();
      await db.transaction((txn) async {
        await txn.delete('savings_movements');
        await txn.delete('savings_goals');
        await txn.delete('budgets');
        await txn.delete('recurring_transactions');
        await txn.delete('transactions');
        await txn.delete('subcategories');
        await txn.delete('accounts');
        await txn.delete('categories');
        await txn.delete('persons');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos eliminados correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al resetear datos: $e')));
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _seedExampleData() async {
    setState(() => _resetting = true);
    try {
      await SeedDataService.instance.seedIfEmpty();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos de ejemplo generados correctamente'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar datos de ejemplo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: _resetting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _SectionTitle(title: 'Apariencia'),
                GlassCard(
                  padding: EdgeInsets.zero,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: const Text('Tema'),
                        subtitle: const Text('Elegí cómo se ve la aplicación'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.light_mode_outlined),
                        title: const Text('Claro'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          HapticHelper.selection();
                          AppTheme.notifier.setLight();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.dark_mode_outlined),
                        title: const Text('Oscuro'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          HapticHelper.selection();
                          AppTheme.notifier.setDark();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.brightness_auto),
                        title: const Text('Sistema'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          HapticHelper.selection();
                          AppTheme.notifier.setSystem();
                        },
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Paleta de colores',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: ValueListenableBuilder<AppPalette>(
                          valueListenable: AppTheme.notifier.palette,
                          builder: (context, selected, _) {
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final palette in AppPalettes.all)
                                  _PaletteSwatch(
                                    key: ValueKey('palette-${palette.id}'),
                                    palette: palette,
                                    selected: palette.id == selected.id,
                                    onTap: () => AppTheme.notifier
                                        .selectPalette(palette),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      ValueListenableBuilder<bool>(
                        valueListenable: DynamicColorSettings.enabled,
                        builder: (context, value, _) {
                          return SwitchListTile(
                            secondary: const Icon(Icons.palette),
                            title: const Text('Colores dinámicos'),
                            subtitle: const Text(
                              'Variante más saturada de la paleta (Android 12+)',
                            ),
                            value: value,
                            onChanged: (v) =>
                                DynamicColorSettings.enabled.value = v,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _SectionTitle(title: 'Moneda'),
                GlassCard(
                  padding: EdgeInsets.zero,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ValueListenableBuilder<String>(
                    valueListenable: CurrencySettings.defaultCurrency,
                    builder: (context, value, _) {
                      return ListTile(
                        leading: const Icon(Icons.attach_money),
                        title: const Text('Moneda principal'),
                        subtitle: Text(
                          '${Currency.fromCode(value).symbol} ${Currency.fromCode(value).code}',
                        ),
                        trailing: DropdownMenu<String>(
                          initialSelection: value,
                          dropdownMenuEntries: Currency.values
                              .map(
                                (c) => DropdownMenuEntry(
                                  value: c.code,
                                  label: c.code,
                                ),
                              )
                              .toList(),
                          onSelected: (v) {
                            if (v != null) {
                              CurrencySettings.defaultCurrency.value = v;
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                _SectionTitle(title: 'Seguridad'),
                GlassCard(
                  padding: EdgeInsets.zero,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Builder(
                    builder: (context) {
                      final security = context.watch<AppProvider>().security;
                      return Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.lock_outline),
                            title: const Text('Bloqueo por PIN'),
                            subtitle: Text(
                              security.pinEnabled
                                  ? 'PIN activo: se pide al abrir la app'
                                  : 'Bloqueá la app con un PIN de 4 dígitos',
                            ),
                            value: security.pinEnabled,
                            onChanged: (v) => v ? _enablePin() : _disablePin(),
                          ),
                          if (security.pinEnabled) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.pin_outlined),
                              title: const Text('Cambiar PIN'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _changePin,
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              secondary: const Icon(Icons.fingerprint),
                              title: const Text('Usar biometría'),
                              subtitle: Text(
                                _biometricSupported
                                    ? 'Desbloqueá con huella o reconocimiento facial'
                                    : 'No disponible en este dispositivo',
                              ),
                              value: security.biometricEnabled,
                              onChanged: _biometricSupported
                                  ? _toggleBiometric
                                  : null,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                _SectionTitle(title: 'Datos'),
                GlassCard(
                  padding: EdgeInsets.zero,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.auto_fix_high),
                        title: const Text('Generar datos de ejemplo'),
                        subtitle: const Text(
                          'Categorías, personas, cuentas y movimientos de prueba',
                        ),
                        onTap: _seedExampleData,
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(
                          Icons.delete_forever,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          'Resetear datos',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        subtitle: const Text(
                          'Elimina toda la información de la aplicación',
                        ),
                        onTap: _resetData,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Versión 1.0.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).viewPadding.bottom + 24,
                ),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteSwatch({
    super.key,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: palette.brandGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(palette.name, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
