import '../entities/person.dart';

abstract class PersonRepository {
  Future<List<Person>> getAll({bool onlyActive = false});
  Future<Person?> getById(int id);
  Future<Person> create(Person person);
  Future<Person> update(Person person);
  Future<void> delete(int id);
}