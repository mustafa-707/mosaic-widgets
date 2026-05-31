import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('bind keys used as resource ids are sanitized', () {
    test('layout uses sanitized id but provider resolves original key',
        () async {
      final r = await runAndroid([irDef(text(bind('my-key')))]);

      final xml = r.file('android/app/src/main/res/layout/hw_testw.xml');
      expect(xml, contains('hw_text_mykey'));
      expect(xml, isNot(contains('hw_text_my-key')));

      final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt',
      );
      // Resource id reference is sanitized...
      expect(kt, contains('R.id.hw_text_mykey'));
      expect(kt, isNot(contains('R.id.hw_text_my-key')));
      // ...but the SharedPreferences lookup key stays the original.
      expect(kt, contains('resolveString(context, "my-key")'));
    });

    test('visibility bind key is sanitized for the resource id', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWVisibility',
          'bind': {'key': 'is-on'},
          'child': text('x'),
        }),
      ]);

      final xml = r.file('android/app/src/main/res/layout/hw_testw.xml');
      expect(xml, contains('hw_visibility_ison'));
      expect(xml, isNot(contains('hw_visibility_is-on')));

      final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt',
      );
      expect(kt, contains('R.id.hw_visibility_ison'));
      expect(kt, contains('resolveBool(context, "is-on")'));
    });
  });
}
