import 'package:flutter/foundation.dart';

import 'person_provider.dart';
import 'account_provider.dart';
import 'category_provider.dart';
import 'transaction_provider.dart';
import 'budget_provider.dart';
import 'savings_provider.dart';
import 'recurring_provider.dart';
import 'statistics_provider.dart';
import 'security_provider.dart';

class AppProvider extends ChangeNotifier {
  AppProvider() {
    transaction = TransactionProvider();
    account = AccountProvider();
    person = PersonProvider();
    category = CategoryProvider();
    budget = BudgetProvider();
    savings = SavingsProvider();
    recurring = RecurringProvider();
    statistics = StatisticsProvider();
    security = SecurityProvider();

    for (final provider in [
      transaction,
      account,
      person,
      category,
      budget,
      savings,
      recurring,
      statistics,
      security,
    ]) {
      provider.addListener(_forward);
    }
    transaction.addListener(_onTransactionsChanged);
  }

  void _forward() => notifyListeners();

  Future<void> _onTransactionsChanged() async {
    await Future.wait([
      account.refreshBalance(),
      statistics.loadMonthlyData(),
    ]);
  }

  late final TransactionProvider transaction;
  late final AccountProvider account;
  late final PersonProvider person;
  late final CategoryProvider category;
  late final BudgetProvider budget;
  late final SavingsProvider savings;
  late final RecurringProvider recurring;
  late final StatisticsProvider statistics;
  late final SecurityProvider security;

  bool _initialized = false;
  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    await security.load();

    await Future.wait([
      person.loadAll(),
      account.loadAll(),
      category.loadAll(),
      budget.loadAll(),
      savings.loadAll(),
      recurring.loadAll(),
      transaction.loadAll(),
    ]);

    await statistics.loadMonthlyData();

    _initialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final provider in [
      transaction,
      account,
      person,
      category,
      budget,
      savings,
      recurring,
      statistics,
      security,
    ]) {
      provider.removeListener(_forward);
      provider.dispose();
    }
    transaction.removeListener(_onTransactionsChanged);
    super.dispose();
  }
}
