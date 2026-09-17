import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../common/glass_card.dart';
import 'accounts_screen.dart';
import 'backup_screen.dart';
import 'calendar_screen.dart';
import 'categories_screen.dart';
import 'contributions_screen.dart';
import 'persons_screen.dart';
import 'recurring_screen.dart';
import 'reports_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _selectTheme(BuildContext context) async {
    final mode = AppTheme.notifier.mode.value;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Claro'),
              trailing: mode == ThemeMode.light
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                AppTheme.notifier.setLight();
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Oscuro'),
              trailing: mode == ThemeMode.dark ? const Icon(Icons.check) : null,
              onTap: () {
                AppTheme.notifier.setDark();
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('Sistema'),
              trailing: mode == ThemeMode.system
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                AppTheme.notifier.setSystem();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          0,
          8,
          0,
          MediaQuery.of(context).viewPadding.bottom + 32,
        ),
        children: [
          SizedBox(height: 4),
          _CardSection(
            title: 'Personas del hogar',
            children: [
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Personas'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const PersonsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.pie_chart),
                title: const Text('Resumen de aportes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const ContributionsScreen()),
              ),
            ],
          ),
          _CardSection(
            title: 'Finanzas',
            children: [
              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('Cuentas'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const AccountsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('Categorías'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const CategoriesScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('Movimientos recurrentes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const RecurringScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Calendario'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const CalendarScreen()),
              ),
            ],
          ),
          _CardSection(
            title: 'Reportes',
            children: [
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Reportes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const ReportsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Búsqueda'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const SearchScreen()),
              ),
            ],
          ),
          _CardSection(
            title: 'Configuración',
            children: [
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Configuración'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const SettingsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Backup y exportación'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const BackupScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.contrast),
                title: const Text('Tema'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectTheme(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CardSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          tint: theme.colorScheme.primary,
          child: Column(children: children),
        ),
      ],
    );
  }
}
