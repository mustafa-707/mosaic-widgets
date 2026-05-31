import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('AndroidGenerator golden-test harness', () {
    test('generates layout file at expected path', () async {
      final result = await runAndroid([irDef(text('hi'))]);

      // Generator writes: android/app/src/main/res/layout/hw_<name_lowercased>.xml
      // For name='TestW' → hw_testw.xml
      const layoutRel =
          'android/app/src/main/res/layout/hw_testw.xml';

      expect(
        result.exists(layoutRel),
        isTrue,
        reason: 'Expected layout file at $layoutRel',
      );
    });
  });
}
