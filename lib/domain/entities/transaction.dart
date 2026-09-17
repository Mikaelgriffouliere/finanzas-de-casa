import 'transaction_type.dart';
import 'entity.dart';

class Transaction extends Entity {
  final TransactionType type;
  final int amount; // en centavos
  final int? categoryId;
  final int? subcategoryId;
  final int? personId;
  final int? accountId;
  final int? transferAccountId;
  final String description;
  final String notes;
  final bool isRecurring;
  final DateTime date;

  const Transaction({
    super.id,
    super.createdAt,
    super.updatedAt,
    required this.type,
    required this.amount,
    required this.date,
    this.categoryId,
    this.subcategoryId,
    this.personId,
    this.accountId,
    this.transferAccountId,
    this.description = '',
    this.notes = '',
    this.isRecurring = false,
  });

  Transaction copyWith({
    int? id,
    TransactionType? type,
    int? amount,
    DateTime? date,
    int? categoryId,
    bool clearCategoryId = false,
    int? subcategoryId,
    bool clearSubcategoryId = false,
    int? personId,
    bool clearPersonId = false,
    int? accountId,
    bool clearAccountId = false,
    int? transferAccountId,
    bool clearTransferAccountId = false,
    String? description,
    String? notes,
    bool? isRecurring,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: clearCategoryId
          ? null
          : (categoryId ?? this.categoryId),
      subcategoryId: clearSubcategoryId
          ? null
          : (subcategoryId ?? this.subcategoryId),
      personId: clearPersonId ? null : (personId ?? this.personId),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      transferAccountId: clearTransferAccountId
          ? null
          : (transferAccountId ?? this.transferAccountId),
      description: description ?? this.description,
      notes: notes ?? this.notes,
      isRecurring: isRecurring ?? this.isRecurring,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}