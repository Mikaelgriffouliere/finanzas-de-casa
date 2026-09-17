import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';

/// Helper de acceso a SQLite. Implementa migraciones y crea índices.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Database? get database => _database;

  Future<Database> getDatabase() async {
    if (_database != null) return _database!;
    final path = await _getDbPath();
    _database = await _openDatabase(path);
    return _database!;
  }

  /// Permite a los tests inyectar una base de datos (p.ej. en memoria con FFI).
  /// `setDatabaseFactoryFfi` debe llamarse antes desde el test.
  @visibleForTesting
  Future<void> setTestDatabase(Database db) async {
    _database = db;
  }

  @visibleForTesting
  Future<void> closeTestDatabase() async {
    await _database?.close();
    _database = null;
  }

  Future<String> _getDbPath() async {
    if (kIsWeb) return AppConstants.dbName;
    final databasesPath = await getDatabasesPath();
    return join(databasesPath, AppConstants.dbName);
  }

  Future<Database> _openDatabase(String path) {
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createTables,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    final batch = db.batch();

    // ---- PRINCIPALES ----
    batch.execute('''
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

    batch.execute('''
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

    batch.execute('''
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

    batch.execute('''
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

    batch.execute('''
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

    // ---- RECURRENTES ----
    batch.execute('''
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

    // ---- PRESUPUESTOS ----
    batch.execute('''
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

    // ---- AHORROS ----
    batch.execute('''
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

    batch.execute('''
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

    // ---- CONFIGURACIÓN ----
    batch.execute('''
      CREATE TABLE ${TableNames.settings} (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await batch.commit(noResult: true);
    await _createIndexes(db);
    await _seedDefaultData(db);
  }

  Future<void> _createIndexes(Database db) async {
    // Índices para consultas frecuentes
    await db.execute(
        'CREATE INDEX idx_transactions_date ON ${TableNames.transactions}(date)');
    await db.execute(
        'CREATE INDEX idx_transactions_type ON ${TableNames.transactions}(type)');
    await db.execute(
        'CREATE INDEX idx_transactions_category ON ${TableNames.transactions}(category_id)');
    await db.execute(
        'CREATE INDEX idx_transactions_account ON ${TableNames.transactions}(account_id)');
    await db.execute(
        'CREATE INDEX idx_transactions_person ON ${TableNames.transactions}(person_id)');
    await db.execute(
        'CREATE INDEX idx_recurring_active ON ${TableNames.recurringTransactions}(is_active)');
    await db.execute(
        'CREATE INDEX idx_budgets_category ON ${TableNames.budgets}(category_id)');
    await db.execute(
        'CREATE INDEX idx_savings_goal ON ${TableNames.savingsMovements}(savings_goal_id)');
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    // Mejoras de migraciones futuras van aquí.
  }

  /// Datos base: categorías y subcategorías por defecto.
  Future<void> _seedDefaultData(Database db) async {
    final now = DateTime.now().toIso8601String();

    final batch = db.batch();
    for (var c in DefaultCategories.categories) {
      batch.insert(TableNames.categories, {
        'name': c.name,
        'icon': c.icon,
        'is_default': 1,
        'is_income': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}