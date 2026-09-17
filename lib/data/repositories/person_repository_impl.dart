import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/person.dart';
import '../../../domain/repositories/person_repository.dart';
import '../database/app_database.dart';

class PersonRepositoryImpl implements PersonRepository {
  final AppDatabase _db = AppDatabase.instance;

  @override
  Future<List<Person>> getAll({bool onlyActive = false}) async {
    final db = await _db.getDatabase();
    final where = onlyActive ? 'is_active = 1' : null;
    final result = await db.query(TableNames.persons, where: where, orderBy: 'name');
    return result.map(_fromRow).toList();
  }

  @override
  Future<Person?> getById(int id) async {
    final db = await _db.getDatabase();
    final result = await db.query(
      TableNames.persons,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : _fromRow(result.first);
  }

  @override
  Future<Person> create(Person person) async {
    final db = await _db.getDatabase();
    final id = await db.insert(TableNames.persons, _toRow(person));
    return person.copyWith(id: id, createdAt: DateTime.now());
  }

  @override
  Future<Person> update(Person person) async {
    final db = await _db.getDatabase();
    final row = _toRow(person);
    row['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      TableNames.persons,
      row,
      where: 'id = ?',
      whereArgs: [person.id],
    );
    return person.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<void> delete(int id) async {
    final db = await _db.getDatabase();
    await db.delete(TableNames.persons, where: 'id = ?', whereArgs: [id]);
  }

  Map<String, dynamic> _toRow(Person p) {
    return {
      'name': p.name,
      'description': p.description,
      'color': p.color,
      'avatar': p.avatar,
      'is_active': p.isActive ? 1 : 0,
      'created_at': p.createdAt?.toIso8601String(),
      'updated_at': p.updatedAt?.toIso8601String(),
    };
  }

  Person _fromRow(Map<String, dynamic> row) {
    return Person(
      id: row['id'] as int,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      color: row['color'] as String? ?? '',
      avatar: row['avatar'] as String? ?? '',
      isActive: (row['is_active'] as int) == 1,
      createdAt: row['created_at'] != null ? DateTime.tryParse(row['created_at']) : null,
      updatedAt: row['updated_at'] != null ? DateTime.tryParse(row['updated_at']) : null,
    );
  }
}