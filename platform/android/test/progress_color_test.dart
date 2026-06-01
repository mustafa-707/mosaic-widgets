import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  test('progress bar with color emits progressTint', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWProgressBar',
        'value': 50,
        'max': 100,
        'color': {'hex': '#FF0000', 'opacity': 1.0},
      })
    ]);
    final xml = layout(r);
    expect(xml, contains('android:progressTint="#FF0000"'));
  });

  test('progress bar without color omits progressTint', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWProgressBar',
        'value': 50,
        'max': 100,
      })
    ]);
    final xml = layout(r);
    expect(xml, isNot(contains('progressTint')));
  });
}
