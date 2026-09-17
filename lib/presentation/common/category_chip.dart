import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class CategoryChip extends StatelessWidget {
  final String name;
  final String? icon;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const CategoryChip({
    super.key,
    required this.name,
    this.icon,
    this.selected = false,
    this.onTap,
    this.onDelete,
  });

  IconData _iconData() {
    if (icon == null || icon!.isEmpty) return Icons.category;
    return AppConstants.iconData(icon!);
  }

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(_iconData(), size: 18),
      label: Text(name),
      selected: selected,
      onSelected: (_) => onTap?.call(),
      onDeleted: onDelete,
      visualDensity: VisualDensity.compact,
    );
  }
}
