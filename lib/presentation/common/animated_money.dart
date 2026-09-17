import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Monto con animación de conteo (count-up). Anima desde $0 al valor destino
/// y transiciona suavemente cuando el monto cambia.
class AnimatedMoney extends StatelessWidget {
  final int cents;
  final TextStyle? style;
  final TextAlign? textAlign;
  final String symbol;
  final Duration duration;
  final Curve curve;

  const AnimatedMoney({
    super.key,
    required this.cents,
    this.style,
    this.textAlign,
    this.symbol = r'$',
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
  });

  static final Map<String, NumberFormat> _formats = {};

  static String _format(int cents, String symbol) {
    final value = cents / 100;
    final key = '$symbol|${value % 1 == 0 ? 0 : 2}';
    final format = _formats.putIfAbsent(
      key,
      () => NumberFormat.currency(
        locale: 'es_AR',
        symbol: symbol,
        decimalDigits: value % 1 == 0 ? 0 : 2,
      ),
    );
    return format.format(value);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: cents),
      duration: duration,
      curve: curve,
      builder: (context, value, _) =>
          Text(_format(value, symbol), style: style, textAlign: textAlign),
    );
  }
}
