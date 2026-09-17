import 'account_type.dart';
import 'entity.dart';

class Account extends Entity {
  final String name;
  final AccountType type;
  final int? currency; // id de moneda (reservado para futuro)
  final bool isActive;
  final int initialBalance; // en centavos

  const Account({
    super.id,
    super.createdAt,
    super.updatedAt,
    required this.name,
    required this.type,
    this.currency,
    this.isActive = true,
    this.initialBalance = 0,
  });

  Account copyWith({
    int? id,
    String? name,
    AccountType? type,
    int? currency,
    bool? isActive,
    int? initialBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      initialBalance: initialBalance ?? this.initialBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
