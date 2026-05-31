import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('visibility reads NSNumber boolValue', () async {
    final r = await runIos([irDef({'__type': 'HWVisibility',
      'bind': bind('isPro'),
      'child': {'__type': 'HWText', 'text': 'pro', 'style': {}}})]);
    expect(r.swiftForTestW(), contains('boolValue'));
  });

  test('text bind coerces to string safely', () async {
    final r = await runIos([irDef(text(bind('count')))]);
    expect(r.swiftForTestW(), contains('as? String'));
  });
}
