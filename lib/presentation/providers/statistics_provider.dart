import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../../domain/services/statistics_service.dart';
import '../../../data/services/statistics_service_impl.dart';
import '../../../utils/formatters.dart';

class StatisticsProvider extends ChangeNotifier {
  final StatisticsServiceImpl _service;

  MonthlySummary? _summary;
  MonthlySummary? get summary => _summary;

  List<CategoryExpense> _categoryExpenses = [];
  List<CategoryExpense> get categoryExpenses => List.unmodifiable(_categoryExpenses);

  List<PersonContribution> _incomeByPerson = [];
  List<PersonContribution> get incomeByPerson => List.unmodifiable(_incomeByPerson);

  List<PersonContribution> _expensesByPerson = [];
  List<PersonContribution> get expensesByPerson =>
      List.unmodifiable(_expensesByPerson);

  double _dailyAverage = 0;
  double get dailyAverage => _dailyAverage;

  DateTime _selectedMonth = DateTime.now();
  DateTime get selectedMonth => _selectedMonth;

  StatisticsProvider({StatisticsServiceImpl? service})
      : _service = service ?? StatisticsServiceImpl();

  Future<void> setMonth(DateTime month) async {
    _selectedMonth = DateTime(month.year, month.month, 1);
    await loadMonthlyData();
  }

  Future<void> loadMonthlyData() async {
    await loadMonthlySummary(_selectedMonth.year, _selectedMonth.month);
    final from = DateUtils.startOfMonth(_selectedMonth);
    final to = DateUtils.endOfMonth(_selectedMonth);
    await loadCategoryExpenses(from, to);
    await loadIncomeByPerson(from, to);
    await loadExpensesByPerson(from, to);
    await loadDailyAverage(from, to);
  }

  Future<void> loadMonthlySummary(int year, int month) async {
    try {
      _summary = await _service.getMonthlySummary(year: year, month: month);
      notifyListeners();
    } catch (e, stack) {
      developer.log('StatisticsProvider.loadMonthlySummary error',
          error: e, stackTrace: stack);
    }
  }

  Future<void> loadCategoryExpenses(DateTime from, DateTime to) async {
    try {
      _categoryExpenses = await _service.getExpensesByCategory(from: from, to: to);
      notifyListeners();
    } catch (e, stack) {
      developer.log('StatisticsProvider.loadCategoryExpenses error',
          error: e, stackTrace: stack);
    }
  }

  Future<void> loadIncomeByPerson(DateTime from, DateTime to) async {
    try {
      _incomeByPerson = await _service.getIncomeByPerson(from: from, to: to);
      notifyListeners();
    } catch (e, stack) {
      developer.log('StatisticsProvider.loadIncomeByPerson error',
          error: e, stackTrace: stack);
    }
  }

  Future<void> loadExpensesByPerson(DateTime from, DateTime to) async {
    try {
      _expensesByPerson = await _service.getExpensesByPerson(from: from, to: to);
      notifyListeners();
    } catch (e, stack) {
      developer.log('StatisticsProvider.loadExpensesByPerson error',
          error: e, stackTrace: stack);
    }
  }

  Future<void> loadDailyAverage(DateTime from, DateTime to) async {
    try {
      _dailyAverage = await _service.getDailyExpenseAverage(from: from, to: to);
      notifyListeners();
    } catch (e, stack) {
      developer.log('StatisticsProvider.loadDailyAverage error',
          error: e, stackTrace: stack);
    }
  }
}
