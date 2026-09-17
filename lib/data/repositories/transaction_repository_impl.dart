import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../database/app_database.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final AppDatabase _db = AppDatabase.instance;

  @override
  Future<List<Transaction>> getAll({TransactionFilter? filter}) async {
    final db = await _db.getDatabase();
    final args = <dynamic>[];
    final where = _buildFilterWhere(filter, args);
    final result = await db.query(
      TableNames.transactions,
      where: where.isEmpty ? null : where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC',
    );
    return result.map(_fromRow).toList();
  }

  @override
  Future<Transaction?> getById(int id) async {
    final db = await _db.getDatabase();
    final result = await db.query(
      TableNames.transactions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : _fromRow(result.first);
  }

  @override
  Future<Transaction> create(Transaction transaction) async {
    final db = await _db.getDatabase();
    final id = await db.insert(TableNames.transactions, _toRow(transaction));
    return transaction.copyWith(id: id, createdAt: DateTime.now());
  }

  @override
  Future<Transaction> update(Transaction transaction) async {
    final db = await _db.getDatabase();
    final row = _toRow(transaction);
    row['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      TableNames.transactions,
      row,
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
    return transaction.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<void> delete(int id) async {
    final db = await _db.getDatabase();
    await db.delete(TableNames.transactions, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Transaction> createTransfer(Transaction transfer) async {
    final db = await _db.getDatabase();
    return await db.transaction((txn) async {
      final id = await txn.insert(TableNames.transactions, _toRow(transfer));
      await txn.rawUpdate(
        'UPDATE ${TableNames.accounts} SET initial_balance = initial_balance - ? WHERE id = ?',
        [transfer.amount, transfer.accountId],
      );
      await txn.rawUpdate(
        'UPDATE ${TableNames.accounts} SET initial_balance = initial_balance + ? WHERE id = ?',
        [transfer.amount, transfer.transferAccountId],
      );
      return transfer.copyWith(id: id, createdAt: DateTime.now());
    });
  }

  @override
  Future<int> sumByType({
    required TransactionType type,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.getDatabase();
    final args = <dynamic>[type.name];
    var where = 'type = ?';
    if (from != null) {
      where += ' AND date >= ?';
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where += ' AND date <= ?';
      args.add(to.millisecondsSinceEpoch);
    }
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM ${TableNames.transactions} WHERE $where',
      args,
    );
    return (result.first['total'] as int?) ?? 0;
  }

  @override
  Future<Map<int, int>> sumByCategory({
    required TransactionType type,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.getDatabase();
    final args = <dynamic>[type.name];
    var where = 'type = ? AND category_id IS NOT NULL';
    if (from != null) {
      where += ' AND date >= ?';
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where += ' AND date <= ?';
      args.add(to.millisecondsSinceEpoch);
    }
    final result = await db.rawQuery(
      'SELECT category_id, SUM(amount) as total FROM ${TableNames.transactions} WHERE $where GROUP BY category_id',
      args,
    );
    return {
      for (final row in result)
        row['category_id'] as int: row['total'] as int,
    };
  }

  @override
  Future<Map<int, int>> sumByPerson({
    required TransactionType type,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.getDatabase();
    final args = <dynamic>[type.name];
    var where = 'type = ? AND person_id IS NOT NULL';
    if (from != null) {
      where += ' AND date >= ?';
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where += ' AND date <= ?';
      args.add(to.millisecondsSinceEpoch);
    }
    final result = await db.rawQuery(
      'SELECT person_id, SUM(amount) as total FROM ${TableNames.transactions} WHERE $where GROUP BY person_id',
      args,
    );
    return {
      for (final row in result)
        row['person_id'] as int: row['total'] as int,
    };
  }

  @override
  Future<Map<String, int>> sumByMonth({
    required TransactionType type,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.getDatabase();
    final args = <dynamic>[type.name];
    var where = 'type = ?';
    if (from != null) {
      where += ' AND date >= ?';
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where += ' AND date <= ?';
      args.add(to.millisecondsSinceEpoch);
    }
    final result = await db.rawQuery(
      '''
      SELECT strftime('%Y-%m', date / 1000, 'unixepoch') as month,
             SUM(amount) as total
      FROM ${TableNames.transactions}
      WHERE $where
      GROUP BY month
      ORDER BY month
      ''',
      args,
    );
    return {
      for (final row in result)
        row['month'] as String: row['total'] as int,
    };
  }

  String _buildFilterWhere(TransactionFilter? filter, List<dynamic> args) {
    if (filter == null) return '';
    final conditions = <String>[];

    if (filter.from != null) {
      conditions.add('date >= ?');
      args.add(filter.from!.millisecondsSinceEpoch);
    }
    if (filter.to != null) {
      conditions.add('date <= ?');
      args.add(filter.to!.millisecondsSinceEpoch);
    }
    if (filter.personId != null) {
      conditions.add('person_id = ?');
      args.add(filter.personId);
    }
    if (filter.categoryId != null) {
      conditions.add('category_id = ?');
      args.add(filter.categoryId);
    }
    if (filter.accountId != null) {
      conditions.add('account_id = ?');
      args.add(filter.accountId);
    }
    if (filter.type != null) {
      conditions.add('type = ?');
      args.add(filter.type!.name);
    }
    if (filter.minAmount != null) {
      conditions.add('amount >= ?');
      args.add(filter.minAmount);
    }
    if (filter.maxAmount != null) {
      conditions.add('amount <= ?');
      args.add(filter.maxAmount);
    }
    if (filter.searchText != null && filter.searchText!.isNotEmpty) {
      conditions.add('(description LIKE ? OR notes LIKE ?)');
      final search = '%${filter.searchText}%';
      args.add(search);
      args.add(search);
    }

    return conditions.isEmpty ? '' : conditions.join(' AND ');
  }

  Map<String, dynamic> _toRow(Transaction t) {
    return {
      'type': t.type.name,
      'amount': t.amount,
      'date': t.date.millisecondsSinceEpoch,
      'category_id': t.categoryId,
      'subcategory_id': t.subcategoryId,
      'person_id': t.personId,
      'account_id': t.accountId,
      'transfer_account_id': t.transferAccountId,
      'description': t.description,
      'notes': t.notes,
      'is_recurring': t.isRecurring ? 1 : 0,
      'created_at': t.createdAt?.toIso8601String(),
      'updated_at': t.updatedAt?.toIso8601String(),
    };
  }

  Transaction _fromRow(Map<String, dynamic> row) {
    return Transaction(
      id: row['id'] as int,
      type: TransactionTypeX.fromName(row['type'] as String),
      amount: row['amount'] as int,
      date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
      categoryId: row['category_id'] as int?,
      subcategoryId: row['subcategory_id'] as int?,
      personId: row['person_id'] as int?,
      accountId: row['account_id'] as int?,
      transferAccountId: row['transfer_account_id'] as int?,
      description: row['description'] as String? ?? '',
      notes: row['notes'] as String? ?? '',
      isRecurring: (row['is_recurring'] as int) == 1,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'])
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'])
          : null,
    );
  }
}
