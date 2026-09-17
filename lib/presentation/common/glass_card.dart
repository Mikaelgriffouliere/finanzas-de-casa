import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Panel sólido con estética premium: tarjeta blanca/navy con borde fino
/// (hairline) y sombra suave. Unifica el lenguaje visual de la app.
///
/// Usa [Material] + [Ink] para que el ripple de los elementos interactivos
/// (ListTile, InkWell, etc.) se pinte sobre la propia tarjeta.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color tint;
  final double tintOpacity;

  GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20,
    this.tintOpacity = 0.06,
    Color? tint,
  }) : tint = tint ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? scheme.surfaceContainerLow : Colors.white;
    final border = Border.all(
      color: scheme.outlineVariant.withValues(alpha: isDark ? 1.0 : 0.8),
    );

    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
      blurRadius: 20,
      offset: const Offset(0, 8),
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [shadow],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            border: border,
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardColor,
                Color.alphaBlend(
                  tint.withValues(alpha: tintOpacity),
                  cardColor,
                ),
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
