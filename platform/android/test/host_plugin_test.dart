import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Android integrators were hand-writing the method channel, callback receiver
/// and deep-link plumbing in MainActivity — the same boilerplate the iOS plugin
/// already removed. Generating it makes the integration two overrides.
void main() {
  const pluginPath =
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicPlugin.kt';

  Map<String, dynamic> orderActivity() => {
        '__type': 'HWLiveActivity',
        'name': 'Order',
        'lockScreen': container(text(bind('status'))),
      };

  test('emits the plugin with the bridge channel', () async {
    final r = await runAndroid([irDef(text('hi'))]);
    expect(r.exists(pluginPath), isTrue);
    final kt = r.file(pluginPath);
    expect(kt, contains('class MosaicPlugin'));
    expect(kt, contains('MethodChannel(engine.dartExecutor.binaryMessenger, "mosaic_bridge")'));
  });

  test('serves every method the Dart bridge invokes', () async {
    final r = await runAndroid([irDef(text('hi'))],
        liveActivities: [orderActivity()]);
    final kt = r.file(pluginPath);
    for (final method in [
      'saveString',
      'saveBool',
      'refresh',
      'refreshAll',
      'startActivity',
      'updateActivity',
      'endActivity',
      'activitiesEnabled',
      'activeActivities',
      'widgetPushTokens',
    ]) {
      expect(kt, contains('"$method"'), reason: 'missing case for $method');
    }
  });

  test('writes to widget_data, the store bindings read', () async {
    final kt = (await runAndroid([irDef(text('hi'))])).file(pluginPath);
    expect(kt, contains('getSharedPreferences(\n                                    "widget_data"'));
    // A Boolean must not be stringified — MosaicData.resolveBool reads it back.
    expect(kt, contains('if (value is Boolean)'));
    expect(kt, contains('editor.putBoolean(key, value)'));
  });

  test('forwards widget callbacks and deep links to Dart', () async {
    final kt = (await runAndroid([irDef(text('hi'))])).file(pluginPath);
    expect(kt, contains('invokeMethod("backgroundCallback"'));
    expect(kt, contains('invokeMethod("onDeepLink"'));
    // A cold start from a widget tap must not lose its deep link.
    expect(kt, contains('handleIntent(activity.intent)'));
  });

  test('the receiver is registered once on the application context', () async {
    final kt = (await runAndroid([irDef(text('hi'))])).file(pluginPath);
    // Registering per activity without unregistering leaks; guarding prevents
    // double registration across activity recreation.
    expect(kt, contains('if (receiverRegistered) return'));
    expect(kt, contains('activity.applicationContext.registerReceiver'));
    expect(kt, contains('Context.RECEIVER_NOT_EXPORTED'));
  });

  test('widgetPushTokens answers empty — Android has no widget push', () async {
    final kt = (await runAndroid([irDef(text('hi'))])).file(pluginPath);
    expect(kt, contains('result.success(emptyMap<String, String>())'));
  });

  group('live activities', () {
    test('routes to the manager when declared', () async {
      final r = await runAndroid([irDef(text('hi'))],
          liveActivities: [orderActivity()]);
      expect(r.file(pluginPath), contains('MosaicLiveActivityManager.start('));
    });

    test('reports unavailable when none are declared, so the file still '
        'compiles', () async {
      final kt = (await runAndroid([irDef(text('hi'))])).file(pluginPath);
      expect(kt, isNot(contains('MosaicLiveActivityManager.')));
      expect(kt, contains('No live_activities declared in mosaic.yaml'));
    });
  });
}
