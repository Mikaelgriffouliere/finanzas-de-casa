enum RecurringFrequency {
  weekly,
  fortnightly,
  monthly,
  yearly,
}

extension RecurringFrequencyX on RecurringFrequency {
  String get name {
    switch (this) {
      case RecurringFrequency.weekly:
        return 'weekly';
      case RecurringFrequency.fortnightly:
        return 'fortnightly';
      case RecurringFrequency.monthly:
        return 'monthly';
      case RecurringFrequency.yearly:
        return 'yearly';
    }
  }

  static RecurringFrequency fromName(String name) {
    switch (name) {
      case 'weekly':
        return RecurringFrequency.weekly;
      case 'fortnightly':
        return RecurringFrequency.fortnightly;
      case 'monthly':
        return RecurringFrequency.monthly;
      case 'yearly':
        return RecurringFrequency.yearly;
      default:
        return RecurringFrequency.monthly;
    }
  }

  String get label {
    switch (this) {
      case RecurringFrequency.weekly:
        return 'Semanal';
      case RecurringFrequency.fortnightly:
        return 'Quincenal';
      case RecurringFrequency.monthly:
        return 'Mensual';
      case RecurringFrequency.yearly:
        return 'Anual';
    }
  }
}
