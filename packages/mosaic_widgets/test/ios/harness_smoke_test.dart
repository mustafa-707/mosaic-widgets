import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('IosGenerator golden-test harness', () {
    test('generates swift file at expected path', () async {
      final result = await runIos([irDef(text('hi'))]);

      // Generator writes: ios/HomeWidgetExtension/<name>.swift
      // For name='TestW' → TestW.swift
      const swiftRel = 'ios/HomeWidgetExtension/TestW.swift';

      expect(
        result.exists(swiftRel),
        isTrue,
        reason: 'Expected swift file at $swiftRel',
      );
    });
  });
}
