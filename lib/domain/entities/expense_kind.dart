enum ExpenseKind {
  fixed,
  variable,
}

extension ExpenseKindX on ExpenseKind {
  String get name {
    switch (this) {
      case ExpenseKind.fixed:
        return 'fixed';
      case ExpenseKind.variable:
        return 'variable';
    }
  }

  static ExpenseKind fromName(String name) {
    switch (name) {
      case 'fixed':
        return ExpenseKind.fixed;
      case 'variable':
        return ExpenseKind.variable;
      default:
        return ExpenseKind.variable;
    }
  }

  String get label {
    switch (this) {
      case ExpenseKind.fixed:
        return 'Fijo';
      case ExpenseKind.variable:
        return 'Variable';
    }
  }
}
