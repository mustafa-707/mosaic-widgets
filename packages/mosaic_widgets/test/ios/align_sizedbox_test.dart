import 'package:mosaic_widgets/src/ios/ios.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('MSizedBox', () {
    test('an empty box is a clear rect of exactly that size', () async {
      // Spacer() would absorb leftover space instead of being a fixed gap.
      final r = await runIos([
        irDef({'__type': 'HWSizedBox', 'width': 12, 'height': 8})
      ]);
      final swift = r.swiftForTestW();
      expect(swift, contains('Color.clear'));
      expect(swift, contains('.frame(width: 12, height: 8)'));
      expect(swift, isNot(contains('Spacer()')));
    });

    test('only the axes given are constrained', () async {
      final r = await runIos([
        irDef({'__type': 'HWSizedBox', 'height': 8})
      ]);
      expect(r.swiftForTestW(), contains('.frame(height: 8)'));
    });

    test('a child is wrapped rather than replaced', () async {
      final r = await runIos([
        irDef({'__type': 'HWSizedBox', 'width': 40, 'child': text('hi')})
      ]);
      final swift = r.swiftForTestW();
      expect(swift, contains('Text("hi")'));
      expect(swift, contains('.frame(width: 40)'));
    });

    test('a box with no dimensions constrains neither axis', () async {
      // Scoped to width/height: the widget wrapper legitimately emits its own
      // `.frame(maxWidth: .infinity, ...)` around the whole tree.
      final r = await runIos([
        irDef({'__type': 'HWSizedBox', 'child': text('hi')})
      ]);
      final swift = r.swiftForTestW();
      expect(swift, contains('Text("hi")'));
      // Numeric frames only: the wrapper emits `.frame(maxWidth: .infinity…)`
      // and a GeometryReader-derived frame around the whole tree.
      expect(swift, isNot(matches(RegExp(r'\.frame\((?:width|height): \d'))));
    });
  });

  group('MAlign', () {
    test('alignment uses leading/trailing so it mirrors in RTL', () async {
      final r = await runIos([
        irDef({
          '__type': 'HWAlign',
          'alignment': 'bottomEnd',
          'child': text('hi'),
        })
      ]);
      final swift = r.swiftForTestW();
      expect(swift, contains('alignment: .bottomTrailing'));
      expect(swift, contains('maxWidth: .infinity'));
    });

    test('every alignment maps to a distinct SwiftUI Alignment', () {
      const names = [
        'topStart',
        'topCenter',
        'topEnd',
        'centerStart',
        'center',
        'centerEnd',
        'bottomStart',
        'bottomCenter',
        'bottomEnd',
      ];
      expect(names.map(swiftAlignment).toSet().length, names.length);
    });

    test('an unknown alignment falls back to centre', () {
      expect(swiftAlignment(null), '.center');
      expect(swiftAlignment('nonsense'), '.center');
    });
  });
}
