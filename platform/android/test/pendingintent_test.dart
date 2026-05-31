import 'package:test/test.dart';
import 'package:mosaic_core/mosaic_core.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('PendingIntent request code is widget-instance unique', () async {
    final r = await runAndroid([
      irDef(container({
        '__type': 'HWButton', 'child': text('x'),
        'action': {'__type': 'HWActionCallback', 'callbackName': 'a'},
      }))
    ]);
    final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');
    expect(kt, contains('appWidgetId * 100'));
  });

  test('updatePeriodMillis derives from updateInterval clamped to 1800000', () async {
    final def = IRDefinition(name: 'TestW',
        root: IRNode.fromJson(text('hi')), updateInterval: 60000);
    final r = await runAndroid([def]);
    expect(r.file('android/app/src/main/res/xml/hw_testw_info.xml'),
        contains('1800000'));
  });

  test('updatePeriodMillis is 0 when no interval set', () async {
    final r = await runAndroid([irDef(text('hi'))]);
    expect(r.file('android/app/src/main/res/xml/hw_testw_info.xml'),
        contains('android:updatePeriodMillis="0"'));
  });
}
