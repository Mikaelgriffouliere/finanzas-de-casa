import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/constants/app_constants.dart';

/// Resuelve una ubicación única y estable para la base de datos de escritorio.
///
/// sqflite FFI calcula las rutas relativas al directorio de trabajo del
/// proceso (`<cwd>/.dart_tool/sqflite_common_ffi/databases`), lo que hace que
/// la app use una base distinta según desde dónde se lance el binario.
/// Aquí se fija la carpeta de datos en el directorio del usuario y, la
/// primera vez, se migra la base existente de las ubicaciones previas.
class DbPathResolver {
  DbPathResolver._();

  static const String dataDirName = '.finanzasHogar';

  /// Retorna el path absoluto del archivo de base de datos, creando la
  /// carpeta y copiando la base existente desde rutas heredadas si hace falta.
  static Future<String> resolve({
    String? home,
    String? cwd,
  }) async {
    final h = home ?? Platform.environment['HOME'];
    final base = (h != null && h.isNotEmpty)
        ? p.join(h, dataDirName)
        : p.join(Directory.systemTemp.path, dataDirName);
    final dir = Directory(p.join(base, 'databases'));
    await dir.create(recursive: true);

    final target = p.join(dir.path, AppConstants.dbName);
    if (File(target).existsSync()) return target;

    final current = cwd ?? Directory.current.path;
    final candidates = <String>[
      p.join(current, '.dart_tool', 'sqflite_common_ffi', 'databases',
          AppConstants.dbName),
      p.join(h ?? '', '.dart_tool', 'sqflite_common_ffi', 'databases',
          AppConstants.dbName),
    ];
    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) {
        await file.copy(target);
        return target;
      }
    }
    return target;
  }
}