import 'package:finanzas_hogar/core/constants/app_constants.dart';
import 'package:finanzas_hogar/core/theme/app_colors.dart';
import 'package:finanzas_hogar/core/theme/app_palettes.dart';
import 'package:finanzas_hogar/core/theme/app_theme.dart';
import 'package:finanzas_hogar/data/database/app_database.dart';
import 'package:finanzas_hogar/presentation/providers/app_provider.dart';
import 'package:finanzas_hogar/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppProvider app;

  setUp(() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ${TableNames.settings} (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        },
      ),
    );
    await AppDatabase.instance.setTestDatabase(db);
    app = AppProvider();
  });

  tearDown(() async {
    await AppDatabase.instance.closeTestDatabase();
    app.dispose();
    AppColors.use(AppPalettes.indigo);
    AppTheme.notifier.palette.value = AppPalettes.indigo;
  });

  Widget appHarness() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.notifier.mode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<AppPalette>(
          valueListenable: AppTheme.notifier.palette,
          builder: (context, palette, _) {
            return MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              home: ChangeNotifierProvider.value(
                value: app,
                child: const SettingsScreen(),
              ),
            );
          },
        );
      },
    );
  }

  test('AppColors de marca siguen la paleta seleccionada', () {
    AppColors.use(AppPalettes.emerald);
    expect(AppColors.primary, AppPalettes.emerald.primary);
    expect(AppColors.brandGradient, AppPalettes.emerald.brandGradient);
    expect(AppColors.heroGradient, AppPalettes.emerald.heroGradient);
    expect(AppColors.chartPalette.length, 10);
    AppColors.use(AppPalettes.indigo);
    expect(AppColors.primary, AppPalettes.indigo.primary);
  });

  test('el ColorScheme de la app cambia de semilla según la paleta', () {
    AppTheme.notifier.selectPalette(AppPalettes.indigo);
    final indigoPrimary = AppTheme.light().colorScheme.primary;
    AppTheme.notifier.selectPalette(AppPalettes.rose);
    final rosePrimary = AppTheme.light().colorScheme.primary;
    expect(indigoPrimary, isNot(rosePrimary));
  });

  testWidgets('elegir una paleta en Configuración la aplica al tema',
      (tester) async {
    await tester.pumpWidget(appHarness());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('palette-emerald')));
    await tester.pumpAndSettle();

    expect(AppTheme.notifier.palette.value.id, 'emerald');
    expect(AppColors.primary, AppPalettes.emerald.primary);
  });
}