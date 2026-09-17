import 'entity.dart';

class Budget extends Entity {
  final int categoryId;
  final int amount; // en centavos mensuales
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  const Budget({
    super.id,
    super.createdAt,
    super.updatedAt,
    required this.categoryId,
    required this.amount,
    required this.startDate,
    this.endDate,
    this.isActive = true,
  });

  Budget copyWith({
    int? id,
    int? categoryId,
    int? amount,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}