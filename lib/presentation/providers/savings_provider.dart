import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../../domain/entities/savings_goal.dart';
import '../../../domain/entities/savings_movement.dart';
import '../../../data/repositories/savings_repository_impl.dart';

class SavingsProvider extends ChangeNotifier {
  final SavingsGoalRepositoryImpl _repository;

  List<SavingsGoal> _goals = [];
  List<SavingsGoal> get goals => List.unmodifiable(_goals);

  SavingsProvider({SavingsGoalRepositoryImpl? repository})
      : _repository = repository ?? SavingsGoalRepositoryImpl();

  Future<void> loadAll() async {
    try {
      _goals = await _repository.getAll();
      notifyListeners();
    } catch (e, stack) {
      developer.log('SavingsProvider.loadAll error', error: e, stackTrace: stack);
    }
  }

  Future<void> add(SavingsGoal goal) async {
    try {
      final created = await _repository.create(goal);
      _goals.add(created);
      notifyListeners();
    } catch (e, stack) {
      developer.log('SavingsProvider.add error', error: e, stackTrace: stack);
    }
  }

  Future<void> update(SavingsGoal goal) async {
    try {
      final updated = await _repository.update(goal);
      final index = _goals.indexWhere((g) => g.id == updated.id);
      if (index != -1) {
        _goals[index] = updated;
        notifyListeners();
      }
    } catch (e, stack) {
      developer.log('SavingsProvider.update error', error: e, stackTrace: stack);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _repository.delete(id);
      _goals.removeWhere((g) => g.id == id);
      notifyListeners();
    } catch (e, stack) {
      developer.log('SavingsProvider.delete error', error: e, stackTrace: stack);
    }
  }

  Future<void> deposit(int goalId, int amount, {int? accountId}) async {
    try {
      final movement = SavingsMovement(
        savingsGoalId: goalId,
        amount: amount,
        isDeposit: true,
        date: DateTime.now(),
        accountId: accountId,
      );
      await _repository.addMovement(movement);
      await loadAll();
    } catch (e, stack) {
      developer.log('SavingsProvider.deposit error', error: e, stackTrace: stack);
    }
  }

  Future<void> withdraw(int goalId, int amount) async {
    try {
      final movement = SavingsMovement(
        savingsGoalId: goalId,
        amount: amount,
        isDeposit: false,
        date: DateTime.now(),
      );
      await _repository.addMovement(movement);
      await loadAll();
    } catch (e, stack) {
      developer.log('SavingsProvider.withdraw error', error: e, stackTrace: stack);
    }
  }

  Future<List<SavingsMovement>> getMovements(int goalId) async {
    try {
      return await _repository.getMovements(goalId);
    } catch (e, stack) {
      developer.log('SavingsProvider.getMovements error', error: e, stackTrace: stack);
      return [];
    }
  }
}
