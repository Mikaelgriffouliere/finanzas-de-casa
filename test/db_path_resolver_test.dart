import 'dart:io';

import 'package:finanzas_hogar/data/database/db_path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DbPathResolver.resolve crea la carpeta estable y fija los datos',
      () async {
    final home = Directory.systemTemp.createTempSync('fh_home_');
    final cwd = Directory.systemTemp.createTempSync('fh_cwd_');

    final target =
        await DbPathResolver.resolve(home: home.path, cwd: cwd.path);

    expect(
      p.normalize(target),
      p.normalize(p.join(
          home.path, DbPathResolver.dataDirName, 'databases', 'finanzas_hogar.db')),
    );
    expect(Directory(p.dirname(target)).existsSync(), isTrue);

    home.deleteSync(recursive: true);
    cwd.deleteSync(recursive: true);
  });

  test('DbPathResolver.resolve migra la BD heredada ubicada en el cwd',
      () async {
    final home = Directory.systemTemp.createTempSync('fh_home_');
    final cwd = Directory.systemTemp.createTempSync('fh_cwd_');
    final legacyDir = Directory(p.join(
        cwd.path, '.dart_tool', 'sqflite_common_ffi', 'databases'));
    legacyDir.createSync(recursive: true);
    final legacy = File(p.join(legacyDir.path, 'finanzas_hogar.db'));
    legacy.writeAsBytesSync([0, 1, 2, 3, 4]);

    final target =
        await DbPathResolver.resolve(home: home.path, cwd: cwd.path);
    expect(File(target).readAsBytesSync(), [0, 1, 2, 3, 4]);

    final again = await DbPathResolver.resolve(home: home.path, cwd: cwd.path);
    expect(again, target);

    home.deleteSync(recursive: true);
    cwd.deleteSync(recursive: true);
  });

  test('DbPathResolver.resolve no machaca una BD ya existente', () async {
    final home = Directory.systemTemp.createTempSync('fh_home_');
    final cwd = Directory.systemTemp.createTempSync('fh_cwd_');
    final dir = Directory(
        p.join(home.path, DbPathResolver.dataDirName, 'databases'));
    dir.createSync(recursive: true);
    File(p.join(dir.path, 'finanzas_hogar.db')).writeAsBytesSync([9, 9, 9]);

    final legacyDir = Directory(p.join(
        cwd.path, '.dart_tool', 'sqflite_common_ffi', 'databases'));
    legacyDir.createSync(recursive: true);
    File(p.join(legacyDir.path, 'finanzas_hogar.db'))
        .writeAsBytesSync([1, 1, 1]);

    final target =
        await DbPathResolver.resolve(home: home.path, cwd: cwd.path);
    expect(File(target).readAsBytesSync(), [9, 9, 9]);

    home.deleteSync(recursive: true);
    cwd.deleteSync(recursive: true);
  });
}