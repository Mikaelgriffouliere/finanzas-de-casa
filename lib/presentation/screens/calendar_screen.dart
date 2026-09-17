import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/recurring_frequency.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_type.dart';
import '../common/amount_display.dart';
import '../common/empty_state.dart';
import '../providers/app_provider.dart';
import 'transaction_detail_screen.dart';
import '../../core/theme/app_colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _localeReady = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null).then((_) {
      if (mounted) setState(() => _localeReady = true);
    });
    _selectedDay = DateTime.now();
    _loadMonth(_focusedDay);
  }

  Future<void> _loadMonth(DateTime month) async {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    await context.read<AppProvider>().transaction.loadByDateRange(from, to);
  }

  Map<DateTime, List<Transaction>> _buildEventMap(
    List<Transaction> transactions,
  ) {
    final map = <DateTime, List<Transaction>>{};
    for (final t in transactions) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      map.putIfAbsent(day, () => []).add(t);
    }
    return map;
  }

  List<_CalendarItem> _getItemsForDay(
    DateTime day,
    List<Transaction> transactions,
    List<RecurringTransaction> recurring,
  ) {
    final items = <_CalendarItem>[];
    final dayOnly = DateTime(day.year, day.month, day.day);

    for (final t in transactions) {
      if (DateTime(t.date.year, t.date.month, t.date.day) == dayOnly) {
        items.add(_CalendarItem.transaction(t));
      }
    }

    for (final r in recurring) {
      if (!r.isActive) continue;
      if (r.dueDay != day.day) continue;
      if (dayOnly.isBefore(
        DateTime(r.startDate.year, r.startDate.month, r.startDate.day),
      ))
        continue;
      if (r.endDate != null && dayOnly.isAfter(r.endDate!)) continue;
      items.add(_CalendarItem.recurring(r));
    }

    items.sort((a, b) {
      if (a.isRecurring && !b.isRecurring) return 1;
      if (!a.isRecurring && b.isRecurring) return -1;
      return 0;
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final transactions = app.transaction.transactions;
    final recurring = app.recurring.recurringTransactions;
    final eventMap = _buildEventMap(transactions);

    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthEnd = DateTime(
      _focusedDay.year,
      _focusedDay.month + 1,
      0,
      23,
      59,
      59,
    );

    int totalIncome = 0;
    int totalExpense = 0;
    for (final t in transactions) {
      if (t.date.isBefore(monthStart) || t.date.isAfter(monthEnd)) continue;
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else if (t.type == TransactionType.expense) {
        totalExpense += t.amount;
      }
    }

    final dayItems = _selectedDay != null
        ? _getItemsForDay(_selectedDay!, transactions, recurring)
        : <_CalendarItem>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          TextButton(
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _focusedDay = now;
                _selectedDay = now;
              });
              _loadMonth(now);
            },
            child: const Text('Ir a hoy'),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<Transaction>(
            locale: _localeReady ? 'es_ES' : null,
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) {
              final dayOnly = DateTime(day.year, day.month, day.day);
              return eventMap[dayOnly] ?? [];
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadMonth(focusedDay);
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              outsideDaysVisible: false,
            ),
            headerStyle: HeaderStyle(
              formatButtonDecoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              titleCentered: true,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final dayOnly = DateTime(day.year, day.month, day.day);
                final dayTransactions = eventMap[dayOnly] ?? [];
                if (dayTransactions.isEmpty) return null;

                bool hasIncome = false;
                bool hasExpense = false;
                for (final t in dayTransactions) {
                  if (t.type == TransactionType.income) hasIncome = true;
                  if (t.type == TransactionType.expense) hasExpense = true;
                }

                final dots = <Widget>[];
                if (hasIncome) {
                  dots.add(
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.income,
                      ),
                    ),
                  );
                }
                if (hasExpense) {
                  dots.add(
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.expense,
                      ),
                    ),
                  );
                }

                return Positioned(
                  bottom: 1,
                  child: Row(mainAxisSize: MainAxisSize.min, children: dots),
                );
              },
            ),
          ),
          const Divider(height: 1),
          _MonthSummary(totalIncome: totalIncome, totalExpense: totalExpense),
          const Divider(height: 1),
          Expanded(
            child: _selectedDay == null
                ? const SizedBox.shrink()
                : dayItems.isEmpty
                ? const EmptyState(
                    icon: Icons.event_busy,
                    title: 'Sin movimientos este día',
                  )
                : ListView.builder(
                    itemCount: dayItems.length,
                    itemBuilder: (context, index) {
                      final item = dayItems[index];
                      if (item.isRecurring) {
                        return _RecurringTile(recurring: item.recurring!);
                      }
                      return _TransactionTile(
                        transaction: item.transaction!,
                        app: app,
                        onTap: () => _openTransaction(item.transaction!),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTransaction(Transaction transaction) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transaction: transaction),
      ),
    );
    _loadMonth(_focusedDay);
  }
}

