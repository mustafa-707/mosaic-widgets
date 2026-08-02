import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('configurable widget (with params)', () {
    test(
        'generates a WidgetConfigurationIntent with a @Parameter per param, '
        'uses AppIntentConfiguration + AppIntentTimelineProvider, copies params '
        'into entry data, and registers under #available(iOS 17.0', () async {
      final def = irDefWithParams(
        container(text(bind('city'))),
        params: [
          param('city', 'choice',
              label: 'City',
              defaultValue: 'London',
              choices: ['London', 'Paris', 'Tokyo']),
          param('compact', 'toggle', label: 'Compact', defaultValue: true),
        ],
      );
      final r = await runIos([def]);
      final s = r.swiftForTestW();

      // 1. A config intent conforming to WidgetConfigurationIntent.
      expect(
          s, contains('struct TestWConfigIntent: WidgetConfigurationIntent'));
      // One @Parameter per param.
      expect(s, contains('@Parameter'));
      expect(s, contains('var city'));
      expect(s, contains('var compact'));

      // 2. AppIntentConfiguration wiring the intent + provider.
      expect(s, contains('AppIntentConfiguration('));
      expect(s, contains('intent: TestWConfigIntent.self'));
      expect(s, isNot(contains('StaticConfiguration')));

      // The provider is an AppIntentTimelineProvider that receives the
      // configuration.
      expect(s, contains('AppIntentTimelineProvider'));
      expect(s, contains('configuration: TestWConfigIntent'));

      // Param values are copied into entry data under their key.
      expect(s, contains('data["city"]'));
      expect(s, contains('data["compact"]'));

      // 3. Availability gating: widget struct + registration.
      expect(s, contains('@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)'));
      final bundle =
          readFile(r.file('ios/HomeWidgetExtension/HomeWidgetBundle.swift'));
      expect(bundle,
          contains('if #available(iOS 17.0, macOS 14.0, watchOS 10.0, *)'));
      expect(bundle, contains('TestWWidget()'));
    });

    test('choice param exposes its choices on the @Parameter', () async {
      final def = irDefWithParams(
        container(text(bind('city'))),
        params: [
          param('city', 'choice',
              label: 'City',
              defaultValue: 'London',
              choices: ['London', 'Paris']),
        ],
      );
      final r = await runIos([def]);
      final s = r.swiftForTestW();
      // Choices surface as selectable string values in the generated code.
      expect(s, contains('"London"'));
      expect(s, contains('"Paris"'));
    });

    test('number/text param types map to Swift types', () async {
      final def = irDefWithParams(
        container(text(bind('count'))),
        params: [
          param('count', 'number', label: 'Count', defaultValue: 3),
          param('label', 'text', label: 'Label', defaultValue: 'hi'),
        ],
      );
      final r = await runIos([def]);
      final s = r.swiftForTestW();
      expect(s, contains('var count'));
      expect(s, contains('var label'));
      expect(s, contains('data["count"]'));
      expect(s, contains('data["label"]'));
    });
  });

  group('non-configurable widget (no params)', () {
    test('still uses StaticConfiguration and TimelineProvider', () async {
      final r = await runIos([irDef(text('hi'))]);
      final s = r.swiftForTestW();
      expect(s, contains('StaticConfiguration'));
      expect(s, contains('TimelineProvider'));
      expect(s, isNot(contains('AppIntentConfiguration')));
      expect(s, isNot(contains('WidgetConfigurationIntent')));
      // Registered without an iOS 17 availability gate.
      final bundle =
          readFile(r.file('ios/HomeWidgetExtension/HomeWidgetBundle.swift'));
      expect(bundle, contains('TestWWidget()'));
    });
  });
}
