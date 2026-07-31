import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';
import 'support/gen_harness.dart';

/// Battery has to be read in the **app**, not the widget extension.
///
/// `UIDevice.isBatteryMonitoringEnabled` is a no-op inside an app extension, so
/// `batteryLevel` there stays -1 on a real device exactly as it does in the
/// simulator — the metric simply never appeared. Verified by logging from the
/// running app: monitoring reads back `false` and the level `-1.0` when nothing
/// enables it in a process that is allowed to.
///
/// So the app publishes into the App Group and the widget reads it like any
/// other stored key.
IRDefinition _def(String key) => IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson({
        '__type': 'HWText',
        'text': {'__type': 'HWBind', 'key': key},
        'style': {},
      }),
    );

void main() {
  String plugin(r) => readFile(r.file('ios/Runner/MosaicPlugin.swift'));

  test('a battery-using project publishes from the app', () async {
    final s = plugin(await runIos([_def('mosaic_battery_level')]));
    expect(s, contains('startBatteryPublishing()'));
    expect(s, contains('isBatteryMonitoringEnabled = true'));
  });

  test('it observes changes rather than sampling once', () async {
    // The first read straight after enabling is usually still -1 — the value
    // arrives asynchronously — so a single sample at launch would publish
    // nothing and never try again.
    final s = plugin(await runIos([_def('mosaic_battery_level')]));
    expect(s, contains('batteryLevelDidChangeNotification'));
    expect(s, contains('batteryStateDidChangeNotification'));
    // And on return to foreground, since the level moves while the app is away.
    expect(s, contains('didBecomeActiveNotification'));
  });

  test('an unknown level is never written', () async {
    // Writing -1 would replace a good value with a placeholder every time
    // monitoring restarts.
    final s = plugin(await runIos([_def('mosaic_battery_level')]));
    expect(s, contains('guard level >= 0 else { return }'));
  });

  test('WidgetCenter is gated, since the Runner may target below iOS 14',
      () async {
    // This failed the real build before it was gated:
    // "'WidgetCenter' is only available in iOS 14.0 or newer".
    final s = plugin(await runIos([_def('mosaic_battery_level')]));
    final at = s.indexOf('reloadAllTimelines()');
    expect(at, greaterThan(-1));
    expect(s.substring(at - 200, at), contains('#available(iOS 14.0, *)'));
  });

  test('a project with no battery metric carries none of it', () async {
    final s = plugin(await runIos([_def('something_else')]));
    expect(s, isNot(contains('startBatteryPublishing')));
    expect(s, isNot(contains('isBatteryMonitoringEnabled')));
  });

  test('the extension no longer overwrites the app value with -1', () async {
    final core = readFile((await runIos([_def('mosaic_battery_level')]))
        .file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));
    // Charging state used to be written unconditionally, outside the level
    // check, so an extension that knew nothing still clobbered it.
    final at = core.indexOf('mosaic_battery_charging');
    expect(at, greaterThan(-1));
    expect(core.substring(0, at), contains('if level >= 0 {'));
  });
}
