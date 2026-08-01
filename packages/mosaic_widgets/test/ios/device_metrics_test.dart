import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Device metrics are read inside the widget extension, so they stay correct
/// when the app has not run for days.
void main() {
  String core(r) =>
      readFile(r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));

  test('battery metrics enable monitoring first', () async {
    final r = await runIos([irDef(text(bind('mosaic_battery_level')))]);
    final swift = core(r);
    // batteryLevel returns -1 until monitoring is on.
    expect(swift, contains('isBatteryMonitoringEnabled = true'));
    expect(swift, contains('"mosaic_battery_level"'));
    expect(swift, contains('if level >= 0'));
  });

  test('charging covers the full state as well as charging', () async {
    final r = await runIos([irDef(text(bind('mosaic_battery_charging')))]);
    expect(core(r), contains('state == .charging || state == .full'));
  });

  test('storage reads volume capacity', () async {
    final r = await runIos([irDef(text(bind('mosaic_storage_free_gb')))]);
    final swift = core(r);
    expect(swift, contains('volumeAvailableCapacityKey'));
    expect(swift, contains('"mosaic_storage_free_gb"'));
  });

  test('only the referenced metrics are collected', () async {
    final r = await runIos([irDef(text(bind('mosaic_battery_level')))]);
    final swift = core(r);
    expect(swift, contains('isBatteryMonitoringEnabled'));
    expect(swift, isNot(contains('volumeAvailableCapacityKey')));
  });

  test('a project using no metrics still emits a compilable no-op', () async {
    final r = await runIos([irDef(text('static'))]);
    final swift = core(r);
    expect(swift, contains('enum MosaicDevice'));
    expect(swift, contains('No widget references a device metric'));
    expect(swift, isNot(contains('isBatteryMonitoringEnabled')));
  });

  test('the provider refreshes metrics before reading stored values', () async {
    final r = await runIos([irDef(text(bind('mosaic_battery_level')))]);
    final swift = r.swiftForTestW();
    final load = swift.substring(swift.indexOf('private func loadData'));
    final populate = load.indexOf('MosaicDevice.populate()');
    final read = load.indexOf('for k in [');
    expect(populate, greaterThan(-1));
    // Reading first would render the app's stale value.
    expect(populate, lessThan(read));
  });
}
