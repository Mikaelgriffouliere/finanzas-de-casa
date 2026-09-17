import 'package:characters/characters.dart';

import 'entity.dart';

class Person extends Entity {
  final String name;
  final String description;
  final String color;
  final String avatar;
  final bool isActive;

  const Person({
    super.id,
    super.createdAt,
    super.updatedAt,
    required this.name,
    this.description = '',
    this.color = '',
    this.avatar = '',
    this.isActive = true,
  });

  Person copyWith({
    int? id,
    String? name,
    String? description,
    String? color,
    String? avatar,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      avatar: avatar ?? this.avatar,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get initial {
    if (name.isEmpty) return '?';
    return name.trim().characters.isEmpty ? '?' : name.trim().characters.first.toUpperCase();
  }
}
