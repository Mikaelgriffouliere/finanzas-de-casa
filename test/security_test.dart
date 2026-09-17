import 'package:finanzas_hogar/core/constants/app_constants.dart';
import 'package:finanzas_hogar/data/database/app_database.dart';
import 'package:finanzas_hogar/data/repositories/security_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ${TableNames.settings} (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        },
      ),
    );
    await AppDatabase.instance.setTestDatabase(db);
  });

  tearDown(() async {
    await AppDatabase.instance.closeTestDatabase();
  });

  group('SecurityRepository', () {
    test('sin PIN no está habilitado', () async {
      final repo = SecurityRepository();
      expect(await repo.isPinEnabled(), isFalse);
    });

    test('después de setPin el PIN queda habilitado y se valida', () async {
      final repo = SecurityRepository();
      await repo.setPin('1234');
      expect(await repo.isPinEnabled(), isTrue);
      expect(await repo.verifyPin('1234'), isTrue);
      expect(await repo.verifyPin('0000'), isFalse);
      expect(await repo.verifyPin('123'), isFalse);
    });

    test('el hash no guarda el PIN en texto plano', () async {
      final db = await AppDatabase.instance.getDatabase();
      await SecurityRepository().setPin('1234');
      final rows = await db.query(TableNames.settings);
      final values = rows.map((r) => r['value'] as String).toList();
      expect(values.where((v) => v == '1234'), isEmpty);
    });

    test('disablePin desactiva PIN y biometría', () async {
      final repo = SecurityRepository();
      await repo.setPin('1234');
      await repo.setBiometricEnabled(true);
      expect(await repo.isBiometricEnabled(), isTrue);
      await repo.disablePin();
      expect(await repo.isPinEnabled(), isFalse);
      expect(await repo.isBiometricEnabled(), isFalse);
    });

    test('setPin inválido lanza error', () async {
      final repo = SecurityRepository();
      expect(() => repo.setPin('12'), throwsArgumentError);
    });
  });
}