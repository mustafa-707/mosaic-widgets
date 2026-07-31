import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// The host app used to hand-copy ~200 lines of AppDelegate plumbing. That is
/// now generated as MosaicPlugin.swift so integration is a single register
/// call and cannot be copied incorrectly.
void main() {
  const pluginPath = 'ios/Runner/MosaicPlugin.swift';

  Map<String, dynamic> orderActivity() => {
        '__type': 'HWLiveActivity',
        'name': 'Order',
        'lockScreen': container(text(bind('status'))),
      };

  test('emits the host plugin into ios/Runner', () async {
    final r = await runIos([irDef(text('hi'))]);
    expect(r.exists(pluginPath), isTrue);
    final swift = readFile(r.file(pluginPath));
    expect(swift, contains('public class MosaicPlugin: NSObject, FlutterPlugin'));
    expect(swift, contains('name: "mosaic_bridge"'));
    expect(swift, contains('registrar.addApplicationDelegate(instance)'));
  });

  test('serves every method the Dart bridge invokes', () async {
    final r = await runIos([irDef(text('hi'))], liveActivities: [orderActivity()]);
    final swift = readFile(r.file(pluginPath));
    // saveJson/saveList route through saveString on the Dart side.
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
    ]) {
      expect(swift, contains('"$method"'), reason: 'missing case for $method');
    }
  });

  test('drains the pending callback the extension left behind', () async {
    final r = await runIos([irDef(text('hi'))]);
    final swift = readFile(r.file(pluginPath));
    expect(swift, contains('mosaic_pending_callback'));
    expect(swift, contains('backgroundCallback'));
    // All three entry points, so a warm resume is covered too.
    expect(swift, contains('didFinishLaunchingWithOptions'));
    expect(swift, contains('applicationWillEnterForeground'));
    expect(swift, contains('applicationDidBecomeActive'));
  });

  test('forwards deep links', () async {
    final r = await runIos([irDef(text('hi'))]);
    expect(readFile(r.file(pluginPath)), contains('onDeepLink'));
  });

  test('falls back to the configured App Group so setAppGroupId is optional',
      () async {
    final r = await runIos([irDef(text('hi'))]);
    final swift = readFile(r.file(pluginPath));
    expect(swift, contains('public static let appGroup = "group.com.acme.app.widgets"'));
    expect(swift, contains('groupId ?? Self.appGroup'));
  });

  group('live activities', () {
    test('wires push tokens and the controller when declared', () async {
      final r =
          await runIos([irDef(text('hi'))], liveActivities: [orderActivity()]);
      final swift = readFile(r.file(pluginPath));
      expect(swift, contains('MosaicActivityController.onPushToken'));
      expect(swift, contains('MosaicActivityController.start('));
    });

    test('omits controller references when none are declared, so the file '
        'still compiles', () async {
      final r = await runIos([irDef(text('hi'))]);
      final swift = readFile(r.file(pluginPath));
      // No *usages* of the symbol (the explanatory comment may name it).
      expect(swift, isNot(contains('MosaicActivityController.')));
      expect(swift, contains('case "startActivity", "updateActivity", "endActivity":'));
    });
  });
}
