import 'package:flutter/foundation.dart';

import '../../../domain/entities/transaction.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../data/repositories/transaction_repository_impl.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionRepositoryImpl _repository;

  List<Transaction> _transactions = [];
  List<Transaction> get transactions => List.unmodifiable(_transactions);

  Transaction? byId(int? id) {
    if (id == null) return null;
    for (final t in _transactions) {
      if (t.id == id) return t;
    }
    return null;
  }

  TransactionFilter? _currentFilter;
  TransactionFilter? get currentFilter => _currentFilter;

  TransactionProvider({TransactionRepositoryImpl? repository})
      : _repository = repository ?? TransactionRepositoryImpl();

  Future<void> setFilter(TransactionFilter filter) async {
    _currentFilter = filter;
    await _loadWithFilter(filter);
  }

  Future<void> clearFilter() async {
    _currentFilter = null;
    await loadAll();
  }

  Future<void> loadAll() async {
    await _loadWithFilter(_currentFilter);
  }

  Future<void> loadByDateRange(DateTime from, DateTime to) async {
    final filter = _currentFilter?.copyWith(from: from, to: to) ??
        TransactionFilter(from: from, to: to);
    await _loadWithFilter(filter);
  }

  Future<void> loadRecent(int limit) async {
    try {
      final now = DateTime.now();
      final filter = TransactionFilter(
        from: DateTime(now.year, now.month, 1),
        to: now,
      );
      final all = await _repository.getAll(filter: filter);
      _transactions = all.take(limit).toList();
      notifyListeners();
    } catch (e, stack) {
      debugPrint('TransactionProvider.loadRecent error: $e\n$stack');
    }
  }

  Future<void> _loadWithFilter(TransactionFilter? filter) async {
    try {
      _transactions = await _repository.getAll(filter: filter);
      notifyListeners();
    } catch (e, stack) {
      debugPrint('TransactionProvider load error: $e\n$stack');
    }
  }

  Future<void> addExpense(Transaction transaction) async {
    try {
      final created = await _repository.create(
        transaction.copyWith(type: TransactionType.expense),
      );
      _transactions.insert(0, created);
      notifyListeners();
    } catch (e, stack) {
      debugPrint('TransactionProvider.addExpense error: $e\n$stack');
    }
  }

  Future<void> addIncome(Transaction transaction) async {
    try {
      final created = await _repository.create(
        transaction.copyWith(type: TransactionType.income),
      );
      _transactions.insert(0, created);
      notifyListeners();
    } catch (e, stack) {
      debugPrint('TransactionProvider.addIncome error: $e\n$stack');
    }
  }

  Future<void> addTransfer(Transaction transaction) async {
    try {
      final created = await _repository.createTransfer(
        transaction.copyWith(type: TransactionType.transfer),
      );
      _transactions.insert(0, created);
      notifyListeners();
    } catch (e, stack) {
      debugPrint('TransactionProvider.addTransfer error: $e\n$stack');
    }
  }

  Future<void> update(Transaction transaction) async {
    try {
      final updated = await _repository.update(transaction);
      final index = _transactions.indexWhere((t) => t.id == updated.id);
      if (index != -1) {
        _transactions[index] = updated;
        notifyListeners();
      }
    } catch (e, stack) {
      debugPrint('TransactionProvider.update error: $e\n$stack');
    }
  }

  Future<void> delete(int id) async {
    try {
      await _repository.delete(id);
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e, stack) {
      debugPrint('TransactionProvider.delete error: $e\n$stack');
    }
  }
}
