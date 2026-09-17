import 'entity.dart';

class Subcategory extends Entity {
  final int categoryId;
  final String name;
  final String? icon;
  final String? color;
  final bool isDefault;

  const Subcategory({
    super.id,
    super.createdAt,
    super.updatedAt,
    required this.categoryId,
    required this.name,
    this.icon,
    this.color,
    this.isDefault = false,
  });

  Subcategory copyWith({
    int? id,
    int? categoryId,
    String? name,
    String? icon,
    String? color,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subcategory(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
