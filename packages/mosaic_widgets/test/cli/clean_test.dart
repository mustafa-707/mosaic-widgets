import 'dart:io';
import 'package:mosaic_widgets/src/cli/commands/clean_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('cleanAndroidDrawables removes hw_-prefixed files and keeps user files',
      () {
    final dir = Directory.systemTemp.createTempSync('mosaic_drawable_');
    File(p.join(dir.path, 'hw_gradient_1.xml')).writeAsStringSync('<shape/>');
    File(p.join(dir.path, 'hw_bg_dark.xml')).writeAsStringSync('<shape/>');
    File(p.join(dir.path, 'my_icon.xml')).writeAsStringSync('<vector/>');
    cleanAndroidDrawables(dir);
    expect(File(p.join(dir.path, 'hw_gradient_1.xml')).existsSync(), isFalse);
    expect(File(p.join(dir.path, 'hw_bg_dark.xml')).existsSync(), isFalse);
    expect(File(p.join(dir.path, 'my_icon.xml')).existsSync(), isTrue);
  });

  test('cleanAndroidColors removes mosaic_colors.xml and keeps user files', () {
    final resDir = Directory.systemTemp.createTempSync('mosaic_res_');
    final valuesDir = Directory(p.join(resDir.path, 'values'))..createSync();
    final valuesNightDir = Directory(p.join(resDir.path, 'values-night'))
      ..createSync();
    File(p.join(valuesDir.path, 'mosaic_colors.xml'))
        .writeAsStringSync('<resources/>');
    File(p.join(valuesNightDir.path, 'mosaic_colors.xml'))
        .writeAsStringSync('<resources/>');
    File(p.join(valuesDir.path, 'strings.xml'))
        .writeAsStringSync('<resources/>');
    cleanAndroidColors(resDir);
    expect(File(p.join(valuesDir.path, 'mosaic_colors.xml')).existsSync(),
        isFalse);
    expect(File(p.join(valuesNightDir.path, 'mosaic_colors.xml')).existsSync(),
        isFalse);
    expect(File(p.join(valuesDir.path, 'strings.xml')).existsSync(), isTrue);
  });

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
