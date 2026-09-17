import '../entities/savings_goal.dart';
import '../entities/savings_movement.dart';

abstract class SavingsGoalRepository {
  Future<List<SavingsGoal>> getAll({bool onlyActive = false});
  Future<SavingsGoal?> getById(int id);
  Future<SavingsGoal> create(SavingsGoal goal);
  Future<SavingsGoal> update(SavingsGoal goal);
  Future<void> delete(int id);

  Future<List<SavingsMovement>> getMovements(int goalId);
  Future<SavingsMovement> addMovement(SavingsMovement movement);
  Future<void> deleteMovement(int movementId);
}