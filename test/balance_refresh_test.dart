import 'package:finanzas_hogar/core/constants/app_constants.dart';
import 'package:finanzas_hogar/data/database/app_database.dart';
import 'package:finanzas_hogar/domain/entities/account.dart';
import 'package:finanzas_hogar/domain/entities/account_type.dart';
import 'package:finanzas_hogar/domain/entities/transaction.dart';
import 'package:finanzas_hogar/domain/entities/transaction_type.dart';
import 'package:finanzas_hogar/presentation/providers/app_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

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
        onCreate: _createSchema,
      ),
    );
    await AppDatabase.instance.setTestDatabase(db);
    app = AppProvider();
  });

  tearDown(() async {
    await AppDatabase.instance.closeTestDatabase();
    app.dispose();
  });

  test('registrar/liquidar movimientos actualiza el balance total', () async {
    await app.init();

    await app.account.add(const Account(
      name: 'Banco',
      type: AccountType.bankAccount,
      initialBalance: 1000000,
    ));
    final accountId = app.account.accounts.first.id!;
    expect(app.account.totalBalance, 1000000);

    await app.transaction.addIncome(Transaction(
      type: TransactionType.income,
      amount: 500000,
      date: DateTime.now(),
      accountId: accountId,
    ));
    await _waitForBalance(app, 1500000);
    await _waitForSummary(app, income: 500000, expense: 0);

    await app.transaction.addExpense(Transaction(
      type: TransactionType.expense,
      amount: 200000,
      date: DateTime.now(),
      accountId: accountId,
    ));
    await _waitForBalance(app, 1300000);
    await _waitForSummary(app, income: 500000, expense: 200000);

    await app.transaction.delete(app.transaction.transactions.first.id!);
    await _waitForBalance(app, 1500000);
    await _waitForSummary(app, income: 500000, expense: 0);

    await app.transaction.delete(app.transaction.transactions.first.id!);
    await _waitForBalance(app, 1000000);
    await _waitForSummary(app, income: 0, expense: 0);
  });
}

Future<void> _waitForSummary(
  AppProvider app, {
  required int income,
  required int expense,
}) async {
  for (var i = 0; i < 100; i++) {
    final s = app.statistics.summary;
    if (s != null && s.income == income && s.expense == expense) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  final s = app.statistics.summary;
  debugPrint(
      'resumen actual: income=${s?.income} expense=${s?.expense}');
  fail('el resumen mensual no reflejó el movimiento '
      '(esperado income=$income expense=$expense)');
}

Future<void> _waitForBalance(AppProvider app, int expected) async {
  for (var i = 0; i < 100; i++) {
    if (app.account.totalBalance == expected) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  debugPrint('balance actual: ${app.account.totalBalance}');
  fail('balance total (${app.account.totalBalance}) '
      'no reflejó el movimiento ($expected)');
}

Future<void> _createSchema(Database db, int version) async {
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
    CREATE TABLE ${TableNames.accounts} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      currency TEXT NOT NULL DEFAULT 'ARS',
      is_active INTEGER NOT NULL DEFAULT 1,
      initial_balance INTEGER NOT NULL DEFAULT 0,
      created_at TEXT,
      updated_at TEXT
    )
  ''');
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
  await db.execute('''
    CREATE TABLE ${TableNames.transactions} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      amount INTEGER NOT NULL,
      date INTEGER NOT NULL,
      category_id INTEGER REFERENCES ${TableNames.categories}(id) ON DELETE SET NULL,
      subcategory_id INTEGER REFERENCES ${TableNames.subcategories}(id) ON DELETE SET NULL,
      person_id INTEGER REFERENCES ${TableNames.persons}(id) ON DELETE SET NULL,
      account_id INTEGER REFERENCES ${TableNames.accounts}(id) ON DELETE SET NULL,
      transfer_account_id INTEGER REFERENCES ${TableNames.accounts}(id) ON DELETE SET NULL,
      description TEXT NOT NULL DEFAULT '',
      notes TEXT NOT NULL DEFAULT '',
      is_recurring INTEGER NOT NULL DEFAULT 0,
      created_at TEXT,
      updated_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE ${TableNames.recurringTransactions} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      amount INTEGER NOT NULL,
      is_income INTEGER NOT NULL DEFAULT 0,
      category_id INTEGER REFERENCES ${TableNames.categories}(id) ON DELETE SET NULL,
      account_id INTEGER REFERENCES ${TableNames.accounts}(id) ON DELETE SET NULL,
      person_id INTEGER REFERENCES ${TableNames.persons}(id) ON DELETE SET NULL,
      frequency TEXT NOT NULL,
      due_day INTEGER NOT NULL,
      start_date INTEGER NOT NULL,
      end_date INTEGER,
      is_active INTEGER NOT NULL DEFAULT 1,
      kind TEXT NOT NULL DEFAULT 'variable',
      description TEXT NOT NULL DEFAULT '',
      created_at TEXT,
      updated_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE ${TableNames.budgets} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category_id INTEGER NOT NULL REFERENCES ${TableNames.categories}(id) ON DELETE CASCADE,
      amount INTEGER NOT NULL,
      start_date INTEGER NOT NULL,
      end_date INTEGER,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE ${TableNames.savingsGoals} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      target_amount INTEGER NOT NULL,
      current_amount INTEGER NOT NULL DEFAULT 0,
      target_date INTEGER,
      priority INTEGER NOT NULL DEFAULT 2,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT,
      updated_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE ${TableNames.savingsMovements} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      savings_goal_id INTEGER NOT NULL REFERENCES ${TableNames.savingsGoals}(id) ON DELETE CASCADE,
      amount INTEGER NOT NULL,
      is_deposit INTEGER NOT NULL DEFAULT 1,
      date INTEGER NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      account_id INTEGER REFERENCES ${TableNames.accounts}(id) ON DELETE SET NULL,
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
}