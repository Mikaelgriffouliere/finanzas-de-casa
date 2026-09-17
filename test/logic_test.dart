import 'package:finanzas_hogar/domain/entities/savings_goal.dart';
import 'package:finanzas_hogar/domain/services/statistics_service.dart';
import 'package:finanzas_hogar/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyUtils', () {
    test('toCents convierte correctamente sin errores de punto flotante', () {
      expect(MoneyUtils.toCents(1500000.0), 150000000);
      expect(MoneyUtils.toCents(25.0), 2500);
      expect(MoneyUtils.toCents(0.1), 10);
      expect(MoneyUtils.toCents(1234.56), 123456);
    });

    test('fromCents convierte de vuelta', () {
      expect(MoneyUtils.fromCents(150000000), 1500000.0);
      expect(MoneyUtils.fromCents(2500), 25.0);
      expect(MoneyUtils.fromCents(0), 0.0);
    });

    test('format formatea con separador de miles', () {
      expect(MoneyUtils.format(150000000), contains('1.500.000'));
      expect(MoneyUtils.format(2500), contains('25'));
    });

    test('formatCompact para gráficos', () {
      expect(MoneyUtils.formatCompact(150000000), contains('1.5M'));
      expect(MoneyUtils.formatCompact(250000), contains('2.5K'));
      expect(MoneyUtils.formatCompact(9900), contains('9'));
    });
  });

  group('DateUtils', () {
    test('startOfDay normaliza a medianoche', () {
      final d = DateTime(2026, 9, 8, 15, 30);
      final s = DateUtils.startOfDay(d);
      expect(s.hour, 0);
      expect(s.minute, 0);
      expect(s.day, 8);
    });

    test('startOfMonth devuelve el primer día', () {
      final d = DateTime(2026, 9, 20);
      expect(DateUtils.startOfMonth(d), DateTime(2026, 9, 1));
    });

    test('endOfMonth devuelve el último día', () {
      final d = DateTime(2026, 9, 5);
      final e = DateUtils.endOfMonth(d);
      expect(e.day, 30);
      expect(e.month, 9);
    });
  });

  group('SavingsGoal', () {
    test('progress calcula porcentaje correctamente', () {
      final goal = SavingsGoal(
        name: 'Fondo',
        targetAmount: 300000000,
        currentAmount: 120000000,
      );
      expect(goal.progress, closeTo(0.4, 0.001));
    });

    test('progress nunca supera 1', () {
      final goal = SavingsGoal(
        name: 'Over',
        targetAmount: 1000,
        currentAmount: 5000,
      );
      expect(goal.progress, 1.0);
    });

    test('progress es 0 cuando target es 0', () {
      final goal = SavingsGoal(name: 'Cero', targetAmount: 0);
      expect(goal.progress, 0);
    });
  });

  group('MonthlySummary', () {
    test('calcula ahorro y disponible correctamente', () {
      const summary = MonthlySummary(
        income: 150000000,
        expense: 95000000,
        savingsTransferIn: 10000000,
      );
      expect(summary.savings, 45000000);
      expect(summary.available, 55000000);
    });

    test('tasa de ahorro', () {
      const summary = MonthlySummary(income: 100, expense: 60);
      expect(summary.savingsRate, closeTo(0.4, 0.001));
    });

    test('tasa de ahorro es 0 si no hay ingresos', () {
      const summary = MonthlySummary(income: 0, expense: 100);
      expect(summary.savingsRate, 0.0);
    });

    test('evolución respecto al mes anterior', () {
      const summary = MonthlySummary(
        income: 120,
        expense: 132,
        previousExpense: 100,
      );
      expect(summary.expenseDeltaPercent, closeTo(32.0, 0.01));
    });
  });

  group('PersonContribution', () {
    test('guarda nombre, monto y porcentaje', () {
      const c = PersonContribution(
        name: 'Yo',
        amount: 120000000,
        percent: 0.6,
      );
      expect(c.name, 'Yo');
      expect(c.amount, 120000000);
      expect(c.percent, 0.6);
    });
  });
}
