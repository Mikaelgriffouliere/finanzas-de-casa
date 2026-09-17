import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../../domain/entities/recurring_transaction.dart';
import '../../../data/repositories/recurring_repository_impl.dart';

class RecurringProvider extends ChangeNotifier {
  final RecurringTransactionRepositoryImpl _repository;

  List<RecurringTransaction> _recurringTransactions = [];
  List<RecurringTransaction> get recurringTransactions =>
      List.unmodifiable(_recurringTransactions);

  RecurringProvider({RecurringTransactionRepositoryImpl? repository})
      : _repository = repository ?? RecurringTransactionRepositoryImpl();

  Future<void> loadAll() async {
    try {
      _recurringTransactions = await _repository.getAll();
      notifyListeners();
    } catch (e, stack) {
      developer.log('RecurringProvider.loadAll error', error: e, stackTrace: stack);
    }
  }

  Future<void> add(RecurringTransaction recurring) async {
    try {
      final created = await _repository.create(recurring);
      _recurringTransactions.add(created);
      notifyListeners();
    } catch (e, stack) {
      developer.log('RecurringProvider.add error', error: e, stackTrace: stack);
    }
  }

  Future<void> update(RecurringTransaction recurring) async {
    try {
      final updated = await _repository.update(recurring);
      final index = _recurringTransactions.indexWhere((r) => r.id == updated.id);
      if (index != -1) {
        _recurringTransactions[index] = updated;
        notifyListeners();
      }
    } catch (e, stack) {
      developer.log('RecurringProvider.update error', error: e, stackTrace: stack);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _repository.delete(id);
      _recurringTransactions.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (e, stack) {
      developer.log('RecurringProvider.delete error', error: e, stackTrace: stack);
    }
  }

  Future<void> generateDue() async {
    try {
      await _repository.generateDueTransactions(DateTime.now());
      await loadAll();
    } catch (e, stack) {
      developer.log('RecurringProvider.generateDue error', error: e, stackTrace: stack);
    }
  }
}
