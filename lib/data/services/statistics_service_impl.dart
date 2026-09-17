import '../../../domain/entities/transaction.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/services/statistics_service.dart';
import '../../../utils/formatters.dart';
import '../repositories/category_repository_impl.dart';
import '../repositories/person_repository_impl.dart';
import '../repositories/transaction_repository_impl.dart';

class StatisticsServiceImpl implements StatisticsService {
  final TransactionRepositoryImpl _transactions = TransactionRepositoryImpl();
  final CategoryRepositoryImpl _categories = CategoryRepositoryImpl();
  final PersonRepositoryImpl _persons = PersonRepositoryImpl();

  @override
  Future<MonthlySummary> getMonthlySummary({
    required int year,
    required int month,
  }) async {
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0, 23, 59, 59);
    final prevFrom = DateUtils.firstDayOfPreviousMonth(from);
    final prevTo = DateUtils.lastDayOfPreviousMonth(from);

    final income = await _transactions.sumByType(
      type: TransactionType.income,
      from: from,
      to: to,
    );
    final expense = await _transactions.sumByType(
      type: TransactionType.expense,
      from: from,
      to: to,
    );
    final previousIncome = await _transactions.sumByType(
      type: TransactionType.income,
      from: prevFrom,
      to: prevTo,
    );
    final previousExpense = await _transactions.sumByType(
      type: TransactionType.expense,
      from: prevFrom,
      to: prevTo,
    );

    return MonthlySummary(
      income: income,
      expense: expense,
      previousIncome: previousIncome,
      previousExpense: previousExpense,
    );
  }

  @override
  Future<List<CategoryExpense>> getExpensesByCategory({
    required DateTime from,
    required DateTime to,
  }) async {
    final totals = await _transactions.sumByCategory(
      type: TransactionType.expense,
      from: from,
      to: to,
    );

    final overallTotal = totals.values.fold<int>(0, (a, b) => a + b);
    final result = <CategoryExpense>[];

    for (final entry in totals.entries) {
      final category = await _categories.getCategoryById(entry.key);
      final name = category?.name ?? 'Sin categoría';
      final percent = overallTotal > 0 ? entry.value / overallTotal : 0.0;
      result.add(CategoryExpense(name: name, amount: entry.value, percent: percent));
    }

    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  @override
  Future<List<PersonContribution>> getIncomeByPerson({
    required DateTime from,
    required DateTime to,
  }) async {
    final totals = await _transactions.sumByPerson(
      type: TransactionType.income,
      from: from,
      to: to,
    );

    final overallTotal = totals.values.fold<int>(0, (a, b) => a + b);
    final result = <PersonContribution>[];

    for (final entry in totals.entries) {
      final person = await _persons.getById(entry.key);
      final name = person?.name ?? 'Desconocido';
      final percent = overallTotal > 0 ? entry.value / overallTotal : 0.0;
      result.add(PersonContribution(name: name, amount: entry.value, percent: percent));
    }

    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  @override
  Future<List<PersonContribution>> getExpensesByPerson({
    required DateTime from,
    required DateTime to,
  }) async {
    final totals = await _transactions.sumByPerson(
      type: TransactionType.expense,
      from: from,
      to: to,
    );

    final overallTotal = totals.values.fold<int>(0, (a, b) => a + b);
    final result = <PersonContribution>[];

    for (final entry in totals.entries) {
      final person = await _persons.getById(entry.key);
      final name = person?.name ?? 'Desconocido';
      final percent = overallTotal > 0 ? entry.value / overallTotal : 0.0;
      result.add(PersonContribution(name: name, amount: entry.value, percent: percent));
    }

    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  @override
  Future<double> getDailyExpenseAverage({
    required DateTime from,
    required DateTime to,
  }) async {
    final totalExpense = await _transactions.sumByType(
      type: TransactionType.expense,
      from: from,
      to: to,
    );
    final days = to.difference(from).inDays + 1;
    if (days <= 0) return 0;
    return MoneyUtils.fromCents(totalExpense) / days;
  }

  @override
  Future<List<Transaction>> getRecentTransactions({int limit = 10}) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final all = await _transactions.getAll(
      filter: TransactionFilter(from: from, to: now),
    );
    return all.take(limit).toList();
  }
}
