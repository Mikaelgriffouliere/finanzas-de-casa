import '../entities/transaction.dart';
import '../entities/transaction_type.dart';

class TransactionFilter {
  final DateTime? from;
  final DateTime? to;
  final int? personId;
  final int? categoryId;
  final int? accountId;
  final TransactionType? type;
  final int? minAmount;
  final int? maxAmount;
  final String? searchText;

  const TransactionFilter({
    this.from,
    this.to,
    this.personId,
    this.categoryId,
    this.accountId,
    this.type,
    this.minAmount,
    this.maxAmount,
    this.searchText,
  });

  TransactionFilter copyWith({
    DateTime? from,
    DateTime? to,
    int? personId,
    int? categoryId,
    int? accountId,
    TransactionType? type,
    int? minAmount,
    int? maxAmount,
    String? searchText,
  }) {
    return TransactionFilter(
      from: from ?? this.from,
      to: to ?? this.to,
      personId: personId ?? this.personId,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      searchText: searchText ?? this.searchText,
    );
  }
}

abstract class TransactionRepository {
  Future<List<Transaction>> getAll({TransactionFilter? filter});
  Future<Transaction?> getById(int id);
  Future<Transaction> create(Transaction transaction);
  Future<Transaction> update(Transaction transaction);
  Future<void> delete(int id);

  /// Crea una transferencia actualizando los saldos de ambas cuentas.
  Future<Transaction> createTransfer(Transaction transfer);

  Future<int> sumByType({
    required TransactionType type,
    DateTime? from,
    DateTime? to,
  });

  Future<Map<int, int>> sumByCategory({
    required TransactionType type,
    DateTime? from,
    DateTime? to,
  });

  Future<Map<int, int>> sumByPerson({
    required TransactionType type,
    DateTime? from,
    DateTime? to,
  });

  Future<Map<String, int>> sumByMonth({
    required TransactionType type,
    DateTime from,
    DateTime to,
  });
}