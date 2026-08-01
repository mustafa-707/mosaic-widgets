import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Device metrics are read in the widget process, so they stay correct when the
/// app has not run for days — an app-supplied battery level is stale the moment
/// the app is backgrounded.
void main() {
  const devicePath =
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicDevice.kt';
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  test('battery metrics read BatteryManager', () async {
    final r = await runAndroid([irDef(text(bind('mosaic_battery_level')))]);
    final kt = r.file(devicePath);
    expect(kt, contains('Context.BATTERY_SERVICE'));
    expect(kt, contains('BATTERY_PROPERTY_CAPACITY'));
    expect(kt, contains('"mosaic_battery_level"'));
  });

  test('charging state is stored as a bool, so MVisibility can bind it',
      () async {
    final r = await runAndroid([irDef(text(bind('mosaic_battery_charging')))]);
    expect(
        r.file(devicePath),
        contains(
            'putBoolean("mosaic_battery_charging", batteryManager.isCharging)'));
  });

  test('storage metrics use StatFs on the data volume', () async {
    final r = await runAndroid([irDef(text(bind('mosaic_storage_free_gb')))]);
    final kt = r.file(devicePath);
    expect(kt, contains('android.os.StatFs'));
    expect(kt, contains('"mosaic_storage_free_gb"'));
  });

  test('only the referenced metrics are collected', () async {
    // Battery only: storage stats hit the filesystem on every redraw, so they
    // must not be gathered when unused.
    final r = await runAndroid([irDef(text(bind('mosaic_battery_level')))]);
    final kt = r.file(devicePath);
    expect(kt, contains('BATTERY_PROPERTY_CAPACITY'));
    expect(kt, isNot(contains('StatFs')));
  });

  test('a project using no metrics still emits a compilable no-op', () async {
    final r = await runAndroid([irDef(text('static'))]);
    final kt = r.file(devicePath);
    expect(kt, contains('object MosaicDevice'));
    expect(kt, contains('No widget references a device metric'));
    expect(kt, isNot(contains('BATTERY_SERVICE')));
  });

  test('values land in widget_data, where every binding reads', () async {
    final r = await runAndroid([irDef(text(bind('mosaic_battery_level')))]);
    expect(r.file(devicePath), contains('getSharedPreferences("widget_data"'));
  });

  test('the provider refreshes metrics before resolving bindings', () async {
    final r = await runAndroid([irDef(text(bind('mosaic_battery_level')))]);
    final kt = provider(r);
    // Bind resolution lives in buildViews(), which is *declared* above
    // updateAppWidget — so comparing positions in the file says nothing about
    // execution order. What matters is that the metrics refresh happens before
    // updateAppWidget asks buildViews for a tree.
    final body = kt.substring(kt.indexOf('private fun updateAppWidget'));
    final populate = body.indexOf('MosaicDevice.populate(context)');
    final build = body.indexOf('buildViews(context');
    expect(populate, greaterThan(-1), reason: 'metrics are never refreshed');
    expect(build, greaterThan(-1), reason: 'no tree is ever built');
    // Building first would render the app's stale value.
    expect(populate, lessThan(build));
    // And the resolution really is downstream of that call.
    expect(kt, contains('MosaicData.resolveString'));
  });

  test('a device metric works through the normal bind path', () async {
    // No node type should need special handling — it is an ordinary bind key.
    final r = await runAndroid([
      irDef({
        '__type': 'HWProgressBar',
        'value': bind('mosaic_battery_level'),
        'max': 100.0,
      })
    ]);
    expect(provider(r), contains('mosaic_battery_level'));
  });
}
