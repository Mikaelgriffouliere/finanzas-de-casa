import 'package:flutter/material.dart';

/// Paleta de marca de la aplicación. Cada paleta define el color semilla del
/// que se deriva el `ColorScheme` (Material 3) y los gradientes de identidad.
class AppPalette {
  final String id;
  final String name;
  final Color primary;

  /// Gradiente corto de marca (encabezados, botones, chips de marca).
  final List<Color> brandGradient;

  /// Gradiente hero de 3 paradas (banner de inicio / splash).
  final List<Color> heroGradient;

  const AppPalette({
    required this.id,
    required this.name,
    required this.primary,
    required this.brandGradient,
    required this.heroGradient,
  });

  /// Paleta de gráficos derivada de la semilla: 10 colores armónicos,
  /// girando el matiz y alternando luminosidad/saturación.
  List<Color> get chartPalette {
    final hsl = HSLColor.fromColor(primary);
    const hues = [0, 28, 55, 95, 145, 200, 245, 300, 330, 20];
    const saturations = [
      0.78,
      0.70,
      0.72,
      0.65,
      0.60,
      0.72,
      0.68,
      0.70,
      0.66,
      0.60,
    ];
    const lightness = [
      0.56,
      0.50,
      0.60,
      0.50,
      0.58,
      0.55,
      0.50,
      0.58,
      0.52,
      0.55,
    ];
    return List.generate(10, (i) {
      return HSLColor.fromAHSL(
        1,
        (hsl.hue + hues[i]) % 360,
        saturations[i],
        lightness[i],
      ).toColor();
    });
  }
}

class AppPalettes {
  AppPalettes._();

  /// Profesional (predeterminado): identidad "tinta + azul" de fintech.
  static const AppPalette profesional = AppPalette(
    id: 'profesional',
    name: 'Profesional',
    primary: Color(0xFF2447DB),
    brandGradient: [Color(0xFF2447DB), Color(0xFF5B8BDE)],
    heroGradient: [Color(0xFF15297F), Color(0xFF2447DB), Color(0xFF5B8BDE)],
  );

  /// Azul analítico.
  static const AppPalette analitico = AppPalette(
    id: 'analitico',
    name: 'Analítico',
    primary: Color(0xFF3B5FC9),
    brandGradient: [Color(0xFF3B5FC9), Color(0xFF5B8BDE)],
    heroGradient: [Color(0xFF243687), Color(0xFF3B5FC9), Color(0xFF6A96E3)],
  );

  /// Verde menta.
  static const AppPalette menta = AppPalette(
    id: 'menta',
    name: 'Menta',
    primary: Color(0xFF0EA79F),
    brandGradient: [Color(0xFF0EA79F), Color(0xFF46C9B4)],
    heroGradient: [Color(0xFF0A8F88), Color(0xFF21B6A6), Color(0xFF7FDCCB)],
  );

  /// Índigo eléctrico.
  static const AppPalette indigo = AppPalette(
    id: 'indigo',
    name: 'Índigo',
    primary: Color(0xFF4F5CD3),
    brandGradient: [Color(0xFF4F5CD3), Color(0xFF0FA3C5)],
    heroGradient: [Color(0xFF3E4CBF), Color(0xFF0FA3C5), Color(0xFF22C3A6)],
  );

  /// Violeta neón.
  static const AppPalette violet = AppPalette(
    id: 'violet',
    name: 'Violeta',
    primary: Color(0xFF7C3AED),
    brandGradient: [Color(0xFF7C3AED), Color(0xFFEC4899)],
    heroGradient: [Color(0xFF5B21B6), Color(0xFF8B5CF6), Color(0xFFF472B6)],
  );

  /// Esmeralda.
  static const AppPalette emerald = AppPalette(
    id: 'emerald',
    name: 'Esmeralda',
    primary: Color(0xFF0E9F6E),
    brandGradient: [Color(0xFF0E9F6E), Color(0xFF0FA3A5)],
    heroGradient: [Color(0xFF057A55), Color(0xFF10B981), Color(0xFF22C3A6)],
  );

  /// Azul océano.
  static const AppPalette ocean = AppPalette(
    id: 'ocean',
    name: 'Océano',
    primary: Color(0xFF2563EB),
    brandGradient: [Color(0xFF2563EB), Color(0xFF06B6D4)],
    heroGradient: [Color(0xFF1E40AF), Color(0xFF3B82F6), Color(0xFF06B6D4)],
  );

  /// Rosa neón.
  static const AppPalette rose = AppPalette(
    id: 'rose',
    name: 'Rosa',
    primary: Color(0xFFEC4899),
    brandGradient: [Color(0xFFEC4899), Color(0xFFA78BFA)],
    heroGradient: [Color(0xFFBE185D), Color(0xFFEC4899), Color(0xFFA78BFA)],
  );

  /// Ámbar.
  static const AppPalette amber = AppPalette(
    id: 'amber',
    name: 'Ámbar',
    primary: Color(0xFFF59E0B),
    brandGradient: [Color(0xFFF59E0B), Color(0xFFF97316)],
    heroGradient: [Color(0xFFB45309), Color(0xFFF59E0B), Color(0xFFFB923C)],
  );

  static const List<AppPalette> all = [
    profesional,
    analitico,
    menta,
    indigo,
    violet,
    emerald,
    ocean,
    rose,
    amber,
  ];

  static AppPalette byId(String id) {
    return all.firstWhere((p) => p.id == id, orElse: () => indigo);
  }
}
