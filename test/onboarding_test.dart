import 'package:finanzas_hogar/data/database/app_database.dart';
import 'package:finanzas_hogar/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        },
      ),
    );
    await AppDatabase.instance.setTestDatabase(db);
  });

  tearDown(() async {
    await AppDatabase.instance.closeTestDatabase();
  });

  testWidgets('al terminar el onboarding se marca como visto', (tester) async {
    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onFinished: () => finished = true,
        ),
      ),
    );

    expect(find.textContaining('Bienvenido'), findsOneWidget);

    await tester.tap(find.text('Omitir'));

    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !finished; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(finished, isTrue);

    var seen = false;
    await tester.runAsync(() async => seen = await isOnboardingSeen());
    expect(seen, isTrue);
  });

  testWidgets('llega hasta el último paso y muestra Comenzar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onFinished: () {}),
      ),
    );

    expect(find.text('Siguiente'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Comenzar'), findsOneWidget);
  });
}