import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('callback action string uses configured android package', () async {
    final r = await runAndroid([
      irDef(container({
        '__type': 'HWButton',
        'child': text('go'),
        'action': {'__type': 'HWActionCallback', 'callbackName': 'ping'},
      }))
    ]);
    final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/hw_generated/TestWProvider.kt');
    expect(kt, contains('com.acme.app.MOSAIC_CALLBACK'));
    expect(kt, isNot(contains('com.example.hw_flutter')));
  });
}
