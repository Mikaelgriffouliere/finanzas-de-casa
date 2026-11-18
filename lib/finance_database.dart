import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'legacy_database_migration_stub.dart'
    if (dart.library.io) 'legacy_database_migration_io.dart';
import 'web_database_factory_stub.dart'
    if (dart.library.js_interop) 'web_database_factory_web.dart';

/// Aporte individual de un integrante dentro de un movimiento compartido.
class FinanceShare {
  const FinanceShare({required this.memberId, required this.amount});

  final int memberId;
  final double amount;

  factory FinanceShare.fromMap(Map<String, Object?> map) => FinanceShare(
    memberId: (map['member_id'] as num?)?.toInt() ?? 0,
    amount: (map['amount'] as num?)?.toDouble() ?? 0,
  );
}

class FinanceEntry {
  const FinanceEntry({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.isIncome,
    this.memberId,
    this.isShared = false,
    List<FinanceShare>? shares,
  }) : shares = shares ?? const <FinanceShare>[];

  final int? id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final bool isIncome;
  final int? memberId;

  /// Cada integrante aporta un monto propio (no necesariamente igual).
  final bool isShared;
  final List<FinanceShare> shares;

  /// Ids de los integrantes que participan del reparto.
  List<int> get sharedMemberIds =>
      shares.map((share) => share.memberId).toList(growable: false);

  FinanceEntry copyWith({bool? isShared, List<FinanceShare>? shares}) =>
      FinanceEntry(
        id: id,
        title: title,
        amount: amount,
        category: category,
        date: date,
        isIncome: isIncome,
        memberId: memberId,
        isShared: isShared ?? this.isShared,
        shares: shares ?? this.shares,
      );

  Map<String, Object?> toMap() => {
    'title': title,
    'amount': amount,
    'category': category,
    'date': date.toIso8601String(),
    'is_income': isIncome ? 1 : 0,
    'member_id': memberId,
    'is_shared': isShared ? 1 : 0,
  };

  factory FinanceEntry.fromMap(Map<String, Object?> map) {
    final rawDate = map['date'] as String?;
    return FinanceEntry(
      id: (map['id'] as num?)?.toInt(),
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      category: map['category'] as String? ?? 'Otros',
      date: DateTime.tryParse(rawDate ?? '') ?? DateTime.now(),
      isIncome: (map['is_income'] as num?)?.toInt() == 1,
      memberId: (map['member_id'] as num?)?.toInt(),
      isShared: (map['is_shared'] as num?)?.toInt() == 1,
    );
  }
}

class FinanceMember {
  const FinanceMember({this.id, required this.name, required this.color});

  final int? id;
  final String name;
  final int color;

  Map<String, Object?> toMap() => {'name': name, 'color': color};

  factory FinanceMember.fromMap(Map<String, Object?> map) => FinanceMember(
    id: (map['id'] as num?)?.toInt(),
    name: map['name'] as String? ?? '',
    color: (map['color'] as num?)?.toInt() ?? 0xFF155C4B,
  );
}

class FinanceCategory {
  const FinanceCategory({
    this.id,
    required this.name,
    required this.isIncome,
    required this.icon,
    required this.color,
  });

  final int? id;
  final String name;
  final bool isIncome;

  /// Clave de ícono definida en `category_visuals.dart`.
  final String icon;

  /// Color ARGB de la categoría.
  final int color;

  Map<String, Object?> toMap() => {
    'name': name,
    'is_income': isIncome ? 1 : 0,
    'icon': icon,
    'color': color,
  };

  factory FinanceCategory.fromMap(Map<String, Object?> map) => FinanceCategory(
    id: (map['id'] as num?)?.toInt(),
    name: map['name'] as String? ?? '',
    isIncome: (map['is_income'] as num?)?.toInt() == 1,
    icon: map['icon'] as String? ?? 'otros',
    color: (map['color'] as num?)?.toInt() ?? 0xFF62736A,
  );
}

class DuplicateCategoryException implements Exception {
  const DuplicateCategoryException(this.name);

  final String name;

  String get message => 'Ya existe una categoría "$name" para este tipo.';

  @override
  String toString() => message;
}

