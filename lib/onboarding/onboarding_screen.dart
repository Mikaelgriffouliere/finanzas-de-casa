import 'package:flutter/material.dart';

import 'onboarding_steps.dart';

/// Introducción animada de primera ejecución.
///
/// Es un módulo independiente: solo recibe un callback para avisar que se
/// terminó (ya sea con "Comenzar" o con "Saltar"). La persistencia la resuelve
/// quien lo integra, manteniendo separadas las responsabilidades.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onFinished, super.key});

  /// Se llama al completar o al saltar. Debe persistir que la intro se vio.
  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  int _page = 0;
  bool get _isLast => _page == onboardingSteps.length - 1;
  bool get _isFirst => _page == 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si el sistema pide reducir movimiento, mostramos todo sin animación.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _animatePage() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller
      ..reset()
      ..forward();
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= onboardingSteps.length) return;
    setState(() => _page = index);
    _animatePage();
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_isLast) {
      widget.onFinished();
      return;
    }
    _goTo(_page + 1);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final step = onboardingSteps[_page];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton(
                  onPressed: widget.onFinished,
                  child: const Text('Saltar'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _page = index);
                  _animatePage();
                },
                itemCount: onboardingSteps.length,
                itemBuilder: (context, index) => Semantics(
                  label: 'Paso ${index + 1} de ${onboardingSteps.length}',
                  child: _StepContent(
                    step: onboardingSteps[index],
                    index: index,
                    fade: _fade,
                    slide: _slide,
                    reduceMotion: reduceMotion,
                  ),
                ),
              ),
            ),
            Semantics(
              label: 'Paso $_page de ${onboardingSteps.length}',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < onboardingSteps.length; i++)
                    _ProgressDot(
                      active: i == _page,
                      reduceMotion: reduceMotion,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Row(
                children: [
                  if (!_isFirst)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _goTo(_page - 1),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Anterior'),
                      ),
                    ),
                  if (!_isFirst) const SizedBox(width: 12),
                  Expanded(
                    flex: _isFirst ? 1 : 2,
                    child: FilledButton.icon(
                      onPressed: _next,
                      icon: Icon(
                        _isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(_isLast ? 'Comenzar' : 'Siguiente'),
                      style: FilledButton.styleFrom(
                        backgroundColor: step.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    required this.step,
    required this.index,
    required this.fade,
    required this.slide,
    required this.reduceMotion,
  });

  final OnboardingStep step;
  final int index;
  final Animation<double> fade;
  final Animation<Offset> slide;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: onboardingIllustration(index),
          ),
          const SizedBox(height: 34),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF616161)),
          ),
        ],
      ),
    );

    if (reduceMotion) return content;

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: content),
    );
  }
}

class _ProgressDot extends StatelessWidget {
  const _ProgressDot({required this.active, required this.reduceMotion});

  final bool active;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? color : color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
