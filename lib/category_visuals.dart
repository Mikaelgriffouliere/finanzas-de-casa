import 'package:flutter/material.dart';

import 'finance_database.dart';

/// Íconos disponibles para las categorías. La clave es la que se guarda en
/// SQLite, así los íconos siguen funcionando aunque cambie la app.
const categoryIconOptions = <String, IconData>{
  'comida': Icons.restaurant_rounded,
  'cafe': Icons.local_cafe_rounded,
  'supermercado': Icons.shopping_cart_rounded,
  'transporte': Icons.directions_bus_rounded,
  'combustible': Icons.local_gas_station_rounded,
  'hogar': Icons.home_rounded,
  'servicios': Icons.bolt_rounded,
  'salud': Icons.favorite_rounded,
  'ocio': Icons.local_activity_rounded,
  'deportes': Icons.fitness_center_rounded,
  'educacion': Icons.school_rounded,
  'libros': Icons.menu_book_rounded,
  'tecnologia': Icons.devices_rounded,
  'mascotas': Icons.pets_rounded,
  'viajes': Icons.flight_rounded,
  'regalos': Icons.card_giftcard_rounded,
  'familia': Icons.family_restroom_rounded,
  'belleza': Icons.spa_rounded,
  'musica': Icons.music_note_rounded,
  'juegos': Icons.sports_esports_rounded,
  'sueldo': Icons.work_rounded,
  'extra': Icons.add_chart_rounded,
  'inversiones': Icons.trending_up_rounded,
  'ahorros': Icons.savings_rounded,
  'impuestos': Icons.receipt_long_rounded,
  'seguros': Icons.shield_rounded,
  'tarjeta': Icons.credit_card_rounded,
  'otros': Icons.more_horiz_rounded,
};

IconData iconForCategory(String key) =>
    categoryIconOptions[key] ?? Icons.more_horiz_rounded;

const categoryColorOptions = <Color>[
  Color(0xFF155C4B),
  Color(0xFF2E7D5B),
  Color(0xFF4F78A1),
  Color(0xFF5B6F9E),
  Color(0xFF8A6C9D),
  Color(0xFFB36A8C),
  Color(0xFFC85F67),
  Color(0xFFCC6E3D),
  Color(0xFFB38723),
  Color(0xFF8D7B3F),
  Color(0xFF62736A),
  Color(0xFF3F4F49),
];

class CategoryStyle {
  const CategoryStyle({
    required this.icon,
    required this.color,
    required this.background,
  });

  factory CategoryStyle.from(FinanceCategory category) {
    final color = Color(category.color);
    return CategoryStyle(
      icon: iconForCategory(category.icon),
      color: color,
      background: Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white),
    );
  }

  final IconData icon;
  final Color color;
  final Color background;

  static const fallback = CategoryStyle(
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF62736A),
    background: Color(0xFFE9EEEB),
  );
}
