import 'package:flutter/foundation.dart';

import '../../../domain/entities/person.dart';
import '../../../data/repositories/person_repository_impl.dart';

class PersonProvider extends ChangeNotifier {
  final PersonRepositoryImpl _repository;

  List<Person> _persons = [];
  List<Person> get persons => List.unmodifiable(_persons);

  PersonProvider({PersonRepositoryImpl? repository})
      : _repository = repository ?? PersonRepositoryImpl();

  Future<void> loadAll() async {
    try {
      _persons = await _repository.getAll();
      notifyListeners();
    } catch (e, stack) {
      debugPrint('PersonProvider.loadAll error: $e\n$stack');
    }
  }

  Future<void> add(Person person) async {
    try {
      final created = await _repository.create(person);
      _persons.add(created);
      notifyListeners();
    } catch (e, stack) {
      debugPrint('PersonProvider.add error: $e\n$stack');
    }
  }

  Future<void> update(Person person) async {
    try {
      final updated = await _repository.update(person);
      final index = _persons.indexWhere((p) => p.id == updated.id);
      if (index != -1) {
        _persons[index] = updated;
        notifyListeners();
      }
    } catch (e, stack) {
      debugPrint('PersonProvider.update error: $e\n$stack');
    }
  }

  Future<void> delete(int id) async {
    try {
      await _repository.delete(id);
      _persons.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e, stack) {
      debugPrint('PersonProvider.delete error: $e\n$stack');
    }
  }
}