class _CalendarItem {
  final Transaction? transaction;
  final RecurringTransaction? recurring;

  const _CalendarItem.transaction(this.transaction) : recurring = null;
  const _CalendarItem.recurring(this.recurring) : transaction = null;

  bool get isRecurring => transaction == null;
}

class _MonthSummary extends StatelessWidget {
  final int totalIncome;
  final int totalExpense;

  const _MonthSummary({required this.totalIncome, required this.totalExpense});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.trending_up,
                  color: AppColors.income,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: AmountDisplay(
                    cents: totalIncome,
                    showSign: true,
                    positiveColor: AppColors.income,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.trending_down,
                  color: AppColors.expense,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: AmountDisplay(
                    cents: -totalExpense,
                    showSign: true,
                    negativeColor: AppColors.expense,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final AppProvider app;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.transaction,
    required this.app,
    required this.onTap,
  });

  IconData get _icon {
    switch (transaction.type) {
      case TransactionType.income:
        return Icons.trending_up;
      case TransactionType.expense:
        return Icons.trending_down;
      case TransactionType.transfer:
        return Icons.swap_horiz;
    }
  }

  Color _color() {
    switch (transaction.type) {
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.transfer:
        return AppColors.transfer;
    }
  }

  String get _title {
    if (transaction.description.isNotEmpty) return transaction.description;
    final category = app.category.byId(transaction.categoryId);
    if (category != null) return category.name;
    return transaction.type.label;
  }

  String? get _subtitle {
    final parts = <String>[];
    final person = _personById(app.person.persons, transaction.personId);
    final account = _accountById(app.account.accounts, transaction.accountId);
    if (person != null) parts.add(person.name);
    if (account != null) parts.add(account.name);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final signedCents = transaction.type == TransactionType.expense
        ? -transaction.amount
        : transaction.amount;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: _color().withValues(alpha: 0.15),
        child: Icon(_icon, color: _color()),
      ),
      title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: _subtitle == null
          ? null
          : Text(_subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: AmountDisplay(cents: signedCents, showSign: true),
    );
  }

  Person? _personById(List<Person> persons, int? id) {
    if (id == null) return null;
    for (final p in persons) {
      if (p.id == id) return p;
    }
    return null;
  }

  Account? _accountById(List<Account> accounts, int? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }
}

class _RecurringTile extends StatelessWidget {
  final RecurringTransaction recurring;

  const _RecurringTile({required this.recurring});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = recurring.isIncome ? AppColors.income : AppColors.expense;
    final signedCents = recurring.isIncome
        ? recurring.amount
        : -recurring.amount;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(Icons.repeat, color: color),
      ),
      title: Text(
        'Recurrente · ${recurring.name}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${recurring.frequency.label} · día ${recurring.dueDay}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: AmountDisplay(cents: signedCents, showSign: true),
    );
  }
}
