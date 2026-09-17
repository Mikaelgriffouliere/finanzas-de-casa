import '../entities/transaction.dart';

class MonthlySummary {
  final int income;
  final int expense;
  final int savingsTransferIn;
  final int? previousIncome;
  final int? previousExpense;

  const MonthlySummary({
    this.income = 0,
    this.expense = 0,
    this.savingsTransferIn = 0,
    this.previousIncome,
    this.previousExpense,
  });

  int get savings => income - expense - savingsTransferIn;
  int get available => income - expense;

  double get savingsRate {
    if (income <= 0) return 0;
    return (savings / income).clamp(0.0, 1.0);
  }

  double get incomeDeltaPercent {
    if (previousIncome == null || previousIncome == 0) return 0;
    return ((income - previousIncome!) / previousIncome! * 100);
  }

  double get expenseDeltaPercent {
    if (previousExpense == null || previousExpense == 0) return 0;
    return ((expense - previousExpense!) / previousExpense! * 100);
  }
}

class CategoryExpense {
  final String name;
  final int amount;
  final double percent;

  const CategoryExpense({
    required this.name,
    required this.amount,
    required this.percent,
  });
}

class PersonContribution {
  final String name;
  final int amount;
  final double percent;

  const PersonContribution({
    required this.name,
    required this.amount,
    required this.percent,
  });
}

abstract class StatisticsService {
  /// Resumen mensual: ingresos, gastos, ahorro, disponible y evolución.
  Future<MonthlySummary> getMonthlySummary({required int year, required int month});

  /// Gastos agrupados por categoría para un rango de fechas.
  Future<List<CategoryExpense>> getExpensesByCategory({
    required DateTime from,
    required DateTime to,
  });

  /// Ingresos por persona.
  Future<List<PersonContribution>> getIncomeByPerson({
    required DateTime from,
    required DateTime to,
  });

  /// Gastos por persona.
  Future<List<PersonContribution>> getExpensesByPerson({
    required DateTime from,
    required DateTime to,
  });

  /// Promedio de gasto diario en un rango.
  Future<double> getDailyExpenseAverage({required DateTime from, required DateTime to});

  /// Movimientos del mes actual para el dashboard.
  Future<List<Transaction>> getRecentTransactions({int limit = 10});
}