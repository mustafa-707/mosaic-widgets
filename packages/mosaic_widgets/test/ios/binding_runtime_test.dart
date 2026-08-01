import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('visibility resolves its bind through mosaicBool', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWVisibility',
        'bind': bind('isPro'),
        'child': {'__type': 'HWText', 'text': 'pro', 'style': {}}
      })
    ]);
    expect(r.swiftForTestW(), contains('mosaicBool(entry.data["isPro"])'));
  });

  test('text bind coerces to string safely', () async {
    final r = await runIos([irDef(text(bind('count')))]);
    expect(r.swiftForTestW(), contains('mosaicStr(entry.data["count"])'));
  });

  test('HomeWidgetCore emits the coercion helpers', () async {
    final r = await runIos([irDef(text(bind('count')))]);
    final core =
        readFile(r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));
    expect(core, contains('func mosaicNum(_ value: Any?) -> Double?'));
    expect(core, contains('func mosaicBool(_ value: Any?) -> Bool'));
    expect(core, contains('func mosaicStr(_ value: Any?) -> String?'));
  });

  // Live Activity ContentState.data is [String: String] (ActivityKit requires
  // Codable), so a direct `as? NSNumber` cast can never succeed there. These
  // guard against regressing to a cast that silently yields 0/false — which
  // rendered bound timers as epoch 0 and hid bound visibility content.
  group('live activity binds coerce from [String: String]', () {
    test('visibility uses mosaicBool against context.state.data', () async {
      final r = await runIos(const [], liveActivities: [
        {
          '__type': 'HWLiveActivity',
          'name': 'Gated',
          'lockScreen': container({
            '__type': 'HWVisibility',
            'bind': bind('isLate'),
            'child': text('late'),
          }),
        }
      ]);
      final swift =
          readFile(r.file('ios/HomeWidgetExtension/GatedLiveActivity.swift'));
      expect(swift, contains('mosaicBool(context.state.data["isLate"])'));
      expect(swift, isNot(contains('boolValue')));
    });

    test('timer uses mosaicNum against context.state.data', () async {
      final r = await runIos(const [], liveActivities: [
        {
          '__type': 'HWLiveActivity',
          'name': 'Countdown',
          'lockScreen': container({
            '__type': 'HWTimer',
            'target': bind('deadline'),
            'style': {},
          }),
        }
      ]);
      final swift = readFile(
          r.file('ios/HomeWidgetExtension/CountdownLiveActivity.swift'));
      expect(swift, contains('mosaicNum(context.state.data["deadline"])'));
      expect(swift, isNot(contains('doubleValue')));
    });
  });
}