class DuplicateMemberException implements Exception {
  const DuplicateMemberException(this.name);

  final String name;

  String get message => 'Ya existe un integrante "$name".';

  @override
  String toString() => message;
}

class FinanceDatabase {
  FinanceDatabase._();

  static final instance = FinanceDatabase._();
  static const _databaseName = 'nido_finanzas.db';
  static const _databaseVersion = 6;

  static const defaultCategories = <FinanceCategory>[
    FinanceCategory(
      name: 'Comida',
      isIncome: false,
      icon: 'comida',
      color: 0xFFCC6E3D,
    ),
    FinanceCategory(
      name: 'Transporte',
      isIncome: false,
      icon: 'transporte',
      color: 0xFF4F78A1,
    ),
    FinanceCategory(
      name: 'Hogar',
      isIncome: false,
      icon: 'hogar',
      color: 0xFF8A6C9D,
    ),
    FinanceCategory(
      name: 'Salud',
      isIncome: false,
      icon: 'salud',
      color: 0xFFC85F67,
    ),
    FinanceCategory(
      name: 'Ocio',
      isIncome: false,
      icon: 'ocio',
      color: 0xFFB38723,
    ),
    FinanceCategory(
      name: 'Tarjeta de crédito',
      isIncome: false,
      icon: 'tarjeta',
      color: 0xFF5B6F9E,
    ),
    FinanceCategory(
      name: 'Otros',
      isIncome: false,
      icon: 'otros',
      color: 0xFF62736A,
    ),
    FinanceCategory(
      name: 'Sueldo',
      isIncome: true,
      icon: 'sueldo',
      color: 0xFF155C4B,
    ),
    FinanceCategory(
      name: 'Extra',
      isIncome: true,
      icon: 'extra',
      color: 0xFF2E7D5B,
    ),
    FinanceCategory(
      name: 'Inversiones',
      isIncome: true,
      icon: 'inversiones',
      color: 0xFF4F78A1,
    ),
    FinanceCategory(
      name: 'Otros',
      isIncome: true,
      icon: 'otros',
      color: 0xFF62736A,
    ),
  ];

  Database? _database;
  Future<Database>? _opening;
  DatabaseFactory? _factory;

  /// Fuerza el uso de SQLite por FFI (escritorio y tests).
  ///
  /// En tests de widgets conviene [noIsolate] porque el binding de pruebas no
  /// procesa los mensajes de un isolate en segundo plano.
  static void initializeFfi({bool noIsolate = false}) {
    sqfliteFfiInit();
    instance._factory = noIsolate
        ? databaseFactoryFfiNoIsolate
        : databaseFactoryFfi;
  }

  Future<Database> get database async {
    final open = _database;
    if (open != null) return open;
    final opening = _opening ??= _open();
    try {
      return await opening;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final factory = _factory ??= _createFactory();
    final database = await factory.openDatabase(
      await _databasePath(factory),
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: (db, version) async {
          await _createTransactionsTable(db);
          await _createSplitsTable(db);
          await _createCategoriesTable(db);
          await _createMembersTable(db);
          await _seedDefaultCategories(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createCategoriesTable(db);
            await _seedDefaultCategories(db);
          }
          if (oldVersion < 3) {
            await _createMembersTable(db);
            await _addMemberColumn(db);
          }
          if (oldVersion < 4) {
            await _addSharedColumn(db);
            await _createSplitsTable(db);
          }
          if (oldVersion < 5) {
            // ConflictAlgorithm.ignore: agrega las categorías nuevas sin
            // modificar las que el usuario ya tiene.
            await _seedDefaultCategories(db);
          }
          if (oldVersion < 6) {
            await _addSplitAmountColumn(db);
          }
        },
      ),
    );
    _database = database;
    return database;
  }

