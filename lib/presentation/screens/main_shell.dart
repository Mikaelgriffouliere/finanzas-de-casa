import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_helper.dart';
import '../common/glass_card.dart';
import '../common/fade_in_up.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'budgets_screen.dart';
import 'savings_screen.dart';
import 'more_screen.dart';
import 'transaction_form_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const String routeName = '/';

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  Future<void> _openNewTransaction() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'Nuevo movimiento',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              _TypeTile(
                icon: Icons.arrow_downward,
                color: AppColors.income,
                title: 'Ingreso',
                subtitle: 'Dinero que llega a tus cuentas',
                onTap: () => Navigator.pop(context, 'income'),
              ),
              _TypeTile(
                icon: Icons.arrow_upward,
                color: AppColors.expense,
                title: 'Gasto',
                subtitle: 'Dinero que sale de tus cuentas',
                onTap: () => Navigator.pop(context, 'expense'),
              ),
              _TypeTile(
                icon: Icons.swap_horiz,
                color: AppColors.transfer,
                title: 'Transferencia',
                subtitle: 'Mueve dinero entre tus cuentas',
                onTap: () => Navigator.pop(context, 'transfer'),
              ),
            ],
          ),
        ),
      ),
    );

    if (type == null || !mounted) return;

    HapticHelper.light();
    Navigator.of(
      context,
    ).pushNamed(TransactionFormScreen.newRoute, arguments: {'type': type});
  }

  void _open(Widget screen) {
    HapticHelper.selection();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openDashboard() {
    HapticHelper.selection();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Inicio')),
          body: const DashboardScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.brandGradient,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.payments, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(AppConstants.appName),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          FadeInUp(
            child: GlassCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              borderRadius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola 👋',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¿Qué querés hacer hoy?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 80),
            child: _MenuTile(
              icon: Icons.home_outlined,
              color: AppColors.primary,
              title: 'Inicio',
              subtitle: 'Resumen, gráficos y tus últimos movimientos',
              onTap: _openDashboard,
            ),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 160),
            child: _MenuTile(
              icon: Icons.swap_horiz,
              color: AppColors.primary,
              title: 'Movimientos',
              subtitle: 'Ingresos, gastos y transferencias',
              onTap: () => _open(const TransactionsScreen()),
            ),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 240),
            child: _MenuTile(
              icon: Icons.pie_chart_outline,
              color: AppColors.primary,
              title: 'Presupuestos',
              subtitle: 'Controlá tus gastos por categoría',
              onTap: () => _open(const BudgetsScreen()),
            ),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 320),
            child: _MenuTile(
              icon: Icons.savings_outlined,
              color: AppColors.primary,
              title: 'Ahorros',
              subtitle: 'Metas y progreso de ahorro',
              onTap: () => _open(const SavingsScreen()),
            ),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: _MenuTile(
              icon: Icons.settings_outlined,
              color: AppColors.primary,
              title: 'Más',
              subtitle: 'Ajustes, seguridad y respaldo',
              onTap: () => _open(const MoreScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewTransaction,
        tooltip: 'Nuevo movimiento',
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.brandGradient,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.add, size: 30, color: Colors.white),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        borderRadius: 20,
        tint: color,
        tintOpacity: 0.10,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TypeTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
