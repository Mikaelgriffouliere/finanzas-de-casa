import '../entities/category.dart';
import '../entities/subcategory.dart';

abstract class CategoryRepository {
  Future<List<Category>> getAllCategories();
  Future<Category?> getCategoryById(int id);
  Future<Category> createCategory(Category category);
  Future<Category> updateCategory(Category category);
  Future<void> deleteCategory(int id);

  Future<List<Subcategory>> getAllSubcategories();
  Future<List<Subcategory>> getSubcategoriesByCategory(int categoryId);
  Future<Subcategory> createSubcategory(Subcategory subcategory);
  Future<Subcategory> updateSubcategory(Subcategory subcategory);
  Future<void> deleteSubcategory(int id);
}