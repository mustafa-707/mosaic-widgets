import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('gauge with static value emits ZStack of Circles with trim', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWGauge',
        'value': 25.0,
        'max': 100.0,
        'trackColor': {'hex': '#CCCCCC', 'opacity': 1.0},
        'fillColor': {'hex': '#0000FF', 'opacity': 1.0},
        'lineWidth': 6.0,
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('ZStack'));
    expect(s, contains('Circle()'));
    expect(s, contains('.trim('));
    expect(s, contains('lineWidth: 6.0'));
    expect(s, contains('.round'));
    expect(s, contains('.rotationEffect(.degrees(-90))'));
  });

  test('gauge with bound value resolves through bindSource as Double', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWGauge',
        'value': bind('pct'),
        'max': 100.0,
        'trackColor': null,
        'fillColor': null,
        'lineWidth': 4.0,
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.trim('));
    expect(s, contains('entry.data["pct"]'));
    expect(s, contains('mosaicNum(entry.data["pct"])'));
  });
}
