import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../../domain/entities/budget.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../../data/repositories/budget_repository_impl.dart';
import '../../../data/repositories/transaction_repository_impl.dart';
import '../../../utils/formatters.dart';

class BudgetStatus {
  final int budget;
  final int spent;
  final int remaining;
  final double percentUsed;
  final bool isWarning;
  final bool isExceeded;

  const BudgetStatus({
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.percentUsed,
    required this.isWarning,
    required this.isExceeded,
  });
}

class BudgetProvider extends ChangeNotifier {
  final BudgetRepositoryImpl _repository;
  final TransactionRepositoryImpl _transactionRepository;

  List<Budget> _budgets = [];
  List<Budget> get budgets => List.unmodifiable(_budgets);

  BudgetProvider({
    BudgetRepositoryImpl? repository,
    TransactionRepositoryImpl? transactionRepository,
  })  : _repository = repository ?? BudgetRepositoryImpl(),
        _transactionRepository = transactionRepository ?? TransactionRepositoryImpl();

  Future<void> loadAll() async {
    try {
      _budgets = await _repository.getAll();
      notifyListeners();
    } catch (e, stack) {
      developer.log('BudgetProvider.loadAll error', error: e, stackTrace: stack);
    }
  }

  Future<void> add(Budget budget) async {
    try {
      final created = await _repository.create(budget);
      _budgets.add(created);
      notifyListeners();
    } catch (e, stack) {
      developer.log('BudgetProvider.add error', error: e, stackTrace: stack);
    }
  }

  Future<void> update(Budget budget) async {
    try {
      final updated = await _repository.update(budget);
      final index = _budgets.indexWhere((b) => b.id == updated.id);
      if (index != -1) {
        _budgets[index] = updated;
        notifyListeners();
      }
    } catch (e, stack) {
      developer.log('BudgetProvider.update error', error: e, stackTrace: stack);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _repository.delete(id);
      _budgets.removeWhere((b) => b.id == id);
      notifyListeners();
    } catch (e, stack) {
      developer.log('BudgetProvider.delete error', error: e, stackTrace: stack);
    }
  }

  Future<double> getCategorySpent(int categoryId, {DateTime? month}) async {
    final target = month ?? DateTime.now();
    final from = DateUtils.startOfMonth(target);
    final to = DateUtils.endOfMonth(target);
    final remaining = await _transactionRepository.sumByCategory(
      type: TransactionType.expense,
      from: from,
      to: to,
    );
    return MoneyUtils.fromCents(_subcategorySpent(categoryId, remaining));
  }

  int _subcategorySpent(int categoryId, Map<int, int> byCategory) {
    if (byCategory.containsKey(categoryId)) {
      return byCategory[categoryId]!;
    }
    return 0;
  }

  Future<BudgetStatus> getStatus(Budget budget, {DateTime? month}) async {
    final target = month ?? DateTime.now();
    final from = DateUtils.startOfMonth(target);
    final to = DateUtils.endOfMonth(target);
    final spent = await _transactionRepository.sumByCategory(
      type: TransactionType.expense,
      from: from,
      to: to,
    );
    final spentValue = spent[budget.categoryId] ?? 0;
    final percent = budget.amount > 0 ? spentValue / budget.amount : 0.0;
    return BudgetStatus(
      budget: budget.amount,
      spent: spentValue,
      remaining: budget.amount - spentValue,
      percentUsed: percent,
      isWarning: percent >= 0.8 && percent < 1.0,
      isExceeded: percent >= 1.0,
    );
  }
}
