import 'package:flutter/foundation.dart' hide Category;

import '../../../domain/entities/category.dart';
import '../../../domain/entities/subcategory.dart';
import '../../../data/repositories/category_repository_impl.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryRepositoryImpl _repository;

  List<Category> _expenseCategories = [];
  List<Category> get expenseCategories => List.unmodifiable(_expenseCategories);

  List<Category> _incomeCategories = [];
  List<Category> get incomeCategories => List.unmodifiable(_incomeCategories);

  List<Subcategory> _subcategories = [];
  List<Subcategory> get subcategories => List.unmodifiable(_subcategories);

  CategoryProvider({CategoryRepositoryImpl? repository})
      : _repository = repository ?? CategoryRepositoryImpl();

  Future<void> loadAll() async {
    try {
      _expenseCategories = await _repository.getByType(isIncome: false);
      _incomeCategories = await _repository.getByType(isIncome: true);
      _subcategories = await _repository.getAllSubcategories();
      notifyListeners();
    } catch (e, stack) {
      debugPrint('CategoryProvider.loadAll error: $e\n$stack');
    }
  }

  Future<void> add(Category category, {bool isIncome = false}) async {
    try {
      final created = await _repository.createCategory(
        category,
        isIncome: isIncome,
      );
      if (isIncome) {
        _incomeCategories.add(created);
      } else {
        _expenseCategories.add(created);
      }
      notifyListeners();
    } catch (e, stack) {
      debugPrint('CategoryProvider.add error: $e\n$stack');
    }
  }

  Future<void> update(Category category, {bool isIncome = false}) async {
    try {
      final updated = await _repository.updateCategory(category);
      if (isIncome) {
        await _repository.setType(updated.id!, isIncome: true);
      }
      final expenseIndex = _expenseCategories.indexWhere((c) => c.id == updated.id);
      if (expenseIndex != -1) {
        _expenseCategories[expenseIndex] = updated;
      }
      final incomeIndex = _incomeCategories.indexWhere((c) => c.id == updated.id);
      if (incomeIndex != -1) {
        _incomeCategories[incomeIndex] = updated;
      }
      notifyListeners();
    } catch (e, stack) {
      debugPrint('CategoryProvider.update error: $e\n$stack');
    }
  }

  Future<void> delete(int id) async {
    try {
      await _repository.deleteCategory(id);
      _expenseCategories.removeWhere((c) => c.id == id);
      _incomeCategories.removeWhere((c) => c.id == id);
      _subcategories.removeWhere((s) => s.categoryId == id);
      notifyListeners();
    } catch (e, stack) {
      debugPrint('CategoryProvider.delete error: $e\n$stack');
    }
  }

  Future<List<Subcategory>> loadByCategory(int categoryId) async {
    final result = await _repository.getSubcategoriesByCategory(categoryId);
    _subcategories = result;
    notifyListeners();
    return result;
  }

  Future<void> addSubcategory(Subcategory subcategory) async {
    try {
      final created = await _repository.createSubcategory(subcategory);
      _subcategories.add(created);
      notifyListeners();
    } catch (e, stack) {
      debugPrint('CategoryProvider.addSubcategory error: $e\n$stack');
    }
  }

  Future<void> updateSubcategory(Subcategory subcategory) async {
    try {
      final updated = await _repository.updateSubcategory(subcategory);
      final index = _subcategories.indexWhere((s) => s.id == updated.id);
      if (index != -1) {
        _subcategories[index] = updated;
        notifyListeners();
      }
    } catch (e, stack) {
      debugPrint('CategoryProvider.updateSubcategory error: $e\n$stack');
    }
  }

  Future<void> deleteSubcategory(int id) async {
    try {
      await _repository.deleteSubcategory(id);
      _subcategories.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (e, stack) {
      debugPrint('CategoryProvider.deleteSubcategory error: $e\n$stack');
    }
  }

  Category? byId(int? id) {
    if (id == null) return null;
    for (final category in _expenseCategories) {
      if (category.id == id) return category;
    }
    for (final category in _incomeCategories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Subcategory? subcategoryById(int? id) {
    if (id == null) return null;
    for (final s in _subcategories) {
      if (s.id == id) return s;
    }
    return null;
  }
}
