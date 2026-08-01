import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Proportional sizing had no equivalent: a 2:1 split meant hard-coding dp and
/// hoping the widget was never resized.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  Map<String, dynamic> flexible(int flex, {String label = 'x'}) => {
        '__type': 'HWFlexible',
        'flex': flex,
        'child': text(label),
      };

  test('weights are emitted with 0dp on the row main axis', () async {
    // Anything but 0dp is added to measured content before the weight applies,
    // so the ratio would not hold.
    final r = await runAndroid([
      irDef({
        '__type': 'HWRow',
        'children': [flexible(2, label: 'a'), flexible(1, label: 'b')],
      })
    ]);
    final xml = layout(r);
    expect(xml, contains('android:layout_weight="2"'));
    expect(xml, contains('android:layout_weight="1"'));
    expect(xml, contains('android:layout_width="0dp"'));
  });

  test('a column flexes on height instead', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [flexible(1, label: 'a'), flexible(1, label: 'b')],
      })
    ]);
    final xml = layout(r);
    expect(xml, contains('android:layout_height="0dp"'));
    expect(xml, contains('android:layout_weight="1"'));
  });

  test('outside a LinearLayout it fills rather than emitting a dead weight',
      () async {
    // A weight means nothing to a FrameLayout parent.
    final r = await runAndroid([irDef(flexible(3))]);
    final xml = layout(r);
    expect(xml, isNot(contains('android:layout_weight="3"')));
    expect(xml, contains('match_parent'));
  });

  test('a flex below 1 is clamped, not allowed to collapse the child',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWRow',
        'children': [
          {'__type': 'HWFlexible', 'flex': 0, 'child': text('a')},
        ],
      })
    ]);
    expect(layout(r), contains('android:layout_weight="1"'));
  });

  test('the cross axis is never match_parent inside a row', () async {
    // A Row is wrap_content tall, so a match_parent child height is a circular
    // constraint that Android resolves to zero — the child vanished outright.
    final r = await runAndroid([
      irDef({
        '__type': 'HWRow',
        'children': [flexible(1, label: 'a')],
      })
    ]);
    final xml = layout(r);
    final weighted = RegExp(
      r'<FrameLayout\s+android:layout_width="0dp" android:layout_height="([^"]+)"',
    ).firstMatch(xml);
    expect(weighted, isNotNull);
    expect(weighted!.group(1), 'wrap_content');
  });

  test('a column keeps match_parent width on the cross axis', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [flexible(1, label: 'a')],
      })
    ]);
    expect(
      layout(r),
      contains(
          'android:layout_width="match_parent" android:layout_height="0dp"'),
    );
  });

  test('the child still renders inside the weighted box', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWRow',
        'children': [flexible(1, label: 'hello')],
      })
    ]);
    expect(layout(r), contains('hello'));
  });
}
