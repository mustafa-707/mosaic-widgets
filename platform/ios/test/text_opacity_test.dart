import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('MText opacity emits .opacity', () async {
    final r = await runIos([
      irDef(text('hi', style: {'opacity': 0.5}))
    ]);
    expect(r.swiftForTestW(), contains('.opacity(0.5)'));
  });

  test('no opacity -> no .opacity modifier', () async {
    final r = await runIos([irDef(text('hi'))]);
    expect(r.swiftForTestW(), isNot(contains('.opacity(')));
  });
}
