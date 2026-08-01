import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// WidgetKit push updates let a server reload a widget's timeline with the app
/// closed. `WidgetPushHandler` and `.pushHandler` are iOS 26+ (verified against
/// the iOS 26.2 SDK), so both must sit behind an availability check or the
/// widget stops building for iOS 16.
MosaicConfig configWithPush({required bool push}) => MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
      },
      'widgets': [
        {
          'name': 'TestW',
          'entry': 'TestW',
          'push': push,
          'android': {
            'min_sdk': 21,
            'sizes': ['medium'],
          },
          'ios': {
            'families': ['systemMedium'],
          },
        },
      ],
    });

void main() {
  test('emits a push handler when opted in', () async {
    final r =
        await runIos([irDef(text('hi'))], config: configWithPush(push: true));
    final swift = r.swiftForTestW();
    expect(swift, contains('struct TestWPushHandler: WidgetPushHandler'));
    expect(swift, contains('@available(iOS 26.0, *)'));
    expect(
        swift,
        contains(
            'func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo])'));
  });

  test('the handler is attached behind an availability check', () async {
    final r =
        await runIos([irDef(text('hi'))], config: configWithPush(push: true));
    final swift = r.swiftForTestW();
    expect(swift, contains('if #available(iOS 26.0, *)'));
    expect(swift, contains('.pushHandler(TestWPushHandler.self)'));
    // Both branches return, so iOS 16 still gets a working widget.
    expect(swift, contains('} else {'));
    expect('return StaticConfiguration'.allMatches(swift).length, 2);
  });

  test('nothing is emitted when push is off', () async {
    final r =
        await runIos([irDef(text('hi'))], config: configWithPush(push: false));
    final swift = r.swiftForTestW();
    expect(swift, isNot(contains('PushHandler')));
    expect(swift, isNot(contains('pushHandler(')));
    // Unchanged shape: no availability wrapper around the configuration.
    expect(swift, contains('        StaticConfiguration(kind: kind'));
  });

  test('the token is stored per widget kind, not globally', () async {
    final r =
        await runIos([irDef(text('hi'))], config: configWithPush(push: true));
    expect(r.swiftForTestW(),
        contains('forKey: "mosaic_widget_push_token_TestW"'));
  });

  test('the token is hex encoded and flushed for the app to read', () async {
    final r =
        await runIos([irDef(text('hi'))], config: configWithPush(push: true));
    final swift = r.swiftForTestW();
    expect(swift, contains(r'String(format: "%02x", $0)'));
    // The extension cannot reach the server; the app must pick this up.
    expect(swift, contains('defaults.synchronize()'));
  });

  // Configurable widgets use a separate emitter (AppIntentConfiguration).
  // It was not wired initially, so opting in silently did nothing.
  test('a configurable widget also gets the handler', () async {
    final r = await runIos([
      IRDefinition.fromJson({
        'name': 'TestW',
        'root': text('hi'),
        'params': [
          {
            'key': 'city',
            'label': 'City',
            'type': 'text',
            'defaultValue': 'London'
          },
        ],
      })
    ], config: configWithPush(push: true));
    final swift = r.swiftForTestW();
    expect(swift, contains('AppIntentConfiguration(kind: kind'));
    expect(swift, contains('.pushHandler(TestWPushHandler.self)'));
    expect(swift, contains('struct TestWPushHandler: WidgetPushHandler'));
    // Still gated, so iOS 16 keeps a working configurable widget.
    expect('return AppIntentConfiguration'.allMatches(swift).length, 2);
  });

  // Without this the extension's token never reaches the app, so a server can
  // never learn it and push updates cannot work end to end.
  test('the host plugin exposes the tokens to Dart', () async {
    final r =
        await runIos([irDef(text('hi'))], config: configWithPush(push: true));
    final plugin = readFile(r.file('ios/Runner/MosaicPlugin.swift'));
    expect(plugin, contains('case "widgetPushTokens":'));
    expect(plugin, contains('let prefix = "mosaic_widget_push_token_"'));
    // Keys are returned stripped of the prefix, keyed by widget name.
    expect(plugin,
        contains('tokens[String(key.dropFirst(prefix.count))] = token'));
    // Missing App Group must answer empty rather than fail the call.
    expect(plugin, contains('result([String: String]())'));
  });

  test('push defaults to off', () {
    expect(configWithPush(push: false).widgets.single.push, isFalse);
  });
}
