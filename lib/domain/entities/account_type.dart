enum AccountType {
  cash,
  bankAccount,
  wallet,
  card,
  savings,
  investment,
}

extension AccountTypeX on AccountType {
  String get name {
    switch (this) {
      case AccountType.cash:
        return 'cash';
      case AccountType.bankAccount:
        return 'bank_account';
      case AccountType.wallet:
        return 'wallet';
      case AccountType.card:
        return 'card';
      case AccountType.savings:
        return 'savings';
      case AccountType.investment:
        return 'investment';
    }
  }

  static AccountType fromName(String name) {
    switch (name) {
      case 'cash':
        return AccountType.cash;
      case 'bank_account':
        return AccountType.bankAccount;
      case 'wallet':
        return AccountType.wallet;
      case 'card':
        return AccountType.card;
      case 'savings':
        return AccountType.savings;
      case 'investment':
        return AccountType.investment;
      default:
        return AccountType.cash;
    }
  }

  String get label {
    switch (this) {
      case AccountType.cash:
        return 'Efectivo';
      case AccountType.bankAccount:
        return 'Cuenta bancaria';
      case AccountType.wallet:
        return 'Billetera virtual';
      case AccountType.card:
        return 'Tarjeta';
      case AccountType.savings:
        return 'Caja de ahorro';
      case AccountType.investment:
        return 'Inversión';
    }
  }
}
