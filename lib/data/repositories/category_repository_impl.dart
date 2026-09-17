import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/subcategory.dart';
import '../../../domain/repositories/category_repository.dart';
import '../database/app_database.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final AppDatabase _db = AppDatabase.instance;

  @override
  Future<List<Category>> getAllCategories() async {
    final db = await _db.getDatabase();
    final result = await db.query(TableNames.categories, orderBy: 'name');
    return result.map(_fromRow).toList();
  }

  @override
  Future<Category?> getCategoryById(int id) async {
    final db = await _db.getDatabase();
    final result = await db.query(
      TableNames.categories,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : _fromRow(result.first);
  }

  @override
  Future<Category> createCategory(Category category, {bool isIncome = false}) async {
    final db = await _db.getDatabase();
    final id = await db.insert(
      TableNames.categories,
      _toRow(category, isIncome: isIncome),
    );
    return category.copyWith(id: id, createdAt: DateTime.now());
  }

  @override
  Future<Category> updateCategory(Category category) async {
    final db = await _db.getDatabase();
    final row = _toRow(category);
    row['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      TableNames.categories,
      row,
      where: 'id = ?',
      whereArgs: [category.id],
    );
    return category.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<void> deleteCategory(int id) async {
    final db = await _db.getDatabase();
    await db.delete(TableNames.categories, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Subcategory>> getAllSubcategories() async {
    final db = await _db.getDatabase();
    final result = await db.query(TableNames.subcategories, orderBy: 'name');
    return result.map(_fromSubcategoryRow).toList();
  }

  @override
  Future<List<Subcategory>> getSubcategoriesByCategory(int categoryId) async {
    final db = await _db.getDatabase();
    final result = await db.query(
      TableNames.subcategories,
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'name',
    );
    return result.map(_fromSubcategoryRow).toList();
  }

  @override
  Future<Subcategory> createSubcategory(Subcategory subcategory) async {
    final db = await _db.getDatabase();
    final id = await db.insert(
      TableNames.subcategories,
      _toSubcategoryRow(subcategory),
    );
    return subcategory.copyWith(id: id, createdAt: DateTime.now());
  }

  @override
  Future<Subcategory> updateSubcategory(Subcategory subcategory) async {
    final db = await _db.getDatabase();
    final row = _toSubcategoryRow(subcategory);
    row['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      TableNames.subcategories,
      row,
      where: 'id = ?',
      whereArgs: [subcategory.id],
    );
    return subcategory.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<void> deleteSubcategory(int id) async {
    final db = await _db.getDatabase();
    await db.delete(TableNames.subcategories, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Category>> getByType({required bool isIncome}) async {
    final db = await _db.getDatabase();
    final result = await db.query(
      TableNames.categories,
      where: 'is_income = ?',
      whereArgs: [isIncome ? 1 : 0],
      orderBy: 'name',
    );
    return result.map(_fromRow).toList();
  }

  Future<void> setType(int categoryId, {required bool isIncome}) async {
    final db = await _db.getDatabase();
    await db.update(
      TableNames.categories,
      {'is_income': isIncome ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }

  Map<String, dynamic> _toRow(Category c, {bool isIncome = false}) {
    return {
      'name': c.name,
      'icon': c.icon,
      'color': c.color,
      'is_default': c.isDefault ? 1 : 0,
      'is_income': isIncome ? 1 : 0,
      'created_at': c.createdAt?.toIso8601String(),
      'updated_at': c.updatedAt?.toIso8601String(),
    };
  }

  Category _fromRow(Map<String, dynamic> row) {
    return Category(
      id: row['id'] as int,
      name: row['name'] as String,
      icon: row['icon'] as String?,
      color: row['color'] as String?,
      isDefault: (row['is_default'] as int) == 1,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'])
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> _toSubcategoryRow(Subcategory s) {
    return {
      'category_id': s.categoryId,
      'name': s.name,
      'icon': s.icon,
      'color': s.color,
      'is_default': s.isDefault ? 1 : 0,
      'created_at': s.createdAt?.toIso8601String(),
      'updated_at': s.updatedAt?.toIso8601String(),
    };
  }

  Subcategory _fromSubcategoryRow(Map<String, dynamic> row) {
    return Subcategory(
      id: row['id'] as int,
      categoryId: row['category_id'] as int,
      name: row['name'] as String,
      icon: row['icon'] as String?,
      color: row['color'] as String?,
      isDefault: (row['is_default'] as int) == 1,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'])
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'])
          : null,
    );
  }
}
