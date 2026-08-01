import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Free/total RAM read in the widget process, from the same
/// `ActivityManager.MemoryInfo` the system settings screen reports — so a
/// memory widget shows the figure the user can verify elsewhere on their phone.
void main() {
  String device(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicDevice.kt');

  Map<String, dynamic> metric(String key) => {
        '__type': 'HWText',
        'text': bind(key),
        'style': {},
      };

  test('referencing free memory emits the ActivityManager read', () async {
    final kt =
        device(await runAndroid([irDef(metric('mosaic_memory_free_mb'))]));
    expect(kt, contains('ACTIVITY_SERVICE'));
    expect(kt, contains('getMemoryInfo(memInfo)'));
    // MB, so the widget can label it without dividing again.
    expect(kt, contains('memInfo.availMem / 1_048_576L'));
  });

  test('used-percent is guarded against a zero total', () async {
    final kt =
        device(await runAndroid([irDef(metric('mosaic_memory_used_percent'))]));
    expect(kt, contains('if (memInfo.totalMem > 0)'));
  });

  test('a project referencing no memory metric reads none', () async {
    // The whole point of collecting only referenced metrics: no widget should
    // pay for a syscall it does not use.
    final kt = device(await runAndroid([irDef(text('plain'))]));
    expect(kt, isNot(contains('ACTIVITY_SERVICE')));
  });

  test('memory sits alongside battery without displacing it', () async {
    final kt = device(await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [
          metric('mosaic_battery_level'),
          metric('mosaic_memory_free_mb'),
        ],
      })
    ]));
    expect(kt, contains('BATTERY_SERVICE'));
    expect(kt, contains('ACTIVITY_SERVICE'));
  });
}
