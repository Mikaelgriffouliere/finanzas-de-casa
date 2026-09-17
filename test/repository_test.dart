import 'package:finanzas_hogar/data/database/app_database.dart';
import 'package:finanzas_hogar/data/repositories/account_repository_impl.dart';
import 'package:finanzas_hogar/data/repositories/category_repository_impl.dart';
import 'package:finanzas_hogar/data/repositories/savings_repository_impl.dart';
import 'package:finanzas_hogar/data/repositories/transaction_repository_impl.dart';
import 'package:finanzas_hogar/domain/entities/account.dart';
import 'package:finanzas_hogar/domain/entities/account_type.dart';
import 'package:finanzas_hogar/domain/entities/category.dart';
import 'package:finanzas_hogar/domain/entities/savings_goal.dart';
import 'package:finanzas_hogar/domain/entities/savings_movement.dart';
import 'package:finanzas_hogar/domain/entities/subcategory.dart';
import 'package:finanzas_hogar/domain/entities/transaction.dart';
import 'package:finanzas_hogar/domain/entities/transaction_type.dart';
import 'package:finanzas_hogar/core/constants/app_constants.dart';
import 'package:finanzas_hogar/domain/repositories/transaction_repository.dart'
    show TransactionFilter;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

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
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
        },
      ),
    );
    await AppDatabase.instance.setTestDatabase(db);
  });

  tearDown(() async {
    await AppDatabase.instance.closeTestDatabase();
  });

  group('AccountRepositoryImpl - cálculo de saldos', () {
    test('saldo inicial + ingresos - gastos', () async {
      final accountRepo = AccountRepositoryImpl();
      final account = await accountRepo.create(
        const Account(
          name: 'Banco',
          type: AccountType.bankAccount,
          initialBalance: 1000000,
        ),
      );

      final txRepo = TransactionRepositoryImpl();
      final now = DateTime.now();
      await txRepo.create(Transaction(
        type: TransactionType.income,
        amount: 500000,
        date: now,
        accountId: account.id,
      ));
      await txRepo.create(Transaction(
        type: TransactionType.expense,
        amount: 200000,
        date: now,
        accountId: account.id,
      ));

      final balance = await accountRepo.getAccountBalance(account.id!);
      expect(balance, 1300000); // 1000000 + 500000 - 200000
    });

    test('suma total de todos los saldos', () async {
      final accountRepo = AccountRepositoryImpl();
      final a = await accountRepo.create(
        const Account(name: 'Efectivo', type: AccountType.cash),
      );
      await accountRepo.create(
        const Account(
          name: 'Banco',
          type: AccountType.bankAccount,
          initialBalance: 1000000,
        ),
      );

      final txRepo = TransactionRepositoryImpl();
      final now = DateTime.now();
      await txRepo.create(Transaction(
        type: TransactionType.income,
        amount: 300000,
        date: now,
        accountId: a.id,
      ));

      final total = await accountRepo.getTotalBalance();
      // efectivo: 300000, banco: 1000000
      expect(total, 1300000);
    });
  });

  group('TransactionRepositoryImpl - ingresos, gastos y transferencias', () {
    test('sumByType suma correctamente por rango de fechas', () async {
      final repo = TransactionRepositoryImpl();
      final now = DateTime.now();
      await repo.create(Transaction(
        type: TransactionType.income,
        amount: 100000,
        date: now,
      ));
      await repo.create(Transaction(
        type: TransactionType.income,
        amount: 50000,
        date: now,
      ));
      await repo.create(Transaction(
        type: TransactionType.expense,
        amount: 30000,
        date: now,
      ));

      final income = await repo.sumByType(
        type: TransactionType.income,
        from: DateTime(now.year, now.month, 1),
        to: now,
      );
      expect(income, 150000);

      final expense = await repo.sumByType(
        type: TransactionType.expense,
        from: DateTime(now.year, now.month, 1),
        to: now,
      );
      expect(expense, 30000);
    });

    test('createTransfer mueve saldo entre cuentas sin duplicar', () async {
      final accountRepo = AccountRepositoryImpl();
      final origen = await accountRepo.create(
        const Account(
          name: 'Origen',
          type: AccountType.wallet,
          initialBalance: 500000,
        ),
      );
      final destino = await accountRepo.create(
        const Account(
          name: 'Destino',
          type: AccountType.bankAccount,
          initialBalance: 100000,
        ),
      );

      final repo = TransactionRepositoryImpl();
      await repo.createTransfer(
        Transaction(
          type: TransactionType.transfer,
          amount: 200000,
          date: DateTime.now(),
          accountId: origen.id,
          transferAccountId: destino.id,
        ),
      );

      // El saldo del origen baja 200000, el del destino sube 200000
      final origenBalance = await accountRepo.getAccountBalance(origen.id!);
      final destinoBalance = await accountRepo.getAccountBalance(destino.id!);
      final totalBefore = 500000 + 100000;
      final totalAfter = origenBalance + destinoBalance;

      expect(origenBalance, 300000);
      expect(destinoBalance, 300000);
      // El patrimonio total NO cambia (la transferencia no crea ni destruye dinero)
      expect(totalAfter, totalBefore);

      // La transferencia no debe contarse como ingreso ni gasto
      final ingresos = await repo.sumByType(
        type: TransactionType.income,
        from: DateTime(2020),
        to: DateTime(2030),
      );
      final gastos = await repo.sumByType(
        type: TransactionType.expense,
        from: DateTime(2020),
        to: DateTime(2030),
      );
      expect(ingresos, 0);
      expect(gastos, 0);
    });

    test('filtro por tipo y monto mínimo', () async {
      final repo = TransactionRepositoryImpl();
      final now = DateTime.now();
      await repo.create(Transaction(
        type: TransactionType.expense,
        amount: 50000,
        date: now,
      ));
      await repo.create(Transaction(
        type: TransactionType.expense,
        amount: 150000,
        date: now,
      ));

      final result = await repo.getAll(
        filter: const TransactionFilter(
          type: TransactionType.expense,
          minAmount: 100000,
        ),
      );
      expect(result.length, 1);
      expect(result.first.amount, 150000);
    });
  });

  group('SavingsGoalRepositoryImpl - cálculo de ahorro', () {
    test('depositar suma al current_amount', () async {
      final repo = SavingsGoalRepositoryImpl();
      final goal = await repo.create(SavingsGoal(
        name: 'Fondo',
        targetAmount: 1000000,
        currentAmount: 200000,
      ));

      await repo.addMovement(SavingsMovement(
        savingsGoalId: goal.id!,
        amount: 300000,
        isDeposit: true,
        date: DateTime.now(),
      ));

      final updated = await repo.getById(goal.id!);
      expect(updated!.currentAmount, 500000);
    });

    test('retirar resta del current_amount', () async {
      final repo = SavingsGoalRepositoryImpl();
      final goal = await repo.create(SavingsGoal(
        name: 'Fondo',
        targetAmount: 1000000,
        currentAmount: 500000,
      ));

      await repo.addMovement(SavingsMovement(
        savingsGoalId: goal.id!,
        amount: 200000,
        isDeposit: false,
        date: DateTime.now(),
      ));

      final updated = await repo.getById(goal.id!);
      expect(updated!.currentAmount, 300000);
    });

    test('al alcanzar el objetivo queda completado', () async {
      final repo = SavingsGoalRepositoryImpl();
      final goal = await repo.create(SavingsGoal(
        name: 'Meta',
        targetAmount: 1000000,
        currentAmount: 900000,
      ));

      await repo.addMovement(SavingsMovement(
        savingsGoalId: goal.id!,
        amount: 100000,
        isDeposit: true,
        date: DateTime.now(),
      ));

      final updated = await repo.getById(goal.id!);
      expect(updated!.currentAmount, 1000000);
      expect(updated.status.name, 'completed');
    });
  });

  group('CategoryRepositoryImpl - categorías', () {
    test('crea y lee categoría de gasto e ingreso', () async {
      final repo = CategoryRepositoryImpl();
      final created = await repo.createCategory(
        const Category(
          name: 'Prueba',
          icon: 'category',
        ),
        isIncome: false,
      );

      final expenses = await repo.getByType(isIncome: false);
      final incomes = await repo.getByType(isIncome: true);
      expect(expenses.any((c) => c.id == created.id), isTrue);
      expect(incomes.any((c) => c.id == created.id), isFalse);
    });

    test('crea subcategoría ligada a categoría', () async {
      final repo = CategoryRepositoryImpl();
      final cat = await repo.createCategory(
        const Category(name: 'Hogar'),
        isIncome: false,
      );
      final sub = await repo.createSubcategory(Subcategory(
        categoryId: cat.id!,
        name: 'Expensas',
      ));

      final subs = await repo.getSubcategoriesByCategory(cat.id!);
      expect(subs.length, 1);
      expect(subs.first.id, sub.id);
      expect(subs.first.name, 'Expensas');
    });
  });
}

Future<void> _createSchema(Database db) async {
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
}
