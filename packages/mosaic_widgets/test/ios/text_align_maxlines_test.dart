import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  // maxLines and align are top-level fields on the node (siblings of 'style'),
  // not nested inside the style sub-map — matches MText.toJson() output.
  test('text with maxLines emits .lineLimit', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWText',
        'text': 'hello',
        'style': <String, dynamic>{},
        'maxLines': 2,
        'align': null
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.lineLimit(2)'));
  });

  test('text align center emits .multilineTextAlignment(.center)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWText',
        'text': 'hello',
        'style': <String, dynamic>{},
        'maxLines': null,
        'align': 'center'
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.multilineTextAlignment(.center)'));
  });

  test('text align start maps to leading, end maps to trailing', () async {
    final rStart = await runIos([
      irDef({
        '__type': 'HWText',
        'text': 'a',
        'style': <String, dynamic>{},
        'maxLines': null,
        'align': 'start'
      })
    ]);
    expect(
        rStart.swiftForTestW(), contains('.multilineTextAlignment(.leading)'));
    final rEnd = await runIos([
      irDef({
        '__type': 'HWText',
        'text': 'b',
        'style': <String, dynamic>{},
        'maxLines': null,
        'align': 'end'
      })
    ]);
    expect(
        rEnd.swiftForTestW(), contains('.multilineTextAlignment(.trailing)'));
  });

  test('text without maxLines/align omits the modifiers', () async {
    final r = await runIos([irDef(text('plain'))]);
    final s = r.swiftForTestW();
    expect(s, isNot(contains('.lineLimit(')));
    expect(s, isNot(contains('.multilineTextAlignment(')));
  });
}
