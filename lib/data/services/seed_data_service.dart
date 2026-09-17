import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../database/app_database.dart';

/// Seeds sample data on first launch if no persons exist.
class SeedDataService {
  SeedDataService._();

  static final SeedDataService instance = SeedDataService._();

  Future<void> seedIfEmpty() async {
    final db = await AppDatabase.instance.getDatabase();
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${TableNames.persons}'),
    );
    if (count != null && count > 0) return;

    await _seedPersons(db);
    await _seedAccounts(db);
    await _seedIncomeCategories(db);
    await _seedTransactions(db);
    await _seedBudgets(db);
    await _seedSavingsGoals(db);
    await _seedRecurringTransactions(db);
  }

  Future<void> _seedPersons(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.insert(TableNames.persons, {
      'name': 'Yo',
      'color': '#4CAF50',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(TableNames.persons, {
      'name': 'Pareja',
      'color': '#2196F3',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> _seedAccounts(Database db) async {
    final now = DateTime.now().toIso8601String();
    final accounts = [
      {'name': 'Efectivo', 'type': 'cash'},
      {'name': 'Banco', 'type': 'bank_account'},
      {'name': 'Mercado Pago', 'type': 'wallet'},
      {'name': 'Tarjeta', 'type': 'card'},
    ];
    for (final a in accounts) {
      await db.insert(TableNames.accounts, {
        ...a,
        'is_active': 1,
        'initial_balance': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<void> _seedIncomeCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    for (final c in DefaultCategories.incomeCategories) {
      await db.insert(TableNames.categories, {
        'name': c.name,
        'icon': c.icon,
        'is_default': 1,
        'is_income': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// Returns category id by name (assumes defaults already exist).
  Future<int> _catId(Database db, String name, {bool income = false}) async {
    final rows = await db.query(
      TableNames.categories,
      columns: ['id'],
      where: 'name = ? AND is_income = ?',
      whereArgs: [name, income ? 1 : 0],
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    // fallback: first category
    final fallback = await db.query(TableNames.categories, columns: ['id'], limit: 1);
    return fallback.first['id'] as int;
  }

  Future<void> _seedTransactions(Database db) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final prevMonth = DateTime(now.year, now.month - 1, 1);

    final currentMonthTs = currentMonth.millisecondsSinceEpoch;
    final prevMonthTs = prevMonth.millisecondsSinceEpoch;

    final catHogar = await _catId(db, 'Hogar');
    final catAlimentacion = await _catId(db, 'Alimentación');
    final catTransporte = await _catId(db, 'Transporte');
    final catOcio = await _catId(db, 'Ocio');
    final catSueldo = await _catId(db, 'Sueldo', income: true);
    final catTrabajo = await _catId(db, 'Trabajo independiente', income: true);

    final nowStr = DateTime.now().toIso8601String();

    // Incomes - current month
    final transactions = <Map<String, dynamic>>[
      // Sueldo Yo
      {
        'type': 'income',
        'amount': 120000000, // $1.200.000
        'date': currentMonthTs + 86400000 * 4,
        'category_id': catSueldo,
        'person_id': 1,
        'account_id': 2,
        'description': 'Sueldo mensual',
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      // Sueldo Pareja
      {
        'type': 'income',
        'amount': 90000000, // $900.000
        'date': currentMonthTs + 86400000 * 5,
        'category_id': catSueldo,
        'person_id': 2,
        'account_id': 2,
        'description': 'Sueldo mensual',
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      // Freelance
      {
        'type': 'income',
        'amount': 50000000, // $500.000
        'date': currentMonthTs + 86400000 * 10,
        'category_id': catTrabajo,
        'person_id': 1,
        'account_id': 3,
        'description': 'Proyecto freelance',
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      // Expenses - current month
      {
        'type': 'expense',
        'amount': 35000000, // $350.000
        'date': currentMonthTs + 86400000 * 1,
        'category_id': catHogar,
        'person_id': 1,
        'account_id': 2,
        'description': 'Expensas',
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'type': 'expense',
        'amount': 25000000, // $250.000
        'date': currentMonthTs + 86400000 * 3,
        'category_id': catAlimentacion,
        'person_id': 1,
        'account_id': 3,
        'description': 'Supermercado',
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'type': 'expense',
        'amount': 15000000, // $150.000
        'date': currentMonthTs + 86400000 * 7,
        'category_id': catTransporte,
        'person_id': 1,
        'account_id': 1,
        'description': 'Nafta',
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'type': 'expense',
        'amount': 12000000, // $120.000
        'date': currentMonthTs + 86400000 * 12,
        'category_id': catOcio,
        'person_id': 2,
        'account_id': 4,
        'description': 'Cena afuera',
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      // Previous month incomes
      {
        'type': 'income',
        'amount': 120000000,
        'date': prevMonthTs + 86400000 * 4,
        'category_id': catSueldo,
        'person_id': 1,
        'account_id': 2,
        'description': 'Sueldo mensual',
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'type': 'income',
        'amount': 90000000,
        'date': prevMonthTs + 86400000 * 5,
        'category_id': catSueldo,
        'person_id': 2,
        'account_id': 2,
        'description': 'Sueldo mensual',
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      // Previous month expenses
      {
        'type': 'expense',
        'amount': 35000000,
        'date': prevMonthTs + 86400000 * 1,
        'category_id': catHogar,
        'person_id': 1,
        'account_id': 2,
        'description': 'Expensas',
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'type': 'expense',
        'amount': 28000000,
        'date': prevMonthTs + 86400000 * 3,
        'category_id': catAlimentacion,
        'person_id': 1,
        'account_id': 3,
        'description': 'Supermercado',
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'type': 'expense',
        'amount': 18000000,
        'date': prevMonthTs + 86400000 * 8,
        'category_id': catTransporte,
        'person_id': 1,
        'account_id': 1,
        'description': 'Nafta',
        'created_at': nowStr,
        'updated_at': nowStr,
      },
    ];

    for (final t in transactions) {
      await db.insert(TableNames.transactions, t);
    }
  }

  Future<void> _seedBudgets(Database db) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final nowStr = now.toIso8601String();

    final catAlimentacion = await _catId(db, 'Alimentación');
    final catTransporte = await _catId(db, 'Transporte');

    await db.insert(TableNames.budgets, {
      'category_id': catAlimentacion,
      'amount': 80000000, // $800.000
      'start_date': startOfMonth.millisecondsSinceEpoch,
      'is_active': 1,
      'created_at': nowStr,
      'updated_at': nowStr,
    });

    await db.insert(TableNames.budgets, {
      'category_id': catTransporte,
      'amount': 20000000, // $200.000
      'start_date': startOfMonth.millisecondsSinceEpoch,
      'is_active': 1,
      'created_at': nowStr,
      'updated_at': nowStr,
    });
  }

  Future<void> _seedSavingsGoals(Database db) async {
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final threeMonths = DateTime(now.year, now.month + 3, now.day);
    final sixMonths = DateTime(now.year, now.month + 6, now.day);

    // Goal 1: Vacation
    final goalId1 = await db.insert(TableNames.savingsGoals, {
      'name': 'Vacaciones',
      'description': 'Viaje a Bariloche',
      'target_amount': 500000000, // $5.000.000
      'current_amount': 150000000, // $1.500.000
      'target_date': threeMonths.millisecondsSinceEpoch,
      'priority': 1,
      'status': 'active',
      'created_at': nowStr,
      'updated_at': nowStr,
    });

    await db.insert(TableNames.savingsMovements, {
      'savings_goal_id': goalId1,
      'amount': 150000000,
      'is_deposit': 1,
      'date': now.millisecondsSinceEpoch,
      'description': 'Aporte inicial',
      'account_id': 2,
      'created_at': nowStr,
      'updated_at': nowStr,
    });

    // Goal 2: Emergency fund
    final goalId2 = await db.insert(TableNames.savingsGoals, {
      'name': 'Fondo de emergencia',
      'description': '6 meses de gastos fijos',
      'target_amount': 1200000000, // $12.000.000
      'current_amount': 400000000, // $4.000.000
      'target_date': sixMonths.millisecondsSinceEpoch,
      'priority': 2,
      'status': 'active',
      'created_at': nowStr,
      'updated_at': nowStr,
    });

    await db.insert(TableNames.savingsMovements, {
      'savings_goal_id': goalId2,
      'amount': 200000000,
      'is_deposit': 1,
      'date': now.millisecondsSinceEpoch,
      'description': 'Primer aporte',
      'account_id': 2,
      'created_at': nowStr,
      'updated_at': nowStr,
    });
    await db.insert(TableNames.savingsMovements, {
      'savings_goal_id': goalId2,
      'amount': 200000000,
      'is_deposit': 1,
      'date': now.subtract(const Duration(days: 15)).millisecondsSinceEpoch,
      'description': 'Segundo aporte',
      'account_id': 3,
      'created_at': nowStr,
      'updated_at': nowStr,
    });
  }

  Future<void> _seedRecurringTransactions(Database db) async {
    final now = DateTime.now();
    final nowStr = now.toIso8601String();

    final catHogar = await _catId(db, 'Hogar');

    await db.insert(TableNames.recurringTransactions, {
      'name': 'Alquiler',
      'amount': 280000000, // $2.800.000
      'is_income': 0,
      'category_id': catHogar,
      'account_id': 2,
      'person_id': 1,
      'frequency': 'monthly',
      'due_day': 5,
      'start_date': DateTime(now.year, 1, 1).millisecondsSinceEpoch,
      'is_active': 1,
      'kind': 'fixed',
      'description': 'Alquiler mensual',
      'created_at': nowStr,
      'updated_at': nowStr,
    });

    await db.insert(TableNames.recurringTransactions, {
      'name': 'Internet',
      'amount': 12000000, // $120.000
      'is_income': 0,
      'category_id': catHogar,
      'account_id': 2,
      'frequency': 'monthly',
      'due_day': 10,
      'start_date': DateTime(now.year, 1, 1).millisecondsSinceEpoch,
      'is_active': 1,
      'kind': 'fixed',
      'description': 'Internet fibra óptica',
      'created_at': nowStr,
      'updated_at': nowStr,
    });
  }
}
