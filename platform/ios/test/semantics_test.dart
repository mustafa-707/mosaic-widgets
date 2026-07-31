import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Without an accessibility label VoiceOver reads whatever text is present —
/// usually bare numbers with no unit or context.
void main() {
  test('applies a static label', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWSemantics',
        'label': 'Battery 71 percent',
        'child': text('71'),
      })
    ]);
    expect(r.swiftForTestW(),
        contains('.accessibilityLabel(Text("Battery 71 percent"))'));
  });

  test('a bound label resolves from stored data', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWSemantics',
        'label': bind('battery_a11y'),
        'child': text('71'),
      })
    ]);
    expect(r.swiftForTestW(),
        contains('mosaicStr(entry.data["battery_a11y"]) ?? ""'));
  });

  test('excludeChildren collapses the subtree before labelling it', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWSemantics',
        'label': 'Summary',
        'child': text('fragment'),
        'excludeChildren': true,
      })
    ]);
    final swift = r.swiftForTestW();
    final ignore = swift.indexOf('.accessibilityElement(children: .ignore)');
    final label = swift.indexOf('.accessibilityLabel(');
    expect(ignore, greaterThan(-1));
    // Order matters: the children's own labels win if this comes after.
    expect(ignore, lessThan(label));
  });

  test('excludeChildren is off by default', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWSemantics',
        'label': 'L',
        'child': text('x'),
      })
    ]);
    expect(r.swiftForTestW(),
        isNot(contains('.accessibilityElement(children: .ignore)')));
  });

  test('the label is escaped for Swift', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWSemantics',
        'label': 'say "hi"',
        'child': text('x'),
      })
    ]);
    expect(r.swiftForTestW(), contains(r'say \"hi\"'));
  });

  test('missing child degrades to a comment', () async {
    final r = await runIos([
      irDef({'__type': 'HWSemantics', 'label': 'L'})
    ]);
    expect(r.swiftForTestW(), contains('missing child'));
  });
}
