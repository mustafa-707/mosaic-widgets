// Tests that the generated Swift uses an iOS-16-compatible availability-gated
// helper (mosaicContainerBackground) instead of the iOS-17-only
// .containerBackground(..., for: .widget) modifier directly.
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('iOS 16 containerBackground compatibility', () {
    test(
        'generated widget swift uses mosaicContainerBackground, '
        'not bare .containerBackground', () async {
      final r = await runIos([irDef(text('hello'))]);
      final swift = r.swiftForTestW();

      expect(
        swift,
        isNot(contains('.containerBackground(')),
        reason: 'bare .containerBackground( is iOS 17+ and must not appear '
            'ungated in the generated widget file',
      );

      expect(
        swift,
        contains('.mosaicContainerBackground('),
        reason: 'generated widget must use the availability-safe helper',
      );
    });

    test(
        'HomeWidgetCore.swift contains mosaicContainerBackground extension '
        'with #available(iOS 17.0, *) guard', () async {
      final r = await runIos([irDef(text('hello'))]);
      final corePath = r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift');
      final core = readFile(corePath);

      expect(
        core,
        contains('mosaicContainerBackground'),
        reason: 'HomeWidgetCore.swift must define the helper extension',
      );

      expect(
        core,
        contains('#available(iOS 17.0, macOS 14.0, watchOS 10.0, *)'),
        reason: 'helper must gate .containerBackground behind iOS 17 check',
      );
    });
  });
}
