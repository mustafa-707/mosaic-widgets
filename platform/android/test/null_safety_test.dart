import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('column without children does not crash', () async {
    final r = await runAndroid([irDef({'__type': 'HWColumn'})]);
    expect(r.exists('android/app/src/main/res/layout/hw_testw.xml'), isTrue);
  });

  test('visibility without bind does not crash', () async {
    final r = await runAndroid([irDef({'__type': 'HWVisibility',
        'child': {'__type': 'HWText', 'text': 'x', 'style': {}}})]);
    expect(r.exists('android/app/src/main/res/layout/hw_testw.xml'), isTrue);
  });
}
