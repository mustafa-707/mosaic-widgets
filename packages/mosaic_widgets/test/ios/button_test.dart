import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('button URL is built without force-unwrap', () async {
    final r = await runIos([
      irDef(container({
        '__type': 'HWButton',
        'child': text('go'),
        'action': {'__type': 'HWLaunchUrlAction', 'url': 'myapp://x'},
      }))
    ]);
    final swift = r.swiftForTestW();
    expect(swift, contains('URL(string:'));
    expect(swift, isNot(contains('")!')));
  });
}
