import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../presentation/providers/app_provider.dart';

/// Bloquea el acceso a la app cuando hay un PIN configurado.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _localAuth = LocalAuthentication();
  final List<String> _pin = [];
  bool _error = false;
  bool _busy = false;
  bool? _biometricAvailable;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    var available = false;
    try {
      available =
          await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics;
    } catch (_) {
      available = false;
    }
    if (mounted) setState(() => _biometricAvailable = available);
  }

  Future<void> _tryBiometrics() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Desbloqueá Finanzas en orden',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (ok && mounted) {
        context.read<AppProvider>().security.unlock();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo usar la biometría')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _press(String digit) {
    if (_busy || _pin.length >= 4) return;
    setState(() {
      _error = false;
      _pin.add(digit);
    });
  }

  void _backspace() {
    if (_pin.isEmpty || _busy) return;
    setState(() {
      _error = false;
      _pin.removeLast();
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final pin = _pin.join();
    final ok = await context.read<AppProvider>().security.unlockWithPin(pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _error = true;
        _pin.clear();
        HapticFeedback.vibrate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final biometricActive =
        _biometricAvailable == true &&
        context.watch<AppProvider>().security.biometricEnabled;
    final canConfirm = _pin.length == 4 && !_busy;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BrandHeader(theme: theme),
                  const SizedBox(height: 20),
                  _PinDots(length: _pin.length, error: _error),
                  SizedBox(
                    height: 26,
                    child: Center(
                      child: Text(
                        _error
                            ? 'PIN incorrecto, volvé a intentar'
                            : 'Ingresá tu PIN de 4 dígitos',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _error
                              ? AppColors.expense
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _Keypad(
                    onDigit: _press,
                    onBackspace: _backspace,
                    onConfirm: canConfirm ? _submit : null,
                    showBiometric: biometricActive,
                    onBiometric: _tryBiometrics,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: AppColors.brandGradient),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.pie_chart, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 10),
        Text(
          'Finanzas en orden',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Ingresá tu PIN para continuar',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PinDots extends StatelessWidget {
  final int length;
  final bool error;

  const _PinDots({required this.length, required this.error});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: error
                    ? AppColors.expense
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              color: error
                  ? AppColors.expense
                  : i < length
                  ? AppColors.primary
                  : Colors.transparent,
            ),
          ),
          if (i < 3) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onConfirm;
  final bool showBiometric;
  final VoidCallback? onBiometric;

  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onConfirm,
    required this.showBiometric,
    required this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 276),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < 3; r++)
            _row([
              for (var c = 1; c <= 3; c++)
                _KeyButton(
                  label: '${r * 3 + c}',
                  onTap: () => onDigit('${r * 3 + c}'),
                ),
            ]),
          _row([
            if (showBiometric)
              _KeyButton(icon: Icons.fingerprint, onTap: onBiometric),
            _KeyButton(label: '0', onTap: () => onDigit('0')),
            _KeyButton(icon: Icons.backspace_outlined, onTap: onBackspace),
            _KeyButton(
              icon: Icons.check_circle,
              onTap: onConfirm,
              highlight: onConfirm != null,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _row(List<Widget> keys) {
    final children = <Widget>[];
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 12));
      children.add(keys[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool highlight;

  const _KeyButton({this.label, this.icon, this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = onTap == null;
    final Color background;
    final Color foreground;
    if (highlight) {
      background = AppColors.income;
      foreground = Colors.white;
    } else {
      background = theme.colorScheme.surfaceContainerHighest;
      foreground = isDisabled
          ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
          : theme.colorScheme.onSurface;
    }
    return SizedBox(
      width: 60,
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: isDisabled ? null : onTap,
            child: Center(
              child: icon != null
                  ? Icon(
                      icon,
                      size: 24,
                      color: highlight ? Colors.white : AppColors.primary,
                    )
                  : Text(
                      label!,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
