import 'expense_kind.dart';
import 'entity.dart';
import 'recurring_frequency.dart';

class RecurringTransaction extends Entity {
  final String name;
  final int amount; // en centavos
  final bool isIncome;
  final int? categoryId;
  final int? accountId;
  final RecurringFrequency frequency;
  final int dueDay;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final ExpenseKind kind;
  final String description;
  final int? personId;

  const RecurringTransaction({
    super.id,
    super.createdAt,
    super.updatedAt,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.dueDay,
    required this.startDate,
    this.isIncome = false,
    this.categoryId,
    this.accountId,
    this.personId,
    this.endDate,
    this.isActive = true,
    this.kind = ExpenseKind.variable,
    this.description = '',
  });

  RecurringTransaction copyWith({
    int? id,
    String? name,
    int? amount,
    bool? isIncome,
    int? categoryId,
    int? accountId,
    int? personId,
    RecurringFrequency? frequency,
    int? dueDay,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    ExpenseKind? kind,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isIncome: isIncome ?? this.isIncome,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      personId: personId ?? this.personId,
      frequency: frequency ?? this.frequency,
      dueDay: dueDay ?? this.dueDay,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      kind: kind ?? this.kind,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}