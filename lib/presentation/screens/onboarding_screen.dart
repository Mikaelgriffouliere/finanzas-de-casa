import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/theme/app_colors.dart';
import '../../data/database/app_database.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static final _pages = _OnboardingPageData.list;

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  Future<void> _finish() async {
    await _markSeen();
    if (!mounted) return;
    widget.onFinished();
  }

  Future<void> _markSeen() async {
    final db = await AppDatabase.instance.getDatabase();
    await db.insert('settings', {
      'key': 'onboarding_seen',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skip,
                child: Text(
                  'Omitir',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) =>
                    _OnboardingPage(data: _pages[i], isDark: isDark),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _page == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _page == i
                                ? AppColors.primary
                                : theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _page == _pages.length - 1 ? 'Comenzar' : 'Siguiente',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  final bool isDark;

  const _OnboardingPage({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 56, color: data.color),
          ),
          const SizedBox(height: 32),
          Text(
            data.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            data.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _OnboardingPageData({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  static final list = [
    _OnboardingPageData(
      icon: Icons.account_balance_wallet,
      color: AppColors.primary,
      title: 'Bienvenido a Finanzas en orden',
      body:
          'Tu billetera personal para controlar ingresos, gastos y transferencias de forma sencilla.',
    ),
    _OnboardingPageData(
      icon: Icons.receipt_long,
      color: AppColors.expense,
      title: 'Registra tus movimientos',
      body:
          'Anota cada gasto, ingreso o transferencia. Asignale categoría, subcategoría, persona y cuenta para tener todo organizado.',
    ),
    _OnboardingPageData(
      icon: Icons.pie_chart,
      color: AppColors.income,
      title: 'Visualiza tu resumen',
      body:
          'En el inicio verás tu balance total, ingresos y gastos del mes, además de gráficos por categoría.',
    ),
    _OnboardingPageData(
      icon: Icons.savings,
      color: const Color(0xFF8EF7CD),
      title: 'Metas y presupuestos',
      body:
          'Ponete metas de ahorro y creá presupuestos por categoría para controlar tus gastos cada mes.',
    ),
  ];
}

Future<bool> isOnboardingSeen() async {
  final db = await AppDatabase.instance.getDatabase();
  final result = await db.query(
    'settings',
    columns: ['value'],
    where: "key = 'onboarding_seen'",
  );
  return result.isNotEmpty && result.first['value'] == '1';
}
