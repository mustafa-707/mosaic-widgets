import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// MToggleAction flips a stored bool from the widget itself, with the app
/// closed — the provider handles the broadcast rather than deferring to Dart.
void main() {
  Future<String> providerFor(String key) async {
    final r = await runAndroid([
      irDef(container({
        '__type': 'HWButton',
        'child': text('°C/°F'),
        'action': {'__type': 'HWToggleAction', 'key': key},
      }))
    ]);
    return r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');
  }

  test('button broadcasts the toggle action with its key', () async {
    final kt = await providerFor('weather_unit_f');
    expect(kt, contains('mosaicToggleAction'));
    expect(kt, contains('putExtra("toggleKey", "weather_unit_f")'));
  });

  test('provider flips the bool in the store bindings read', () async {
    final kt = await providerFor('weather_unit_f');
    expect(kt, contains('MOSAIC_TOGGLE'));
    // Must be widget_data — the same store MosaicData.resolveBool reads.
    expect(kt, contains('getSharedPreferences("widget_data"'));
    expect(
        kt, contains('putBoolean(key, !MosaicData.resolveBool(context, key))'));
  });

  test('toggle handling does not fall through to the callback path', () async {
    final kt = await providerFor('weather_unit_f');
    final toggleBranch = kt.indexOf('mosaicToggleAction)');
    final callbackBranch = kt.indexOf('mosaicCallbackAction)');
    expect(toggleBranch, greaterThan(-1));
    expect(toggleBranch, lessThan(callbackBranch));
    expect(kt, contains('return'));
  });
}
