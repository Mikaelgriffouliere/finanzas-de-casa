import 'entity.dart';

class Category extends Entity {
  final String name;
  final String? icon;
  final String? color;
  final bool isDefault;

  const Category({
    super.id,
    super.createdAt,
    super.updatedAt,
    required this.name,
    this.icon,
    this.color,
    this.isDefault = false,
  });

  Category copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
