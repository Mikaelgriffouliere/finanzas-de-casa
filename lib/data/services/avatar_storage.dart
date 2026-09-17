import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copia una imagen elegida a la carpeta de datos de la app para que el avatar
/// no dependa de la ubicación original del archivo.
class AvatarStorage {
  static Future<String> saveImage(File source) async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory(p.join(dir.path, 'avatars'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final name =
        'avatar_${DateTime.now().millisecondsSinceEpoch}${p.extension(source.path)}';
    final target = File(p.join(folder.path, name));
    await source.copy(target.path);
    return target.path;
  }
}