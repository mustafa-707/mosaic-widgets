import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// MToggleAction flips a stored bool from inside the widget — no app launch and
/// no network — so in-widget state like a °C/°F switch responds immediately.
void main() {
  Map<String, dynamic> toggleButton() => {
        '__type': 'HWButton',
        'child': text('°C/°F'),
        'action': {'__type': 'HWToggleAction', 'key': 'weather_unit_f'},
      };

  test('button dispatches MosaicToggleIntent with the key', () async {
    final r = await runIos([irDef(toggleButton())]);
    final swift = r.swiftForTestW();
    expect(swift, contains('MosaicToggleIntent(key: "weather_unit_f")'));
    expect(swift, contains('if #available(iOS 17.0, *)'));
  });

  test('falls back to a Link below iOS 17, where widgets are not interactive',
      () async {
    final r = await runIos([irDef(toggleButton())]);
    expect(r.swiftForTestW(), contains('Link(destination:'));
  });

  test('emits the toggle intent, which flips the bool in place', () async {
    final r = await runIos([irDef(toggleButton())]);
    final intents =
        readFile(r.file('ios/HomeWidgetExtension/MosaicIntents.swift'));
    expect(intents, contains('struct MosaicToggleIntent: AppIntent'));
    expect(intents, contains('defaults.set(!defaults.bool(forKey: key), forKey: key)'));
    expect(intents, contains('WidgetCenter.shared.reloadAllTimelines()'));
  });

  test('the key is escaped', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWButton',
        'child': text('x'),
        'action': {'__type': 'HWToggleAction', 'key': 'we"ird'},
      })
    ]);
    expect(r.swiftForTestW(), contains(r'we\"ird'));
  });
}
