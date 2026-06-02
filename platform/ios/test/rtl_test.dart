import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('Row output uses leading/trailing, never .left/.right', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWRow',
        'crossAxisAlignment': 'start',
        'mainAxisAlignment': 'end',
        'children': [text('a'), text('b')],
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, isNot(contains('alignment: .left')));
    expect(s, isNot(contains('alignment: .right')));
    expect(s, isNot(contains('.leftAligned')));
  });

  test('Column with start/end cross-axis maps to leading/trailing', () async {
    final start = await runIos([
      irDef({
        '__type': 'HWColumn',
        'crossAxisAlignment': 'start',
        'children': [text('a')],
      })
    ]);
    expect(start.swiftForTestW(), contains('alignment: .leading'));

    final end = await runIos([
      irDef({
        '__type': 'HWColumn',
        'crossAxisAlignment': 'end',
        'children': [text('a')],
      })
    ]);
    expect(end.swiftForTestW(), contains('alignment: .trailing'));
  });

  test('Stack alignments never emit left/right edge tokens', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWStack',
        'alignment': 'bottomTrailing',
        'children': [text('a')],
      })
    ]);
    final s = r.swiftForTestW();
    // bottomTrailing maps to the mirror-safe .bottomTrailing, not a raw right edge.
    expect(s, contains('.bottomTrailing'));
    expect(s, isNot(contains('.bottomRight')));
    expect(s, isNot(contains(': .right')));
  });
}
