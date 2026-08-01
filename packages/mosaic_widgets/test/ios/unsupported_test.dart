import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('unknown node type throws with the type name', () async {
    expect(
        () => runIos([
              irDef({'__type': 'HWBogus'})
            ]),
        throwsA(predicate((e) => e.toString().contains('HWBogus'))));
  });
}
