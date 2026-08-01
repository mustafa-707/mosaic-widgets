import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('column without children does not crash', () async {
    final r = await runIos([
      irDef({'__type': 'HWColumn'})
    ]);
    expect(r.exists('ios/HomeWidgetExtension/TestW.swift'), isTrue);
  });

  test('visibility without bind does not crash', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWVisibility',
        'child': {'__type': 'HWText', 'text': 'x', 'style': {}}
      })
    ]);
    expect(r.exists('ios/HomeWidgetExtension/TestW.swift'), isTrue);
  });
}
