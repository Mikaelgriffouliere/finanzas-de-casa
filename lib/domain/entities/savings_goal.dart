import 'entity.dart';
import 'savings_goal_status.dart';

class SavingsGoal extends Entity {
  final String name;
  final String description;
  final int targetAmount; // en centavos
  final int currentAmount; // en centavos
  final DateTime? targetDate;
  final int priority; // 1 = alta, 2 = media, 3 = baja
  final SavingsGoalStatus status;

  const SavingsGoal({
    super.id,
    super.createdAt,
    super.updatedAt,
    required this.name,
    required this.targetAmount,
    this.description = '',
    this.currentAmount = 0,
    this.targetDate,
    this.priority = 2,
    this.status = SavingsGoalStatus.active,
  });

  double get progress {
    if (targetAmount <= 0) return 0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  SavingsGoal copyWith({
    int? id,
    String? name,
    String? description,
    int? targetAmount,
    int? currentAmount,
    DateTime? targetDate,
    int? priority,
    SavingsGoalStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}