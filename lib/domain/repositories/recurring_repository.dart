import '../entities/recurring_transaction.dart';

abstract class RecurringTransactionRepository {
  Future<List<RecurringTransaction>> getAll({bool onlyActive = false});
  Future<RecurringTransaction?> getById(int id);
  Future<RecurringTransaction> create(RecurringTransaction recurring);
  Future<RecurringTransaction> update(RecurringTransaction recurring);
  Future<void> delete(int id);

  /// Convierte movimientos recurrentes vencidos en transacciones reales.
  Future<List<dynamic>> generateDueTransactions(DateTime upTo);
}