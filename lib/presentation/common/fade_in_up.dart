import 'package:flutter/material.dart';

/// Aparece su hijo con un fade + desplazamiento vertical ascendente,
/// con un [delay] opcional para lograr entradas escalonadas.
class FadeInUp extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offset;

  const FadeInUp({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 480),
    this.delay = Duration.zero,
    this.offset = 14,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds + delay.inMilliseconds;
    final start = delay.inMilliseconds / totalMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, offset * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
