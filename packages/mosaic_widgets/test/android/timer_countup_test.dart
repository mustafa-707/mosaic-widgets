import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  test(
      'timer countUp:true emits the count-up path (setChronometerCountDown false)',
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

  test('count-up puts the base in the past, so it renders a positive',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWTimer',
        'target': 1700000000000,
        'countUp': true,
      })
    ]);
    final kt = provider(r);
    // `offset = target - now`, so for the past target a count-up timer counts
    // from, offset is already negative and the base must simply add it —
    // landing in the past, which Chronometer renders as a growing positive.
    // Negating it instead put the base in the FUTURE and rendered a negative
    // timer on screen (observed as "LIVE: -28:03").
    expect(
        kt,
        contains(
            'views.setChronometer(R.id.hw_timer_0, android.os.SystemClock.elapsedRealtime() + offset0, null, true)'));
    expect(kt, contains('setChronometerCountDown(R.id.hw_timer_0, false)'));
    expect(kt, isNot(contains('elapsedRealtime() - offset0')));
  });

  test('timer default (count-down) keeps plus-offset Chronometer base',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWTimer',
        'target': 1700000000000,
      })
    ]);
    final kt = provider(r);
    expect(
        kt,
        contains(
            'views.setChronometer(R.id.hw_timer_0, android.os.SystemClock.elapsedRealtime() + offset0, null, true)'));
  });
}
