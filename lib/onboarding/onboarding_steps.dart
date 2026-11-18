import 'package:flutter/material.dart';

/// Contenido de cada paso de la introducción. El índice en la lista es el
/// orden en que se muestran.
class OnboardingStep {
  const OnboardingStep({
    required this.title,
    required this.description,
    required this.accent,
  });

  final String title;
  final String description;
  final Color accent;
}

const onboardingSteps = <OnboardingStep>[
  OnboardingStep(
    title: 'Bienvenido a tus finanzas',
    description: 'Organizá tu dinero y tomá el control de tus finanzas desde un solo lugar',
    accent: Color(0xFF155C4B),
  ),
  OnboardingStep(
    title: 'Todo tu dinero organizado',
    description: 'Registrá tus ingresos, gastos y transferencias fácilmente',
    accent: Color(0xFF2E7D5B),
  ),
  OnboardingStep(
    title: 'Controlá tus gastos',
    description: 'Creá presupuestos y conocé cuánto podés gastar',
    accent: Color(0xFF2E5A88),
  ),
  OnboardingStep(
    title: 'Alcanzá tus objetivos',
    description: 'Planificá tus ahorros y seguí tu progreso',
    accent: Color(0xFFB38723),
  ),
];

/// Ilustración animada correspondiente a un paso. Se usa composición nativa
/// de Flutter para no agregar dependencias ni assets externos.
Widget onboardingIllustration(int index) => switch (index) {
  0 => const _WelcomeIllustration(),
  1 => const _MovementsIllustration(),
  2 => const _BudgetIllustration(),
  3 => const _GoalsIllustration(),
  _ => const SizedBox.shrink(),
};

/// Entrada escalonada con fade y desplazamiento, sin animaciones infinitas.
class _FloatIn extends StatelessWidget {
  const _FloatIn({
    required this.delay,
    required this.offset,
    required this.child,
  });

  final double delay;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 650),
    curve: Interval(delay, 1, curve: Curves.easeOutBack),
    builder: (context, value, child) {
      final t = value.clamp(0.0, 1.0);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(offset.dx * (1 - t), offset.dy * (1 - t)),
          child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
        ),
      );
    },
    child: child,
  );
}

Widget _coin(IconData icon, Color color) => Container(
  width: 40,
  height: 40,
  decoration: BoxDecoration(
    color: Colors.white,
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: color.withValues(alpha: 0.22),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Icon(icon, color: color, size: 22),
);

class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 200,
    height: 170,
    child: Stack(
      alignment: Alignment.center,
      children: [
        _FloatIn(
          delay: 0,
          offset: const Offset(0, 24),
          child: Container(
            width: 150,
            height: 104,
            decoration: BoxDecoration(
              color: const Color(0xFF155C4B),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF155C4B).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 14,
                  top: 16,
                  child: Container(
                    width: 30,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const Positioned(
                  left: 16,
                  bottom: 18,
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 20,
                  child: Text(
                    '\$\$\$',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 2,
          top: 12,
          child: _FloatIn(
            delay: 0.25,
            offset: const Offset(-28, -18),
            child: _coin(Icons.attach_money_rounded, const Color(0xFF2E7D5B)),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 14,
          child: _FloatIn(
            delay: 0.42,
            offset: const Offset(28, 18),
            child: _coin(Icons.trending_up_rounded, const Color(0xFFB38723)),
          ),
        ),
      ],
    ),
  );
}

class _MovementsIllustration extends StatelessWidget {
  const _MovementsIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    height: 180,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FloatIn(
          delay: 0,
          offset: const Offset(-24, 0),
          child: _movementRow(
            Icons.arrow_downward_rounded,
            'Ingresos',
            const Color(0xFF155C4B),
          ),
        ),
        const SizedBox(height: 8),
        _FloatIn(
          delay: 0.18,
          offset: const Offset(24, 0),
          child: _movementRow(
            Icons.arrow_upward_rounded,
            'Gastos',
            const Color(0xFFC85F67),
          ),
        ),
        const SizedBox(height: 12),
        _FloatIn(
          delay: 0.34,
          offset: const Offset(0, 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _bar(0.65, const Color(0xFF155C4B)),
              const SizedBox(width: 8),
              _bar(0.95, const Color(0xFF4F78A1)),
              const SizedBox(width: 8),
              _bar(0.45, const Color(0xFFB38723)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _movementRow(IconData icon, String label, Color color) =>
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                radius: 16,
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded, color: color, size: 18),
            ],
          ),
        ),
      );

  Widget _bar(double fraction, Color color) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: fraction),
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Container(
      width: 26,
      height: 8 + 44 * value,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}

class _BudgetIllustration extends StatelessWidget {
  const _BudgetIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    height: 170,
    child: Stack(
      alignment: Alignment.center,
      children: [
        _FloatIn(
          delay: 0,
          offset: const Offset(0, 18),
          child: SizedBox(
            width: 130,
            height: 130,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 0.72),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 14,
                    color: const Color(0xFFE8EEF5),
                  ),
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 14,
                    color: const Color(0xFF2E5A88),
                    strokeCap: StrokeCap.round,
                  ),
                  Text(
                    '${(value * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E5A88),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 24,
          child: _FloatIn(
            delay: 0.3,
            offset: const Offset(-20, 0),
            child: _chip(Icons.restaurant_rounded, const Color(0xFFCC6E3D)),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 22,
          child: _FloatIn(
            delay: 0.45,
            offset: const Offset(20, 0),
            child: _chip(Icons.home_rounded, const Color(0xFF8A6C9D)),
          ),
        ),
      ],
    ),
  );

  Widget _chip(IconData icon, Color color) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.22),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

class _GoalsIllustration extends StatelessWidget {
  const _GoalsIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 230,
    height: 170,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            _FloatIn(
              delay: 0,
              offset: const Offset(0, 18),
              child: Container(
                width: 120,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFFB38723).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFB38723).withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.savings_rounded,
                    size: 48,
                    color: Color(0xFFB38723),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 2,
              child: _FloatIn(
                delay: 0.35,
                offset: const Offset(0, -28),
                child: _coin(
                  Icons.attach_money_rounded,
                  const Color(0xFF155C4B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _FloatIn(
          delay: 0.5,
          offset: const Offset(0, 14),
          child: Container(
            width: 180,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEF5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 0.8),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFB38723),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
