import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('generated-file sentinel', () {
    test('layout xml first line contains MOSAIC-GENERATED', () async {
      final r = await runAndroid([irDef(text('hi'))]);
      final xml = r.file('android/app/src/main/res/layout/hw_testw.xml');
      final firstLine = xml.split('\n').first;
      expect(firstLine, contains('MOSAIC-GENERATED'));
    });

    test('info xml first line contains MOSAIC-GENERATED', () async {
      final r = await runAndroid([irDef(text('hi'))]);
      final xml = r.file('android/app/src/main/res/xml/hw_testw_info.xml');
      final firstLine = xml.split('\n').first;
      expect(firstLine, contains('MOSAIC-GENERATED'));
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
