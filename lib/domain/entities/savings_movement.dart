import 'entity.dart';

class SavingsMovement extends Entity {
  final int savingsGoalId;
  final int amount; // en centavos
  final bool isDeposit; // true = aporte, false = retiro
  final DateTime date;
  final String description;
  final int? accountId;

  const SavingsMovement({
    super.id,
    super.createdAt,
    super.updatedAt,
    required this.savingsGoalId,
    required this.amount,
    required this.isDeposit,
    required this.date,
    this.description = '',
    this.accountId,
  });

  SavingsMovement copyWith({
    int? id,
    int? savingsGoalId,
    int? amount,
    bool? isDeposit,
    DateTime? date,
    String? description,
    int? accountId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavingsMovement(
      id: id ?? this.id,
      savingsGoalId: savingsGoalId ?? this.savingsGoalId,
      amount: amount ?? this.amount,
      isDeposit: isDeposit ?? this.isDeposit,
      date: date ?? this.date,
      description: description ?? this.description,
      accountId: accountId ?? this.accountId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}