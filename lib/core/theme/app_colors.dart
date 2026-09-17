import 'package:flutter/material.dart';

import 'app_palettes.dart';

/// Identidad visual "Fintech moderna": acentos eléctricos sobre superficies
/// limpias, jerarquía clara y alto contraste. Los colores de marca siguen la
/// [AppPalette] seleccionada; los semánticos (ingresos/gastos/etc.) se
/// mantienen fijos por su significado.
class AppColors {
  AppColors._();

  static AppPalette _current = AppPalettes.profesional;

  /// Sincroniza los colores de marca con la paleta activa.
  static void use(AppPalette palette) => _current = palette;

  // -- Marca / primario (dinámicos por paleta) ------------------------------
  static Color get primary => _current.primary;
  static Color get secondary => _current.brandGradient.last;
  static List<Color> get brandGradient => _current.brandGradient;
  static List<Color> get heroGradient => _current.heroGradient;
  static List<Color> get chartPalette => _current.chartPalette;

  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onTertiary = Color(0xFFFFFFFF);

  // -- Semánticos ----------------------------------------------------------
  static const Color income = Color(0xFF1FB98A); // verde esmeralda
  static const Color expense = Color(0xFFEF6B8C); // rosa coral
  static const Color transfer = Color(0xFF4D9DE8); // azul cielo
  static const Color warning = Color(0xFFF0A437); // ámbar
  static const Color slate = Color(0xFF64748B); // gris azulado

  static const Color success = Color(0xFF1FB98A);
  static const Color highlight = Color(0xFF8B5CF6);
  static const Color info = Color(0xFF4D9DE8);

  // -- Fondos y superficies ------------------------------------------------
  static const Color background = Color(0xFFF3F5FC); // azul hielo
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLow = Color(0xFFEAEEF8);
  static const Color surfaceHigh = Color(0xFFE0E5F2);

  static const Color backgroundDark = Color(0xFF080C1A); // azul medianoche
  static const Color surfaceDark = Color(0xFF0F1526);
  static const Color surfaceDarkLow = Color(0xFF151C30);
  static const Color surfaceDarkHigh = Color(0xFF1D2640);

  static const Color outline = Color(0xFFC9D0E4);
}
