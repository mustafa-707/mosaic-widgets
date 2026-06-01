import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Builds a MosaicLiveActivity toJson for the OrderTracker fixture used across
/// the live-activity generation tests. Trees reuse the same widget __types so
/// the existing node→SwiftUI handlers render them; binds inside a live activity
/// resolve against `context.state.data`.
Map<String, dynamic> orderTrackerActivity() => {
      '__type': 'HWLiveActivity',
      'name': 'OrderTracker',
      'lockScreen': container(text(bind('status'))),
      'dynamicIsland': {
        '__type': 'HWDynamicIsland',
        'compactLeading': text('L'),
        'compactTrailing': text(bind('eta')),
        'minimal': text('M'),
        'expanded': {
          '__type': 'HWExpanded',
          'leading': text('lead'),
          'trailing': text(bind('eta')),
          'center': text('mid'),
          'bottom': text(bind('status')),
        },
      },
    };

void main() {
  group('Live Activity ActivityConfiguration generation', () {
    test('emits OrderTrackerLiveActivity.swift with ActivityConfiguration',
        () async {
      final res = await runIos(
        const [],
        liveActivities: [orderTrackerActivity()],
      );

      expect(
        res.exists(
            'ios/HomeWidgetExtension/OrderTrackerLiveActivity.swift'),
        isTrue,
      );

      final swift = readFile(res.file(
          'ios/HomeWidgetExtension/OrderTrackerLiveActivity.swift'));

      // Sentinel must be first line.
      expect(swift.split('\n').first, contains('MOSAIC-GENERATED'));

      // ActivityConfiguration bound to the shared attributes type.
      expect(
        swift,
        contains('ActivityConfiguration(for: MosaicActivityAttributes.self)'),
      );

      // Dynamic Island scaffold with all four expanded regions.
      expect(swift, contains('DynamicIsland {'));
      expect(swift, contains('DynamicIslandExpandedRegion(.leading)'));
      expect(swift, contains('DynamicIslandExpandedRegion(.trailing)'));
      expect(swift, contains('DynamicIslandExpandedRegion(.center)'));
      expect(swift, contains('DynamicIslandExpandedRegion(.bottom)'));

      // Compact + minimal presentations.
      expect(swift, contains('compactLeading:'));
      expect(swift, contains('compactTrailing:'));
      expect(swift, contains('minimal:'));

      // Bind resolution targets the activity content state.
      expect(swift, contains('context.state.data['));

      // iOS 16.1 availability gate.
      expect(swift, contains('@available(iOS 16.1, *)'));
    });

    test('emits the shared MosaicActivityAttributes.swift once', () async {
      final res = await runIos(
        const [],
        liveActivities: [orderTrackerActivity()],
      );

      expect(
        res.exists('ios/HomeWidgetExtension/MosaicActivityAttributes.swift'),
        isTrue,
      );

      final swift = readFile(res.file(
          'ios/HomeWidgetExtension/MosaicActivityAttributes.swift'));
      expect(swift.split('\n').first, contains('MOSAIC-GENERATED'));
      expect(swift, contains('struct MosaicActivityAttributes: ActivityAttributes'));
      expect(swift, contains('struct ContentState: Codable, Hashable'));
      expect(swift, contains('var data: [String: String]'));
    });

    test('absent expanded regions fall back to EmptyView', () async {
      final res = await runIos(
        const [],
        liveActivities: [
          {
            '__type': 'HWLiveActivity',
            'name': 'Sparse',
            'lockScreen': text('lock'),
            'dynamicIsland': {
              '__type': 'HWDynamicIsland',
              'compactLeading': text('L'),
              'compactTrailing': text('T'),
              'minimal': text('M'),
              'expanded': {
                '__type': 'HWExpanded',
                'leading': null,
                'trailing': null,
                'center': null,
                'bottom': null,
              },
            },
          }
        ],
      );

      final swift = readFile(
          res.file('ios/HomeWidgetExtension/SparseLiveActivity.swift'));
      expect(swift, contains('EmptyView()'));
    });
  });
}
