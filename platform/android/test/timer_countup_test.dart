import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  test('timer countUp:true emits the count-up path (setChronometerCountDown false)',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWTimer',
        'target': 1700000000000,
        'countUp': true,
      })
    ]);
    final kt = provider(r);
    expect(kt, contains('setChronometerCountDown(R.id.hw_timer_0, false)'));
  });

  test('timer default counts down (setChronometerCountDown true)', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWTimer',
        'target': 1700000000000,
      })
    ]);
    final kt = provider(r);
    expect(kt, contains('setChronometerCountDown(R.id.hw_timer_0, true)'));
  });
}
