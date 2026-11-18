import 'dart:io';

import 'package:path/path.dart' as path;

/// Copia la base que versiones anteriores guardaban dentro de `.dart_tool`
/// (relativa al directorio de trabajo) a la carpeta de datos de la app.
Future<void> migrateLegacyDatabase(String targetPath) async {
  final target = File(targetPath);
  if (await target.exists()) return;

  final legacy = File(
    path.join(
      Directory.current.path,
      '.dart_tool',
      'sqflite_common_ffi',
      'databases',
      'nido_finanzas.db',
    ),
  );
  if (!await legacy.exists()) return;

  await target.parent.create(recursive: true);
  await legacy.copy(targetPath);
}
