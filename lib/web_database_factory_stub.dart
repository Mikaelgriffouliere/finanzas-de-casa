import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fábrica de base de datos para web. En el resto de plataformas se usa el
/// stub, que nunca debería ser invocado.
DatabaseFactory createWebDatabaseFactory() {
  throw UnsupportedError(
    'La base de datos web no está disponible en esta plataforma.',
  );
}
