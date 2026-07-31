import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// WidgetKit has no self-advancing container and no arbitrary animation, so
/// MFlipper degrades to its first child and the numeric transition is gated to
/// iOS 17+.
void main() {
  group('MFlipper', () {
    test('renders the first child and says why', () async {
      final r = await runIos([
        irDef({
          '__type': 'HWFlipper',
          'children': [text('first'), text('second')],
          'intervalMs': 4000,
        })
      ]);
      final swift = r.swiftForTestW();
      expect(swift, contains('Text("first")'));
      // Match the emitted literal — "second" also occurs in boilerplate.
      expect(swift, isNot(contains('Text("second")')));
      expect(swift, contains('cycles on Android only'));
    });

    test('an empty flipper degrades to a comment', () async {
      final r = await runIos([
        irDef({'__type': 'HWFlipper', 'children': []})
      ]);
      expect(r.swiftForTestW(), contains('flipper has no children'));
    });
  });

  group('numeric transition', () {
    test('applies the availability-gated helper when requested', () async {
      final r = await runIos([
        irDef({
          '__type': 'HWText',
          'text': bind('btc_price'),
          'style': {},
          'contentTransition': 'numericText',
        })
      ]);
      expect(r.swiftForTestW(), contains('.mosaicNumericTransition()'));
    });

    test('is absent by default', () async {
      final r = await runIos([irDef(text('plain'))]);
      expect(r.swiftForTestW(), isNot(contains('mosaicNumericTransition')));
    });

    test('the helper gates on iOS 17, so older systems still compile',
        () async {
      final r = await runIos([irDef(text('hi'))]);
      final core =
          readFile(r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));
      expect(core, contains('func mosaicNumericTransition()'));
      expect(core, contains('if #available(iOS 17.0, *)'));
      expect(core, contains('.contentTransition(.numericText())'));
    });
  });
}
