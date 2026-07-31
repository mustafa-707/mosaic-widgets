import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Without a contentDescription TalkBack reads whatever text happens to be in
/// the tree — usually bare numbers with no unit or context.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  test('a static label goes straight into the layout', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWSemantics',
        'label': 'Battery 71 percent',
        'child': text('71'),
      })
    ]);
    expect(layout(r),
        contains('android:contentDescription="Battery 71 percent"'));
    // No provider work needed for a constant.
    expect(provider(r), isNot(contains('setContentDescription')));
  });

  test('a bound label is applied by the provider', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWSemantics',
        'label': bind('battery_a11y'),
        'child': text('71'),
      })
    ]);
    expect(layout(r), contains('hw_a11y_'));
    expect(
        provider(r),
        contains(
            'setContentDescription(R.id.hw_a11y_battery_a11y, MosaicData.resolveString(context, "battery_a11y"))'));
  });

  test('the label is escaped for XML', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWSemantics',
        'label': 'Tom & "Jerry" <b>',
        'child': text('x'),
      })
    ]);
    expect(layout(r), contains('Tom &amp;'));
    expect(layout(r), isNot(contains('contentDescription="Tom & "')));
  });

  test('the child still renders inside the wrapper', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWSemantics',
        'label': 'Label',
        'child': text('inner'),
      })
    ]);
    expect(layout(r), contains('android:text="inner"'));
  });

  test('the wrapper is inflatable by RemoteViews', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWSemantics',
        'label': 'Label',
        'child': text('x'),
      })
    ]);
    expect(layout(r), isNot(contains('<View ')));
    expect(layout(r), contains('<FrameLayout'));
  });

  test('missing child degrades to a comment', () async {
    final r = await runAndroid([
      irDef({'__type': 'HWSemantics', 'label': 'L'})
    ]);
    expect(layout(r), contains('missing child'));
  });
}
