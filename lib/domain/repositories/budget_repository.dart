import '../entities/budget.dart';

abstract class BudgetRepository {
  Future<List<Budget>> getAll({bool onlyActive = false});
  Future<Budget?> getById(int id);
  Future<Budget?> getByCategory(int categoryId);
  Future<Budget> create(Budget budget);
  Future<Budget> update(Budget budget);
  Future<void> delete(int id);
}