import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  test('text with style opacity emits android:alpha', () async {
    final r = await runAndroid([
      irDef(text('hi', style: {'opacity': 0.5}))
    ]);
    expect(layout(r), contains('android:alpha="0.5"'));
  });

  test('text without opacity omits android:alpha', () async {
    final r = await runAndroid([irDef(text('hi'))]);
    expect(layout(r), isNot(contains('android:alpha')));
  });

  test('opacity applies regardless of color', () async {
    final r = await runAndroid([
      irDef(text('hi', style: {
        'opacity': 0.25,
        'color': {'hex': '#00FF00', 'opacity': 1.0}
      }))
    ]);
    final xml = layout(r);
    expect(xml, contains('android:alpha="0.25"'));
    expect(xml, contains('android:textColor="#00FF00"'));
  });
}
