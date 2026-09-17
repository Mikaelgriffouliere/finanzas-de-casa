import 'package:finanzas_hogar/core/constants/app_constants.dart';
import 'package:finanzas_hogar/data/database/app_database.dart';
import 'package:finanzas_hogar/domain/entities/category.dart';
import 'package:finanzas_hogar/domain/entities/subcategory.dart';
import 'package:finanzas_hogar/presentation/providers/app_provider.dart';
import 'package:finanzas_hogar/presentation/screens/categories_screen.dart';
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
            CREATE TABLE ${TableNames.categories} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              icon TEXT,
              color TEXT,
              is_default INTEGER NOT NULL DEFAULT 0,
              is_income INTEGER NOT NULL DEFAULT 0,
              created_at TEXT,
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE ${TableNames.subcategories} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category_id INTEGER NOT NULL REFERENCES ${TableNames.categories}(id) ON DELETE CASCADE,
              name TEXT NOT NULL,
              icon TEXT,
              color TEXT,
              is_default INTEGER NOT NULL DEFAULT 0,
              created_at TEXT,
              updated_at TEXT
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

  Future<Category> seedImpuestosConSubcategoria(WidgetTester tester) async {
    await tester.runAsync(() async {
      await app.category.add(
        const Category(name: 'Impuestos', icon: '12', color: '#B2B2B2'),
        isIncome: false,
      );
      final category = app.category.expenseCategories.first;
      await app.category.addSubcategory(
        Subcategory(categoryId: category.id!, name: 'IVA'),
      );
    });
    return app.category.expenseCategories.first;
  }

  testWidgets('el sheet de subcategorías muestra las agregadas y el botón Agregar',
      (tester) async {
    await seedImpuestosConSubcategoria(tester);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: CategoriesScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Impuestos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.runAsync(() async {
      for (var i = 0; i < 150 && !tester.any(find.text('IVA')); i++) {
        await Future.delayed(const Duration(milliseconds: 15));
      }
    });
    await tester.pump();

    expect(find.text('IVA'), findsOneWidget);
    expect(find.text('Agregar'), findsOneWidget);
  });

  test('agregar una subcategoría queda persistida y vuelve con loadByCategory',
      () async {
    await app.category.add(
      const Category(name: 'Impuestos', icon: '12', color: '#B2B2B2'),
      isIncome: false,
    );
    final category = app.category.expenseCategories.first;
    await app.category.addSubcategory(
      Subcategory(categoryId: category.id!, name: 'IVA'),
    );

    final loaded = await app.category.loadByCategory(category.id!);
    expect(loaded.map((s) => s.name), contains('IVA'));
  });
}