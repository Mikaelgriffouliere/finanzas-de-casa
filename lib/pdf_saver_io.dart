import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Guarda [bytes] en la carpeta de documentos de la app y devuelve la ruta.
Future<String> savePdfBytes(List<int> bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File(path.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
