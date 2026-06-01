import 'dart:io';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('generated-file sentinel', () {
    test('layout xml: declaration first, sentinel on line 2', () async {
      final r = await runAndroid([irDef(text('hi'))]);
      final xml = r.file('android/app/src/main/res/layout/hw_testw.xml');
      final lines = xml.split('\n');
      // AAPT requires the <?xml?> processing instruction at byte 0.
      expect(lines.first.trimLeft(), startsWith('<?xml'));
      expect(lines[1], contains('MOSAIC-GENERATED'));
    });

    test('info xml: declaration first, sentinel on line 2', () async {
      final r = await runAndroid([irDef(text('hi'))]);
      final xml = r.file('android/app/src/main/res/xml/hw_testw_info.xml');
      final lines = xml.split('\n');
      expect(lines.first.trimLeft(), startsWith('<?xml'));
      expect(lines[1], contains('MOSAIC-GENERATED'));
    });

    test('gradient drawable xml: declaration is first line', () async {
      final r = await runAndroid([
        irDef(container(text('hi'), extra: {
          'gradient': {
            '__type': 'HWLinearGradient',
            'colors': [
              {'hex': '#FF0000', 'opacity': 1.0},
              {'hex': '#0000FF', 'opacity': 1.0}
            ],
            'stops': null
          }
        }))
      ]);
      final dir = Directory(
          '${r.root.path}/android/app/src/main/res/drawable');
      for (final f in dir.listSync().whereType<File>()) {
        expect(f.readAsStringSync().split('\n').first.trimLeft(),
            startsWith('<?xml'),
            reason: 'drawable ${f.path} must start with <?xml?>');
      }
    });

    test('kotlin provider first line contains MOSAIC-GENERATED', () async {
      final r = await runAndroid([irDef(text('hi'))]);
      final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt',
      );
      final firstLine = kt.split('\n').first;
      expect(firstLine, contains('MOSAIC-GENERATED'));
    });
  });
}