  static Future<void> _createTransactionsTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      amount REAL NOT NULL,
      category TEXT NOT NULL,
      date TEXT NOT NULL,
      is_income INTEGER NOT NULL,
      member_id INTEGER
    )
  ''');

  static Future<void> _createSplitsTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS transaction_splits (
      transaction_id INTEGER NOT NULL,
      member_id INTEGER NOT NULL,
      amount REAL NOT NULL DEFAULT 0,
      PRIMARY KEY (transaction_id, member_id)
    )
  ''');

  /// Agrega `amount` a bases creadas antes de la versión 6. Los repartos
  /// existentes se convierten en partes iguales para no perder información.
  static Future<void> _addSplitAmountColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(transaction_splits)');
    if (columns.any((column) => column['name'] == 'amount')) return;
    await db.execute(
      'ALTER TABLE transaction_splits ADD COLUMN amount REAL NOT NULL DEFAULT 0',
    );
    final rows = await db.query('transaction_splits');
    final counts = <int, int>{};
    for (final row in rows) {
      final id = (row['transaction_id'] as num?)?.toInt();
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    for (final row in rows) {
      final transactionId = (row['transaction_id'] as num?)?.toInt();
      final memberId = (row['member_id'] as num?)?.toInt();
      if (transactionId == null || memberId == null) continue;
      final transactions = await db.query(
        'transactions',
        columns: ['amount'],
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      if (transactions.isEmpty) continue;
      final total = (transactions.first['amount'] as num?)?.toDouble() ?? 0;
      await db.update(
        'transaction_splits',
        {'amount': total / (counts[transactionId] ?? 1)},
        where: 'transaction_id = ? AND member_id = ?',
        whereArgs: [transactionId, memberId],
      );
    }
  }

  /// Agrega `is_shared` a bases creadas antes de la versión 4.
  static Future<void> _addSharedColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(transactions)');
    final hasShared = columns.any((column) => column['name'] == 'is_shared');
    if (hasShared) return;
    await db.execute(
      'ALTER TABLE transactions ADD COLUMN is_shared INTEGER NOT NULL DEFAULT 0',
    );
  }

  static Future<void> _createMembersTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS members (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL COLLATE NOCASE,
      color INTEGER NOT NULL,
      UNIQUE(name)
    )
  ''');

  /// Agrega `member_id` a bases creadas antes de la versión 3.
  static Future<void> _addMemberColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(transactions)');
    final hasMemberId = columns.any((column) => column['name'] == 'member_id');
    if (hasMemberId) return;
    await db.execute('ALTER TABLE transactions ADD COLUMN member_id INTEGER');
  }

  static Future<void> _createCategoriesTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL COLLATE NOCASE,
      is_income INTEGER NOT NULL,
      icon TEXT NOT NULL,
      color INTEGER NOT NULL,
      UNIQUE(name, is_income)
    )
  ''');

  static Future<void> _seedDefaultCategories(Database db) async {
    for (final category in defaultCategories) {
      await db.insert(
        'categories',
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<String> _databasePath(DatabaseFactory factory) async {
    // En escritorio no se usa la carpeta de trabajo: así los datos no se
    // pierden al ejecutar la app desde otro directorio ni al hacer
    // `flutter clean`.
    if (!kIsWeb && _isDesktop) {
      final supportDirectory = await getApplicationSupportDirectory();
      final databasePath = path.join(supportDirectory.path, _databaseName);
      await migrateLegacyDatabase(databasePath);
      return databasePath;
    }
    final databasesPath = await factory.getDatabasesPath();
    return path.join(databasesPath, _databaseName);
  }

  static bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS;

  DatabaseFactory _createFactory() {
    if (kIsWeb) {
      return createWebDatabaseFactory();
    }
    if (_isDesktop) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return sqflite.databaseFactorySqflitePlugin;
  }

  Future<List<FinanceEntry>> getEntries() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'date DESC, id DESC');
    final splitRows = await db.query('transaction_splits');
    final participants = <int, List<FinanceShare>>{};
    for (final row in splitRows) {
      final transactionId = (row['transaction_id'] as num?)?.toInt();
      final memberId = (row['member_id'] as num?)?.toInt();
      if (transactionId == null || memberId == null) continue;
      participants
          .putIfAbsent(transactionId, () => [])
          .add(FinanceShare.fromMap(row));
    }
    return rows.map((row) {
      final entry = FinanceEntry.fromMap(row);
      final shares = participants[entry.id];
      if (shares == null || shares.isEmpty) return entry;
      return entry.copyWith(isShared: true, shares: shares);
    }).toList();
  }

  Future<int> insertEntry(FinanceEntry entry) async {
    final db = await database;
    final id = await db.insert('transactions', entry.toMap());
    await _replaceSplits(db, id, entry);
    return id;
  }

  Future<int> updateEntry(FinanceEntry entry) async {
    final id = entry.id;
    if (id == null) {
      throw ArgumentError('El movimiento a editar necesita un id.');
    }
    final db = await database;
    final count = await db.update(
      'transactions',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    await _replaceSplits(db, id, entry);
    return count;
  }

  Future<void> _replaceSplits(
    Database db,
    int transactionId,
    FinanceEntry entry,
  ) async {
    await db.delete(
      'transaction_splits',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
    if (!entry.isShared) return;
    final seen = <int>{};
    for (final share in entry.shares) {
      if (!seen.add(share.memberId)) continue;
      await db.insert('transaction_splits', {
        'transaction_id': transactionId,
        'member_id': share.memberId,
        'amount': share.amount,
      });
    }
  }

  Future<int> deleteEntry(int id) async {
    final db = await database;
    final count = await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count > 0) {
      await db.delete(
        'transaction_splits',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
    }
    return count;
  }

  Future<List<FinanceCategory>> getCategories({bool? isIncome}) async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: isIncome == null ? null : 'is_income = ?',
      whereArgs: isIncome == null ? null : [isIncome ? 1 : 0],
      orderBy: 'is_income, name COLLATE NOCASE',
    );
    return rows.map(FinanceCategory.fromMap).toList();
  }

  Future<FinanceCategory> insertCategory(FinanceCategory category) async {
    final db = await database;
    final name = category.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('El nombre de la categoría no puede estar vacío.');
    }
    final cleaned = FinanceCategory(
      name: name,
      isIncome: category.isIncome,
      icon: category.icon,
      color: category.color,
    );
    try {
      final id = await db.insert('categories', cleaned.toMap());
      return FinanceCategory(
        id: id,
        name: cleaned.name,
        isIncome: cleaned.isIncome,
        icon: cleaned.icon,
        color: cleaned.color,
      );
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw DuplicateCategoryException(name);
      }
      rethrow;
    }
  }

  /// Devuelve `false` cuando la categoría está en uso y no se puede eliminar.
  Future<bool> deleteCategory(FinanceCategory category) async {
    final id = category.id;
    if (id == null) return false;
    final db = await database;
    final usage = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM transactions
      WHERE category = ? COLLATE NOCASE AND is_income = ?
      ''',
      [category.name, category.isIncome ? 1 : 0],
    );
    final total = (usage.first['total'] as num?)?.toInt() ?? 0;
    if (total > 0) return false;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    return true;
  }

  Future<List<FinanceMember>> getMembers() async {
    final db = await database;
    final rows = await db.query('members', orderBy: 'name COLLATE NOCASE');
    return rows.map(FinanceMember.fromMap).toList();
  }

  Future<FinanceMember> insertMember(FinanceMember member) async {
    final db = await database;
    final name = member.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('El nombre del integrante no puede estar vacío.');
    }
    try {
      final id = await db.insert('members', {
        'name': name,
        'color': member.color,
      });
      return FinanceMember(id: id, name: name, color: member.color);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw DuplicateMemberException(name);
      }
      rethrow;
    }
  }

  /// Devuelve `false` cuando el integrante tiene movimientos asociados.
  Future<bool> deleteMember(FinanceMember member) async {
    final id = member.id;
    if (id == null) return false;
    final db = await database;
    final usage = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM transactions WHERE member_id = ?',
      [id],
    );
    final shared = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM transaction_splits WHERE member_id = ?',
      [id],
    );
    final total = (usage.first['total'] as num?)?.toInt() ?? 0;
    final sharedTotal = (shared.first['total'] as num?)?.toInt() ?? 0;
    if (total > 0 || sharedTotal > 0) return false;
    await db.delete('members', where: 'id = ?', whereArgs: [id]);
    return true;
  }

  /// Cierra la conexión (útil en tests y al reiniciar la app).
  Future<void> close() async {
    final db = _database;
    _database = null;
    _opening = null;
    await db?.close();
  }
}
