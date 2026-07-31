import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';
import 'support/gen_harness.dart';

/// `supplementalActivityFamilies` (iOS 18+) puts a Live Activity on a paired
/// Apple Watch's Smart Stack and in CarPlay, using the layout that already
/// exists — no second tree to write.
///
/// Live Activities themselves start at iOS 16.1, and a `WidgetConfiguration` is
/// an opaque type that cannot branch on availability inside its own body. So the
/// choice is per activity: opting in makes that one activity an iOS 18 type,
/// gated to match in the bundle. `WidgetBundleBuilder` has `buildOptional` but
/// no `buildEither`, so a single-branch `if #available` is the only shape that
/// compiles — which is what the bundle already uses.
MosaicConfig _config({required bool watch}) => MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
      },
      'widgets': const [],
      'live_activities': [
        {'name': 'Delivery', 'entry': 'lib/delivery.live.dart', 'watch': watch},
      ],
    });

Map<String, dynamic> _activity() => {
      'name': 'Delivery',
      'lockScreen': {'__type': 'HWText', 'text': 'On the way', 'style': {}},
      'dynamicIsland': {
        'expanded': {
          'leading': {'__type': 'HWText', 'text': 'L', 'style': {}},
        },
      },
    };

void main() {
  test('off by default, so 16.1 devices keep their Live Activities', () async {
    final r = await runIos([], config: _config(watch: false), liveActivities: [_activity()]);
    final swift = readFile(r.file('ios/HomeWidgetExtension/DeliveryLiveActivity.swift'));
    expect(swift, contains('@available(iOS 16.1, *)'));
    expect(swift, isNot(contains('supplementalActivityFamilies')));
    expect(readFile(r.file('ios/HomeWidgetExtension/HomeWidgetBundle.swift')),
        contains('if #available(iOS 16.1, *)'));
  });

  test('opting in emits the modifier and raises that activity to 18', () async {
    final r = await runIos([], config: _config(watch: true), liveActivities: [_activity()]);
    final swift = readFile(r.file('ios/HomeWidgetExtension/DeliveryLiveActivity.swift'));
    expect(swift, contains('.supplementalActivityFamilies([.small, .medium])'));
    expect(swift, contains('@available(iOS 18.0, *)'));
  });

  test('the bundle gate matches the struct, or it would not compile', () async {
    // Referencing an iOS 18 type from an `if #available(iOS 16.1, *)` block is
    // a hard compile error, so these two numbers can never drift apart.
    final r = await runIos([], config: _config(watch: true), liveActivities: [_activity()]);
    final bundle = readFile(r.file('ios/HomeWidgetExtension/HomeWidgetBundle.swift'));
    expect(bundle, contains('if #available(iOS 18.0, *)'));
    expect(
      bundle,
      isNot(contains(RegExp(
          r'if #available\(iOS 16\.1, \*\) \{\s*DeliveryLiveActivity\(\)'))),
    );
  });

  test('the modifier goes on the configuration, not inside the island', () async {
    // It modifies the ActivityConfiguration; placing it within the
    // DynamicIsland builder would not typecheck.
    final r = await runIos([], config: _config(watch: true), liveActivities: [_activity()]);
    final swift = readFile(r.file('ios/HomeWidgetExtension/DeliveryLiveActivity.swift'));
    final island = swift.indexOf('DynamicIsland {');
    final modifier = swift.indexOf('.supplementalActivityFamilies');
    expect(island, greaterThan(-1));
    expect(modifier, greaterThan(island),
        reason: 'expected the modifier after the island closure closes');
    expect(swift.substring(modifier), contains('}\n}'));
  });
}
