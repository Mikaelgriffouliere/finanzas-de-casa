enum SavingsGoalStatus {
  active,
  completed,
  paused,
}

extension SavingsGoalStatusX on SavingsGoalStatus {
  String get name {
    switch (this) {
      case SavingsGoalStatus.active:
        return 'active';
      case SavingsGoalStatus.completed:
        return 'completed';
      case SavingsGoalStatus.paused:
        return 'paused';
    }
  }

  static SavingsGoalStatus fromName(String name) {
    switch (name) {
      case 'active':
        return SavingsGoalStatus.active;
      case 'completed':
        return SavingsGoalStatus.completed;
      case 'paused':
        return SavingsGoalStatus.paused;
      default:
        return SavingsGoalStatus.active;
    }
  }

  String get label {
    switch (this) {
      case SavingsGoalStatus.active:
        return 'Activo';
      case SavingsGoalStatus.completed:
        return 'Completado';
      case SavingsGoalStatus.paused:
        return 'Pausado';
    }
  }
}
