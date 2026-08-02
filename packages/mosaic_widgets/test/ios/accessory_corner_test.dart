import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/gen_harness.dart';

/// `accessoryCorner` is the curved complication that sits in a watch face
/// corner. It exists **only on watchOS** — naming it on iOS is a compile error,
/// which is why it cannot join the shared accessory list that is emitted under
/// a gate mentioning both platforms.
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

IRDefinition _def() => IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson({'__type': 'HWText', 'text': 'x', 'style': {}}),
    );

void main() {
  test('it is accepted as a declared family', () async {
    // Previously an unknown value here threw a gen-time error.
    final s = (await runIos([
      _def(),
    ], config: _config(['accessoryCorner'])))
        .swiftForTestW();
    expect(s, contains('.accessoryCorner'));
  });

  test('it is fenced to watchOS alone', () async {
    final s = (await runIos([
      _def(),
    ], config: _config(['accessoryCorner'])))
        .swiftForTestW();
    final at = s.indexOf('.accessoryCorner');
    final before = s.substring(0, at);
    // The nearest preceding fence must be watchOS-only — not the shared
    // `os(iOS) || os(watchOS)` block the other accessories use, which would
    // put the case on a platform that has no such enum value.
    expect(before.lastIndexOf('#if os(watchOS)'),
        greaterThan(before.lastIndexOf('#if os(iOS) || os(watchOS)')));
    expect(s, contains('#available(watchOS 9.0, *)'));
  });

  test('it coexists with families that exist elsewhere', () async {
    final s = (await runIos([
      _def(),
    ],
            config: _config([
              'systemSmall',
              'accessoryCircular',
              'accessoryCorner',
            ])))
        .swiftForTestW();
    expect(s, contains('.systemSmall'));
    expect(s, contains('.accessoryCircular'));
    expect(s, contains('.accessoryCorner'));
    // The corner must not be folded into the shared accessory append, which is
    // compiled on iOS too.
    final shared = s.substring(
      s.indexOf('#if os(iOS) || os(watchOS)'),
      s.indexOf('#endif', s.indexOf('#if os(iOS) || os(watchOS)')),
    );
    expect(shared, isNot(contains('.accessoryCorner')));
  });

  test('a project not asking for it emits no watch-corner block', () async {
    final s = (await runIos([
      _def(),
    ], config: _config(['systemSmall'])))
        .swiftForTestW();
    expect(s, isNot(contains('.accessoryCorner')));
  });
}
