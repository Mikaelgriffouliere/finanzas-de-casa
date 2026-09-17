import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/budget.dart';
import '../../../domain/repositories/budget_repository.dart';
import '../database/app_database.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final AppDatabase _db = AppDatabase.instance;

  @override
  Future<List<Budget>> getAll({bool onlyActive = false}) async {
    final db = await _db.getDatabase();
    final where = onlyActive ? 'is_active = 1' : null;
    final result = await db.query(
      TableNames.budgets,
      where: where,
      orderBy: 'created_at DESC',
    );
    return result.map(_fromRow).toList();
  }

  @override
  Future<Budget?> getById(int id) async {
    final db = await _db.getDatabase();
    final result = await db.query(
      TableNames.budgets,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : _fromRow(result.first);
  }

  @override
  Future<Budget?> getByCategory(int categoryId) async {
    final db = await _db.getDatabase();
    final result = await db.query(
      TableNames.budgets,
      where: 'category_id = ? AND is_active = 1',
      whereArgs: [categoryId],
      limit: 1,
    );
    return result.isEmpty ? null : _fromRow(result.first);
  }

  @override
  Future<Budget> create(Budget budget) async {
    final db = await _db.getDatabase();
    final id = await db.insert(TableNames.budgets, _toRow(budget));
    return budget.copyWith(id: id, createdAt: DateTime.now());
  }

  @override
  Future<Budget> update(Budget budget) async {
    final db = await _db.getDatabase();
    final row = _toRow(budget);
    row['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      TableNames.budgets,
      row,
      where: 'id = ?',
      whereArgs: [budget.id],
    );
    return budget.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<void> delete(int id) async {
    final db = await _db.getDatabase();
    await db.delete(TableNames.budgets, where: 'id = ?', whereArgs: [id]);
  }

  Map<String, dynamic> _toRow(Budget b) {
    return {
      'category_id': b.categoryId,
      'amount': b.amount,
      'start_date': b.startDate.millisecondsSinceEpoch,
      'end_date': b.endDate?.millisecondsSinceEpoch,
      'is_active': b.isActive ? 1 : 0,
      'created_at': b.createdAt?.toIso8601String(),
      'updated_at': b.updatedAt?.toIso8601String(),
    };
  }

  Budget _fromRow(Map<String, dynamic> row) {
    return Budget(
      id: row['id'] as int,
      categoryId: row['category_id'] as int,
      amount: row['amount'] as int,
      startDate: DateTime.fromMillisecondsSinceEpoch(row['start_date'] as int),
      endDate: row['end_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['end_date'] as int)
          : null,
      isActive: (row['is_active'] as int) == 1,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'])
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'])
          : null,
    );
  }
}
