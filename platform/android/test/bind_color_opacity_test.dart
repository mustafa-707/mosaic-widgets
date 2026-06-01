import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  test('bind text color with opacity applies alpha in the provider', () async {
    final r = await runAndroid([
      irDef(text('hi', style: {
        'color': {'bind': 'accent', 'opacity': 0.5},
      }))
    ]);
    final kt = provider(r);
    // Color is still resolved from prefs...
    expect(kt, contains('Color.parseColor'));
    expect(kt, contains('"accent"'));
    // ...and the bind opacity is applied via an alpha-channel rewrite.
    expect(kt, contains('shl 24'));
    expect(kt, contains('0x00FFFFFF'));
  });

  test('bind background color with opacity applies alpha in the provider',
      () async {
    final r = await runAndroid([
      irDef(container(
        text('hi'),
        extra: {
          'background': {'bind': 'card', 'opacity': 0.5},
        },
      ))
    ]);
    final kt = provider(r);
    expect(kt, contains('Color.parseColor'));
    expect(kt, contains('"card"'));
    expect(kt, contains('shl 24'));
  });

  test('bind color at full opacity leaves the parse path unchanged', () async {
    final r = await runAndroid([
      irDef(text('hi', style: {
        'color': {'bind': 'accent', 'opacity': 1.0},
      }))
    ]);
    final kt = provider(r);
    expect(kt, contains('Color.parseColor'));
    expect(kt, isNot(contains('shl 24')));
  });
}
