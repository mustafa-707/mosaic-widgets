import 'dart:io';
import 'package:hw_cli/src/commands/clean_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('removes only MOSAIC-GENERATED swift files', () {
    final dir = Directory.systemTemp.createTempSync('mosaic_clean_');
    File(p.join(dir.path, 'Foo.swift'))
        .writeAsStringSync('// MOSAIC-GENERATED\nimport WidgetKit\n');
    File(p.join(dir.path, 'Bar.swift'))
        .writeAsStringSync('import WidgetKit // hand written\n');
    cleanIosGenerated(dir);
    expect(File(p.join(dir.path, 'Foo.swift')).existsSync(), isFalse);
    expect(File(p.join(dir.path, 'Bar.swift')).existsSync(), isTrue);
  });
}
