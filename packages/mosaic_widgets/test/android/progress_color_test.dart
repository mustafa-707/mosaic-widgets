import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  test('progress bar with color emits progressTint', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWProgressBar',
        'value': 50,
        'max': 100,
        'color': {'hex': '#FF0000', 'opacity': 1.0},
      })
    ]);
    final xml = layout(r);
    expect(xml, contains('android:progressTint="#FF0000"'));
  });

  test('progress bar without color omits progressTint', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWProgressBar',
        'value': 50,
        'max': 100,
      })
    ]);
    final xml = layout(r);
    expect(xml, isNot(contains('progressTint')));
  });

  test('progress bar with bind color wires a runtime color filter', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWProgressBar',
        'value': 50,
        'max': 100,
        'color': {'bind': 'tint', 'opacity': 1.0},
      })
    ]);
    final xml = layout(r);
    // The ProgressBar gets a stable id so the provider can target it.
    expect(xml, contains('hw_progresscolor_tint'));

    final kt = r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt',
    );
    // Provider resolves the bind key via MosaicData and applies setColorFilter
    // to the progress view id.
    expect(kt, contains('Color.parseColor'));
    expect(kt, contains('"tint"'));
    expect(kt, contains('setColorFilter'));
    expect(kt, contains('R.id.hw_progresscolor_tint'));
  });
}
