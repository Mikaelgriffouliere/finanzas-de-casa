import 'package:intl/intl.dart';

/// Utilidades para manejar montos monetarios en centavos.
class MoneyUtils {
  MoneyUtils._();

  /// Convierte a centavos evitando errores de punto flotante.
  static int toCents(double amount) {
    return (amount * 100).round();
  }

  /// Convierte de centavos a "pesos con decimales".
  static double fromCents(int cents) {
    return cents / 100;
  }

  /// Formatea centavos a string con separador de miles y 2 decimales.
  static String format(int cents, {String symbol = r'$'}) {
    final value = fromCents(cents);
    final formatted = NumberFormat.currency(
      locale: 'es_AR',
      symbol: symbol,
      decimalDigits: value % 1 == 0 ? 0 : 2,
    ).format(value);
    return formatted;
  }

  /// Formatea de forma compacta: 1500000 -> $1.5M. Para gráficos.
  static String formatCompact(int cents, {String symbol = r'$'}) {
    final value = fromCents(cents);
    final abs = value.abs();
    if (abs >= 1e9) return '$symbol${(value / 1e9).toStringAsFixed(1)}B';
    if (abs >= 1e6) return '$symbol${(value / 1e6).toStringAsFixed(1)}M';
    if (abs >= 1e3) return '$symbol${(value / 1e3).toStringAsFixed(1)}K';
    return '$symbol${value.toStringAsFixed(0)}';
  }
}

/// Utilidades de fecha.
class DateUtils {
  DateUtils._();

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);
  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  static DateTime endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0, 23, 59, 59);
  static DateTime firstDayOfPreviousMonth(DateTime d) =>
      DateTime(d.year, d.month - 1, 1);
  static DateTime lastDayOfPreviousMonth(DateTime d) =>
      DateTime(d.year, d.month, 0, 23, 59, 59);

  static String monthName(DateTime d) =>
      DateFormat('MMMM').format(d).toLowerCase().capitalizeFirst();

  static String shortDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
  static String shortDateTime(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

  /// Nombre del mes capitalizado.
  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);
}

extension StringX on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}