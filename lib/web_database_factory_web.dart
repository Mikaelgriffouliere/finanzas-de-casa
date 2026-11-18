import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// SQLite en el navegador usando sqlite3.wasm + el worker de sqflite.
///
/// Requiere haber ejecutado `dart run sqflite_common_ffi_web:setup`, que copia
/// `sqlite3.wasm` y `sqflite_sw.js` a la carpeta `web/`.
DatabaseFactory createWebDatabaseFactory() => databaseFactoryFfiWeb;
