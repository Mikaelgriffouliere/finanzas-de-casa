import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../database/app_database.dart';

/// Almacena y valida la configuración de seguridad (PIN y biometría) en la
/// tabla `settings`. El PIN nunca se guarda en texto plano: se persiste un
/// hash con salt (SHA-256).
class SecurityRepository {
  SecurityRepository({Database? database})
      : _database = database ?? AppDatabase.instance.database;

  final Database? _database;

  static const _pinSaltKey = 'auth_pin_salt';
  static const _pinHashKey = 'auth_pin_hash';
  static const _biometricKey = 'auth_biometric_enabled';
  static const _pinLength = 4;

  Future<Database> _db() async {
    final db = _database ?? (await AppDatabase.instance.getDatabase());
    return db;
  }

  bool isValidLength(String pin) => pin.length == _pinLength && _isNumeric(pin);

  bool _isNumeric(String s) => int.tryParse(s) != null;

  Future<bool> isPinEnabled() async {
    final db = await _db();
    final result = await db.query(
      TableNames.settings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_pinHashKey],
    );
    final value = result.isNotEmpty ? result.first['value'] as String? : null;
    return value != null && value.isNotEmpty;
  }

  Future<bool> verifyPin(String pin) async {
    if (!isValidLength(pin)) return false;
    final db = await _db();
    final results = await db.query(
      TableNames.settings,
      columns: ['key', 'value'],
      where: 'key IN (?, ?)',
      whereArgs: [_pinSaltKey, _pinHashKey],
    );
    String? salt;
    String? expectedHash;
    for (final row in results) {
      final key = row['key'] as String;
      final value = row['value'] as String?;
      if (key == _pinSaltKey) salt = value;
      if (key == _pinHashKey) expectedHash = value;
    }
    if (salt == null || expectedHash == null) return false;
    return _hash(pin, salt) == expectedHash;
  }

  Future<void> setPin(String pin) async {
    if (!isValidLength(pin)) {
      throw ArgumentError('El PIN debe tener $_pinLength dígitos');
    }
    final db = await _db();
    final salt = _generateSalt();
    final hash = _hash(pin, salt);
    await db.transaction((txn) async {
      await txn.insert(
        TableNames.settings,
        {'key': _pinSaltKey, 'value': salt},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        TableNames.settings,
        {'key': _pinHashKey, 'value': hash},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> disablePin() async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.delete(TableNames.settings, where: 'key IN (?, ?, ?)', whereArgs: [_pinSaltKey, _pinHashKey, _biometricKey]);
    });
  }

  Future<bool> isBiometricEnabled() async {
    if (!await isPinEnabled()) return false;
    final db = await _db();
    final result = await db.query(
      TableNames.settings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_biometricKey],
    );
    final value = result.isNotEmpty ? result.first['value'] as String? : null;
    return value == '1';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final db = await _db();
    await db.insert(
      TableNames.settings,
      {'key': _biometricKey, 'value': enabled ? '1' : '0'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _hash(String pin, String salt) {
    return sha256.convert('$salt|$pin'.codeUnits).toString();
  }
}