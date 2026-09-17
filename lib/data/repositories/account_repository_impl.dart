import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/account_type.dart';
import '../../../domain/entities/currency.dart';
import '../../../domain/repositories/account_repository.dart';
import '../database/app_database.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AppDatabase _db = AppDatabase.instance;

  @override
  Future<List<Account>> getAll({bool onlyActive = false}) async {
    final db = await _db.getDatabase();
    final where = onlyActive ? 'is_active = 1' : null;
    final result = await db.query(TableNames.accounts, where: where, orderBy: 'name');
    return result.map(_fromRow).toList();
  }

  @override
  Future<Account?> getById(int id) async {
    final db = await _db.getDatabase();
    final result = await db.query(
      TableNames.accounts,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : _fromRow(result.first);
  }

  @override
  Future<Account> create(Account account) async {
    final db = await _db.getDatabase();
    final id = await db.insert(TableNames.accounts, _toRow(account));
    return account.copyWith(id: id, createdAt: DateTime.now());
  }

  @override
  Future<Account> update(Account account) async {
    final db = await _db.getDatabase();
    final row = _toRow(account);
    row['updated_at'] = DateTime.now().toIso8601String();
    await db.update(TableNames.accounts, row, where: 'id = ?', whereArgs: [account.id]);
    return account.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<void> delete(int id) async {
    final db = await _db.getDatabase();
    await db.delete(TableNames.accounts, where: 'id = ?', whereArgs: [id]);
  }

  /// Saldo actual = initialBalance + (ingresos - gastos por cuenta)
  Future<int> getAccountBalance(int accountId) async {
    final db = await _db.getDatabase();
    final account = await getById(accountId);
    if (account == null) return 0;

    final incomeSum = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${TableNames.transactions}
      WHERE account_id = ? AND type = 'income'
    ''', [accountId]);
    final expenseSum = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${TableNames.transactions}
      WHERE account_id = ? AND type = 'expense'
    ''', [accountId]);

    final income = (incomeSum.first['total'] as int?) ?? 0;
    final expense = (expenseSum.first['total'] as int?) ?? 0;

    return account.initialBalance + income - expense;
  }

  /// Suma de todos los saldos de cuentas activas.
  Future<int> getTotalBalance() async {
    final accounts = await getAll(onlyActive: true);
    int total = 0;
    for (final acc in accounts) {
      total += await getAccountBalance(acc.id!);
    }
    return total;
  }

  Map<String, dynamic> _toRow(Account a) {
    return {
      'name': a.name,
      'type': a.type.name,
      'currency': a.currency == null
          ? ''
          : Currency.values[a.currency!].code,
      'is_active': a.isActive ? 1 : 0,
      'initial_balance': a.initialBalance,
      'created_at': a.createdAt?.toIso8601String(),
      'updated_at': a.updatedAt?.toIso8601String(),
    };
  }

  Account _fromRow(Map<String, dynamic> row) {
    return Account(
      id: row['id'] as int,
      name: row['name'] as String,
      type: AccountTypeX.fromName(row['type'] as String),
      currency: (row['currency'] as String?) == null ||
              (row['currency'] as String).isEmpty
          ? null
          : Currency.fromCode(row['currency'] as String).index,
      isActive: (row['is_active'] as int) == 1,
      initialBalance: row['initial_balance'] as int,
      createdAt: row['created_at'] != null ? DateTime.tryParse(row['created_at']) : null,
      updatedAt: row['updated_at'] != null ? DateTime.tryParse(row['updated_at']) : null,
    );
  }
}