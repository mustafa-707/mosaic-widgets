import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('generated-file sentinel', () {
    test('per-widget swift first line contains MOSAIC-GENERATED', () async {
      final r = await runIos([irDef(text('hi'))]);
      final firstLine = r.swiftForTestW().split('\n').first;
      expect(firstLine, contains('MOSAIC-GENERATED'));
    });

    test('bundle swift first line contains MOSAIC-GENERATED', () async {
      final r = await runIos([irDef(text('hi'))]);
      final bundle = r.file('ios/HomeWidgetExtension/HomeWidgetBundle.swift');
      final firstLine = readFirstLine(bundle);
      expect(firstLine, contains('MOSAIC-GENERATED'));
    });

    test('core swift first line contains MOSAIC-GENERATED', () async {
      final r = await runIos([irDef(text('hi'))]);
      final core = r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift');
      final firstLine = readFirstLine(core);
      expect(firstLine, contains('MOSAIC-GENERATED'));
    });
  });
}
