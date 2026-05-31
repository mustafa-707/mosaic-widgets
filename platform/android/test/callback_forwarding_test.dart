import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('callback provider puts callbackName extra', () async {
    final r = await runAndroid([irDef(container({
      '__type': 'HWButton', 'child': text('x'),
      'action': {'__type': 'HWActionCallback', 'callbackName': 'sync'},
    }))]);
    final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');
    expect(kt, contains('"callbackName"'));
  });
}
