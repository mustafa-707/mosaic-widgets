import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('countUp true emits countsDown: false', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWTimer',
        'target': 1700000000000,
        'countUp': true,
        'style': {}
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('countsDown: false'));
    // gated for iOS16+ timerInterval Text, with a .timer fallback
    expect(s, contains('if #available(iOS 16.0'));
    expect(s, contains('style: .timer'));
  });

  test('countUp false keeps countdown timer style', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWTimer',
        'target': 1700000000000,
        'countUp': false,
        'style': {}
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('style: .timer'));
    expect(s, isNot(contains('countsDown: false')));
  });

  test('countUp with bind target reads entry data', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWTimer',
        'target': {'__type': 'HWBind', 'key': 'started'},
        'countUp': true,
        'style': {}
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('started'));
    expect(s, contains('countsDown: false'));
  });
}
