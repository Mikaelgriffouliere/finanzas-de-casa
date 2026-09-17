import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/savings_goal.dart';
import '../../../domain/entities/savings_goal_status.dart';
import '../../../domain/entities/savings_movement.dart';
import '../../../domain/repositories/savings_repository.dart';
import '../database/app_database.dart';

class SavingsGoalRepositoryImpl implements SavingsGoalRepository {
  final AppDatabase _db = AppDatabase.instance;

  @override
  Future<List<SavingsGoal>> getAll({bool onlyActive = false}) async {
    final db = await _db.getDatabase();
    final where = onlyActive ? "status = 'active'" : null;
    final result = await db.query(
      TableNames.savingsGoals,
      where: where,
      orderBy: 'priority, name',
    );
    return result.map(_fromRow).toList();
  }

  @override
  Future<SavingsGoal?> getById(int id) async {
    final db = await _db.getDatabase();
    final result = await db.query(
      TableNames.savingsGoals,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : _fromRow(result.first);
  }

  @override
  Future<SavingsGoal> create(SavingsGoal goal) async {
    final db = await _db.getDatabase();
    final id = await db.insert(TableNames.savingsGoals, _toRow(goal));
    return goal.copyWith(id: id, createdAt: DateTime.now());
  }

  @override
  Future<SavingsGoal> update(SavingsGoal goal) async {
    final db = await _db.getDatabase();
    final row = _toRow(goal);
    row['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      TableNames.savingsGoals,
      row,
      where: 'id = ?',
      whereArgs: [goal.id],
    );
    return goal.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<void> delete(int id) async {
    final db = await _db.getDatabase();
    await db.delete(TableNames.savingsGoals, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<SavingsMovement>> getMovements(int goalId) async {
    final db = await _db.getDatabase();
    final result = await db.query(
      TableNames.savingsMovements,
      where: 'savings_goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'date DESC',
    );
    return result.map(_fromMovementRow).toList();
  }

  @override
  Future<SavingsMovement> addMovement(SavingsMovement movement) async {
    final db = await _db.getDatabase();
    return await db.transaction((txn) async {
      final id = await txn.insert(
        TableNames.savingsMovements,
        _toMovementRow(movement),
      );

      final goalRows = await txn.query(
        TableNames.savingsGoals,
        where: 'id = ?',
        whereArgs: [movement.savingsGoalId],
        limit: 1,
      );
      if (goalRows.isEmpty) {
        return movement.copyWith(id: id, createdAt: DateTime.now());
      }

      final currentAmount = goalRows.first['current_amount'] as int;
      final targetAmount = goalRows.first['target_amount'] as int;
      final newAmount = movement.isDeposit
          ? currentAmount + movement.amount
          : currentAmount - movement.amount;

      final goalUpdate = <String, dynamic>{
        'current_amount': newAmount,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (newAmount >= targetAmount) {
        goalUpdate['status'] = SavingsGoalStatus.completed.name;
      }

      await txn.update(
        TableNames.savingsGoals,
        goalUpdate,
        where: 'id = ?',
        whereArgs: [movement.savingsGoalId],
      );

      return movement.copyWith(id: id, createdAt: DateTime.now());
    });
  }

  @override
  Future<void> deleteMovement(int movementId) async {
    final db = await _db.getDatabase();
    await db.delete(
      TableNames.savingsMovements,
      where: 'id = ?',
      whereArgs: [movementId],
    );
  }

  Map<String, dynamic> _toRow(SavingsGoal g) {
    return {
      'name': g.name,
      'description': g.description,
      'target_amount': g.targetAmount,
      'current_amount': g.currentAmount,
      'target_date': g.targetDate?.millisecondsSinceEpoch,
      'priority': g.priority,
      'status': g.status.name,
      'created_at': g.createdAt?.toIso8601String(),
      'updated_at': g.updatedAt?.toIso8601String(),
    };
  }

  SavingsGoal _fromRow(Map<String, dynamic> row) {
    return SavingsGoal(
      id: row['id'] as int,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      targetAmount: row['target_amount'] as int,
      currentAmount: row['current_amount'] as int,
      targetDate: row['target_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['target_date'] as int)
          : null,
      priority: row['priority'] as int,
      status: SavingsGoalStatusX.fromName(row['status'] as String),
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'])
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> _toMovementRow(SavingsMovement m) {
    return {
      'savings_goal_id': m.savingsGoalId,
      'amount': m.amount,
      'is_deposit': m.isDeposit ? 1 : 0,
      'date': m.date.millisecondsSinceEpoch,
      'description': m.description,
      'account_id': m.accountId,
      'created_at': m.createdAt?.toIso8601String(),
      'updated_at': m.updatedAt?.toIso8601String(),
    };
  }

  SavingsMovement _fromMovementRow(Map<String, dynamic> row) {
    return SavingsMovement(
      id: row['id'] as int,
      savingsGoalId: row['savings_goal_id'] as int,
      amount: row['amount'] as int,
      isDeposit: (row['is_deposit'] as int) == 1,
      date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
      description: row['description'] as String? ?? '',
      accountId: row['account_id'] as int?,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'])
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'])
          : null,
    );
  }
}
