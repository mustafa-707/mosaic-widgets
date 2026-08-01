import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  test('timer with style opacity emits android:alpha on Chronometer', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWTimer',
        'target': 1700000000000,
        'style': {'opacity': 0.5},
      })
    ]);
    final xml = layout(r);
    expect(xml, contains('<Chronometer'));
    expect(xml, contains('android:alpha="0.5"'));
  });

  test('timer without opacity omits android:alpha', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWTimer',
        'target': 1700000000000,
      })
    ]);
    expect(layout(r), isNot(contains('android:alpha')));
  });
}
