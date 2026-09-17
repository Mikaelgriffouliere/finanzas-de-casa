import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/expense_kind.dart';
import '../../../domain/entities/recurring_frequency.dart';
import '../../../domain/entities/recurring_transaction.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../../domain/repositories/recurring_repository.dart';
import '../database/app_database.dart';
import 'transaction_repository_impl.dart';

class RecurringTransactionRepositoryImpl
    implements RecurringTransactionRepository {
  final AppDatabase _db = AppDatabase.instance;

  @override
  Future<List<RecurringTransaction>> getAll({bool onlyActive = false}) async {
    final db = await _db.getDatabase();
    final where = onlyActive ? 'is_active = 1' : null;
    final result = await db.query(
      TableNames.recurringTransactions,
      where: where,
      orderBy: 'name',
    );
    return result.map(_fromRow).toList();
  }

  @override
  Future<RecurringTransaction?> getById(int id) async {
    final db = await _db.getDatabase();
    final result = await db.query(
      TableNames.recurringTransactions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : _fromRow(result.first);
  }

  @override
  Future<RecurringTransaction> create(RecurringTransaction recurring) async {
    final db = await _db.getDatabase();
    final id = await db.insert(
      TableNames.recurringTransactions,
      _toRow(recurring),
    );
    return recurring.copyWith(id: id, createdAt: DateTime.now());
  }

  @override
  Future<RecurringTransaction> update(RecurringTransaction recurring) async {
    final db = await _db.getDatabase();
    final row = _toRow(recurring);
    row['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      TableNames.recurringTransactions,
      row,
      where: 'id = ?',
      whereArgs: [recurring.id],
    );
    return recurring.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<void> delete(int id) async {
    final db = await _db.getDatabase();
    await db.delete(
      TableNames.recurringTransactions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Transaction>> generateDueTransactions(DateTime upTo) async {
    final db = await _db.getDatabase();
    final generated = <Transaction>[];
    final txRepo = TransactionRepositoryImpl();

    final recurringRows = await db.query(
      TableNames.recurringTransactions,
      where: 'is_active = 1',
    );

    for (final row in recurringRows) {
      final rt = _fromRow(row);
      final dueDate = _currentPeriodDueDate(rt);

      if (dueDate.isAfter(upTo)) continue;
      if (rt.endDate != null && dueDate.isAfter(rt.endDate!)) continue;
      if (dueDate.isBefore(rt.startDate)) continue;

      final periodStart = _periodStart(rt.frequency, dueDate);
      final periodEnd = _periodEnd(rt.frequency, dueDate);

      final existing = await db.query(
        TableNames.transactions,
        where:
            'is_recurring = 1 AND account_id = ? AND amount = ? '
            'AND date >= ? AND date <= ?',
        whereArgs: [
          rt.accountId,
          rt.amount,
          periodStart.millisecondsSinceEpoch,
          periodEnd.millisecondsSinceEpoch,
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final transaction = Transaction(
          type:
              rt.isIncome ? TransactionType.income : TransactionType.expense,
          amount: rt.amount,
          date: dueDate,
          categoryId: rt.categoryId,
          personId: rt.personId,
          accountId: rt.accountId,
          description: rt.name,
          notes: rt.description,
          isRecurring: true,
        );
        final created = await txRepo.create(transaction);
        generated.add(created);
      }
    }

    return generated;
  }

  DateTime _currentPeriodDueDate(RecurringTransaction rt) {
    final now = DateTime.now();
    switch (rt.frequency) {
      case RecurringFrequency.weekly:
        final diff = rt.dueDay - now.weekday;
        return DateTime(now.year, now.month, now.day + diff);
      case RecurringFrequency.fortnightly:
        final daysSinceStart = now.difference(rt.startDate).inDays;
        final periodIndex = daysSinceStart ~/ 14;
        return rt.startDate.add(Duration(days: periodIndex * 14));
      case RecurringFrequency.monthly:
        return DateTime(now.year, now.month, rt.dueDay);
      case RecurringFrequency.yearly:
        return DateTime(now.year, rt.startDate.month, rt.dueDay);
    }
  }

  DateTime _periodStart(RecurringFrequency frequency, DateTime date) {
    switch (frequency) {
      case RecurringFrequency.weekly:
        return date.subtract(Duration(days: date.weekday - 1));
      case RecurringFrequency.fortnightly:
        final daysSinceStart = date.difference(DateTime(2000)).inDays;
        final periodIndex = daysSinceStart ~/ 14;
        return DateTime(2000).add(Duration(days: periodIndex * 14));
      case RecurringFrequency.monthly:
        return DateTime(date.year, date.month, 1);
      case RecurringFrequency.yearly:
        return DateTime(date.year, 1, 1);
    }
  }

  DateTime _periodEnd(RecurringFrequency frequency, DateTime date) {
    switch (frequency) {
      case RecurringFrequency.weekly:
        return date.add(Duration(days: 7 - date.weekday, hours: 23, minutes: 59, seconds: 59));
      case RecurringFrequency.fortnightly:
        return _periodStart(frequency, date).add(
          const Duration(days: 13, hours: 23, minutes: 59, seconds: 59),
        );
      case RecurringFrequency.monthly:
        return DateTime(date.year, date.month + 1, 0, 23, 59, 59);
      case RecurringFrequency.yearly:
        return DateTime(date.year, 12, 31, 23, 59, 59);
    }
  }

  Map<String, dynamic> _toRow(RecurringTransaction rt) {
    return {
      'name': rt.name,
      'amount': rt.amount,
      'is_income': rt.isIncome ? 1 : 0,
      'category_id': rt.categoryId,
      'account_id': rt.accountId,
      'person_id': rt.personId,
      'frequency': rt.frequency.name,
      'due_day': rt.dueDay,
      'start_date': rt.startDate.millisecondsSinceEpoch,
      'end_date': rt.endDate?.millisecondsSinceEpoch,
      'is_active': rt.isActive ? 1 : 0,
      'kind': rt.kind.name,
      'description': rt.description,
      'created_at': rt.createdAt?.toIso8601String(),
      'updated_at': rt.updatedAt?.toIso8601String(),
    };
  }

  RecurringTransaction _fromRow(Map<String, dynamic> row) {
    return RecurringTransaction(
      id: row['id'] as int,
      name: row['name'] as String,
      amount: row['amount'] as int,
      isIncome: (row['is_income'] as int) == 1,
      categoryId: row['category_id'] as int?,
      accountId: row['account_id'] as int?,
      personId: row['person_id'] as int?,
      frequency: RecurringFrequencyX.fromName(row['frequency'] as String),
      dueDay: row['due_day'] as int,
      startDate: DateTime.fromMillisecondsSinceEpoch(row['start_date'] as int),
      endDate: row['end_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['end_date'] as int)
          : null,
      isActive: (row['is_active'] as int) == 1,
      kind: ExpenseKindX.fromName(row['kind'] as String),
      description: row['description'] as String? ?? '',
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'])
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'])
          : null,
    );
  }
}
