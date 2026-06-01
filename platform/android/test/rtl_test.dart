import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  test('padding + row layout uses start/end, never left/right', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWPadding',
        'insets': {'left': 8, 'right': 16, 'top': 4, 'bottom': 4},
        'child': {
          '__type': 'HWRow',
          'mainAxisAlignment': 'start',
          'crossAxisAlignment': 'start',
          'children': [text('a'), text('b')],
        },
      })
    ]);
    final xml = layout(r);

    // No left/right physical padding or margin attributes.
    expect(xml, isNot(contains('android:paddingLeft')));
    expect(xml, isNot(contains('android:paddingRight')));
    expect(xml, isNot(contains('android:layout_marginLeft')));
    expect(xml, isNot(contains('android:layout_marginRight')));

    // RTL-aware equivalents are used instead.
    expect(xml, contains('android:paddingStart'));
    expect(xml, contains('android:paddingEnd'));

    // No gravity literal of left/right (start/end used instead).
    expect(xml, isNot(contains('gravity="left')));
    expect(xml, isNot(contains('gravity="right')));
    expect(xml, isNot(contains('|left')));
    expect(xml, isNot(contains('|right')));
  });

  test('container margin uses marginStart/marginEnd', () async {
    final r = await runAndroid([
      irDef(container(text('hi'), extra: {
        'margin': {'left': 8, 'right': 12, 'top': 2, 'bottom': 2},
      }))
    ]);
    final xml = layout(r);
    expect(xml, isNot(contains('android:layout_marginLeft')));
    expect(xml, isNot(contains('android:layout_marginRight')));
    expect(xml, contains('android:layout_marginStart'));
    expect(xml, contains('android:layout_marginEnd'));
  });

  test('positioned uses marginStart/marginEnd, no left/right', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWStack',
        'children': [
          {
            '__type': 'HWPositioned',
            'left': 4,
            'right': 8,
            'top': 2,
            'child': text('p'),
          }
        ],
      })
    ]);
    final xml = layout(r);
    expect(xml, isNot(contains('android:layout_marginLeft')));
    expect(xml, isNot(contains('android:layout_marginRight')));
    expect(xml, contains('android:layout_marginStart'));
    expect(xml, contains('android:layout_marginEnd'));
  });
}
