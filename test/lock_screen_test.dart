import 'package:finanzas_hogar/core/constants/app_constants.dart';
import 'package:finanzas_hogar/data/database/app_database.dart';
import 'package:finanzas_hogar/presentation/providers/app_provider.dart';
import 'package:finanzas_hogar/presentation/screens/auth/lock_screen.dart';
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
  });

  Future<void> pumpLockScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: app,
          child: const LockScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapConfirm(WidgetTester tester) async {
    await tester.ensureVisible(find.byIcon(Icons.check_circle));
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.check_circle));
      for (var i = 0; i < 150 && !app.security.unlocked; i++) {
        await Future.delayed(const Duration(milliseconds: 15));
      }
    });
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('el keypad registra los toques y los puntos se llenan',
      (tester) async {
    await tester.runAsync(() => app.security.setPin('1234'));
    await pumpLockScreen(tester);

    for (final digit in ['1', '2', '3', '4']) {
      await tapKey(tester, find.text(digit));
    }
    expect(find.byType(AnimatedContainer), findsNWidgets(4));
  });

  testWidgets('con PIN correcto desbloquea', (tester) async {
    await tester.runAsync(() => app.security.setPin('1234'));
    await pumpLockScreen(tester);

    for (final digit in ['1', '2', '3', '4']) {
      await tapKey(tester, find.text(digit));
    }
    await tapConfirm(tester);

    expect(app.security.unlocked, isTrue);
  });

  testWidgets('al desbloquear la UI pasa del lock a la app (AppGate)',
      (tester) async {
    await tester.runAsync(() => app.security.setPin('1234'));
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: app,
          child: Builder(
            builder: (context) {
              final security = context.watch<AppProvider>().security;
              return security.unlocked
                  ? const Scaffold(
                      body: Text('APP_DESBLOQUEADA'),
                    )
                  : const LockScreen();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('APP_DESBLOQUEADA'), findsNothing);
    for (final digit in ['1', '2', '3', '4']) {
      await tapKey(tester, find.text(digit));
    }
    await tapConfirm(tester);

    expect(find.text('APP_DESBLOQUEADA'), findsOneWidget);
  });

  testWidgets('con PIN incorrecto muestra error y no desbloquea', (tester) async {
    await tester.runAsync(() => app.security.setPin('1234'));
    await pumpLockScreen(tester);

    for (final digit in ['0', '0', '0', '0']) {
      await tapKey(tester, find.text(digit));
    }
    await tapConfirm(tester);

    expect(app.security.unlocked, isFalse);
    expect(find.text('PIN incorrecto, volvé a intentar'), findsOneWidget);
  });

  testWidgets('el botón borrar quita el último dígito', (tester) async {
    await tester.runAsync(() => app.security.setPin('1234'));
    await pumpLockScreen(tester);

    await tapKey(tester, find.text('1'));
    await tapKey(tester, find.text('2'));
    await tapKey(tester, find.text('7'));
    await tapKey(tester, find.byIcon(Icons.backspace_outlined));
    await tapKey(tester, find.text('3'));
    await tapKey(tester, find.text('4'));
    await tapConfirm(tester);

    expect(app.security.unlocked, isTrue);
  });
}