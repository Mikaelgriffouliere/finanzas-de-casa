import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'Finanzas en orden';
  static const String dbName = 'finanzas_hogar.db';
  static const int dbVersion = 1;

  // Colores de avatar por defecto (tonos pastel armoniosos)
  static const List<String> personColors = [
    '#7FAE96',
    '#9DB6D4',
    '#E4B79E',
    '#AFA3C9',
    '#D29E97',
    '#9CC2A5',
    '#D9C08C',
    '#CBA3AC',
  ];

  // Avatares rápidos (emojis) para personas del hogar
  static const List<String> avatarEmojis = [
    '👤', '👩', '👨', '👧', '👦', '👵', '👴', '🧑', '👱‍♀️', '👱‍♂️',
    '🧔', '👩‍🦱', '👨‍🦱', '👩‍🦰', '👨‍🦰', '👩🏻', '👨🏻', '🐱', '🐶', '🐰',
  ];

  // Prefijos del campo avatar de Person
  static const String avatarEmojiPrefix = 'emoji:';
  static const String avatarPhotoPrefix = 'photo:';

  static Color parseColor(String hex) {
    var clean = hex.replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    return Color(int.parse('0x$clean'));
  }

  static String colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static IconData iconData(String name) {
    return _iconMap[name] ?? Icons.category;
  }

  static const Map<String, IconData> _iconMap = {
    'home': Icons.home,
    'medical_services': Icons.medical_services,
    'restaurant': Icons.restaurant,
    'directions_bus': Icons.directions_bus,
    'school': Icons.school,
    'celebration': Icons.celebration,
    'movie': Icons.movie,
    'pets': Icons.pets,
    'checkroom': Icons.checkroom,
    'receipt_long': Icons.receipt_long,
    'account_balance': Icons.account_balance,
    'payments': Icons.payments,
    'category': Icons.category,
    'work': Icons.work,
    'schedule': Icons.schedule,
    'card_giftcard': Icons.card_giftcard,
    'verified': Icons.verified,
    'storefront': Icons.storefront,
    'percent': Icons.percent,
    'trending_up': Icons.trending_up,
  };
}

class DefaultCategories {
  DefaultCategories._();

  static const List<({String name, String icon})> categories = [
    (name: 'Hogar', icon: 'home'),
    (name: 'Salud', icon: 'medical_services'),
    (name: 'Alimentación', icon: 'restaurant'),
    (name: 'Transporte', icon: 'directions_bus'),
    (name: 'Educación', icon: 'school'),
    (name: 'Ocio', icon: 'celebration'),
    (name: 'Entretenimiento', icon: 'movie'),
    (name: 'Mascotas', icon: 'pets'),
    (name: 'Ropa', icon: 'checkroom'),
    (name: 'Impuestos', icon: 'receipt_long'),
    (name: 'Deudas', icon: 'account_balance'),
    (name: 'Finanzas', icon: 'payments'),
    (name: 'Otros', icon: 'category'),
  ];

  static const List<({String name, String icon})> incomeCategories = [
    (name: 'Sueldo', icon: 'payments'),
    (name: 'Trabajo independiente', icon: 'work'),
    (name: 'Horas extras', icon: 'schedule'),
    (name: 'Bonificaciones', icon: 'card_giftcard'),
    (name: 'Aguinaldo', icon: 'verified'),
    (name: 'Ventas', icon: 'storefront'),
    (name: 'Intereses', icon: 'percent'),
    (name: 'Inversiones', icon: 'trending_up'),
    (name: 'Otros', icon: 'category'),
  ];
}

class TableNames {
  TableNames._();

  static const String persons = 'persons';
  static const String accounts = 'accounts';
  static const String categories = 'categories';
  static const String subcategories = 'subcategories';
  static const String transactions = 'transactions';
  static const String recurringTransactions = 'recurring_transactions';
  static const String budgets = 'budgets';
  static const String savingsGoals = 'savings_goals';
  static const String savingsMovements = 'savings_movements';
  static const String settings = 'settings';
}