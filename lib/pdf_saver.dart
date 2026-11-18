// Guarda los bytes de un PDF en una ubicación del dispositivo.
//
// La implementación real usa `dart:io` en escritorio/móvil; en web no hay
// sistema de archivos accesible y la implementación stub devuelve una cadena
// vacía para que la UI pueda avisar al usuario.
export 'pdf_saver_stub.dart' if (dart.library.io) 'pdf_saver_io.dart';
