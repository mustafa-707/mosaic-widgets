import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/gen_harness.dart';

/// WidgetKit spans iOS, macOS and watchOS, but the *families* do not: watchOS
/// has no `systemSmall` at all — every complication is an accessory — and macOS
/// has no accessory families. A `WidgetFamily` case named unconditionally is a
/// compile error on the platform that lacks it, not a runtime no-op.
///
/// These assertions exist because each of the fences below was added only after
/// a real `swiftc -typecheck` against that platform's SDK failed.
MosaicConfig _config(List<String> families) => MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
      },
      'widgets': [
        {
          'name': 'TestW',
          'entry': 'TestW',
          'ios': {'families': families},
        },
      ],
    });

IRDefinition _def({IRNode? compact}) => IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson({'__type': 'HWText', 'text': 'x', 'style': {}}),
      compactRoot: compact,
    );

void main() {
  test('a system-only widget still compiles for watchOS', () async {
    // The bare `return [.systemSmall]` here is what broke a watch target for a
    // widget that was never intended for one. An empty list is the honest
    // answer: it offers nothing on that platform.
    final s = (await runIos([_def()], config: _config(['systemSmall'])))
        .swiftForTestW();
    expect(s, contains('#if os(watchOS)'));
    expect(s, contains('return []'));
  });

  test('system families are fenced out, accessories fenced in', () async {
    final s = (await runIos([_def()],
            config: _config(['systemSmall', 'accessoryCircular'])))
        .swiftForTestW();
    expect(s, contains('#if !os(watchOS)'));
    // Accessories exist on iOS 16+ and watchOS 9+, so the gate names both.
    expect(s, contains('#if os(iOS) || os(watchOS)'));
    expect(s, contains('#available(iOS 16.0, watchOS 9.0, *)'));
  });

  test('recommendations() is emitted for configurable widgets', () async {
    // Optional on iOS and macOS, where the protocol has a default, but
    // *required* on watchOS — without it the provider does not conform and the
    // extension will not build for a watch target.
    final def = IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson({'__type': 'HWText', 'text': 'x', 'style': {}}),
      params: [
        {'key': 'city', 'label': 'City', 'type': 'text', 'defaultValue': 'SF'},
      ],
    );
    final s =
        (await runIos([def], config: _config(['systemSmall']))).swiftForTestW();
    expect(s, contains('func recommendations()'));
    expect(s, contains('AppIntentRecommendation'));
  });

  test('the compact-family helper is fenced for every platform', () async {
    final core = readFile(
        (await runIos([_def()], config: _config(['systemSmall'])))
            .file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));
    // Accessory cases: iOS and watchOS only.
    expect(core, contains('#if os(iOS) || os(watchOS)'));
    // systemSmall: absent on watchOS, so that branch cannot name it.
    expect(core, contains('#if os(watchOS)'));
  });

  test('availability names every platform the API exists on', () async {
    final core = readFile(
        (await runIos([_def()], config: _config(['systemSmall'])))
            .file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));
    // Accented rendering arrived at different versions per platform; naming
    // only iOS made it unavailable everywhere else.
    expect(core, contains('iOS 18.0, macOS 15.0, watchOS 11.0'));
  });
}
