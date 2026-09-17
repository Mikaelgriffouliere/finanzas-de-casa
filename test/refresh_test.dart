import 'package:finanzas_hogar/core/constants/app_constants.dart';
import 'package:finanzas_hogar/data/database/app_database.dart';
import 'package:finanzas_hogar/domain/entities/person.dart';
import 'package:finanzas_hogar/presentation/providers/app_provider.dart';
import 'package:finanzas_hogar/presentation/screens/persons_screen.dart';
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
            CREATE TABLE ${TableNames.persons} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              color TEXT NOT NULL DEFAULT '',
              avatar TEXT NOT NULL DEFAULT '',
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT,
              updated_at TEXT
            )
          ''');
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

  testWidgets('agregar una persona se refleja en la pantalla al instante',
      (tester) async {
    await tester.runAsync(() => app.init());
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: app,
          child: const PersonsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('María'), findsNothing);

    await tester.runAsync(() => app.person.add(
          Person(name: 'María', description: '', color: '#9DB6D4'),
        ));
    await tester.pumpAndSettle();

    expect(find.text('María'), findsOneWidget);
  });

  testWidgets('eliminar una persona se refleja en la pantalla al instante',
      (tester) async {
    await tester.runAsync(() => app.init());
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: app,
          child: const PersonsScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.runAsync(() => app.person.add(
          Person(name: 'Juan', description: '', color: '#7FAE96'),
        ));
    await tester.pumpAndSettle();
    expect(find.text('Juan'), findsOneWidget);

    await tester.runAsync(() => app.person.delete(app.person.persons.first.id!));
    await tester.pumpAndSettle();

    expect(find.text('Juan'), findsNothing);
  });
}