import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_palettes.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/database/db_path_resolver.dart';
import 'domain/entities/transaction_type.dart';
import 'presentation/providers/app_provider.dart';
import 'presentation/screens/auth/lock_screen.dart';
import 'presentation/screens/main_shell.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/savings_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/transaction_detail_screen.dart';
import 'presentation/screens/transaction_form_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En Android se oculta la barra de navegación inferior (modo inmersivo).
  if (Platform.isAndroid) {
    _hideNavigationBar();
  }

  // En plataformas de escritorio (con plugin sqflite nativo no disponible)
  // se usa la implementación FFI de SQLite.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Ruta de BD fija (independiente del CWD) + migración de datos previos.
    final dbPath = await DbPathResolver.resolve();
    databaseFactory.setDatabasesPath(p.dirname(dbPath));
  }

  await AppDatabase.instance.getDatabase();

  runApp(
    ChangeNotifierProvider<AppProvider>(
      create: (_) => AppProvider()..init(),
      child: const FinanzasHogarApp(),
    ),
  );
}

/// Oculta la barra de navegación inferior dejando visible solo la barra de
/// estado. Se mantiene oculta hasta que el usuario desliza desde el borde.
void _hideNavigationBar() {
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values
        .where((overlay) => overlay != SystemUiOverlay.bottom)
        .toList(),
  );
}

class FinanzasHogarApp extends StatelessWidget {
  const FinanzasHogarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.notifier.mode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<AppPalette>(
          valueListenable: AppTheme.notifier.palette,
          builder: (context, palette, _) {
            return MaterialApp(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              home: const AppGate(),
              routes: {
                SavingsGoalDetailScreen.routeName: (context) {
                  final arguments = ModalRoute.of(context)?.settings.arguments;
                  final map = arguments is Map<String, dynamic>
                      ? arguments
                      : const <String, dynamic>{};
                  return SavingsGoalDetailScreen(
                    goalId: map['id'] as int? ?? 0,
                  );
                },
              },
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case TransactionFormScreen.newRoute:
                    final arguments = settings.arguments;
                    final map = arguments is Map<String, dynamic>
                        ? arguments
                        : const <String, dynamic>{};
                    final type = TransactionType.values.firstWhere(
                      (t) => t.name == map['type'],
                      orElse: () => TransactionType.expense,
                    );
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (_) => TransactionFormScreen(initialType: type),
                    );
                  case TransactionFormScreen.editRoute:
                    final arguments = settings.arguments;
                    final map = arguments is Map<String, dynamic>
                        ? arguments
                        : const <String, dynamic>{};
                    final id = map['id'] as int?;
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (context) {
                        final app = context.read<AppProvider>();
                        final transaction = app.transaction.byId(id);
                        if (transaction == null) {
                          return const TransactionFormScreen();
                        }
                        return TransactionDetailScreen(
                          transaction: transaction,
                        );
                      },
                    );
                }
                return null;
              },
            );
          },
        );
      },
    );
  }
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  bool? _onboardingSeen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) _hideNavigationBar();
    _checkOnboarding();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de segundo plano el sistema puede restaurar la barra.
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      _hideNavigationBar();
    }
  }

  Future<void> _checkOnboarding() async {
    final seen = await isOnboardingSeen();
    if (mounted) setState(() => _onboardingSeen = seen);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.initialized || _onboardingSeen == null) {
      return const SplashScreen();
    }
    if (!_onboardingSeen!) {
      return OnboardingScreen(
        onFinished: () => setState(() => _onboardingSeen = true),
      );
    }
    if (app.security.pinEnabled && !app.security.unlocked) {
      return const LockScreen();
    }
    return const MainShell();
  }
}
