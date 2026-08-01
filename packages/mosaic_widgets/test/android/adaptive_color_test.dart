import 'dart:io';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('adaptive (dark) colors', () {
    test(
        'adaptive container background emits light + night color resources and references @color/mosaic_',
        () async {
      final r = await runAndroid([
        irDef(container(text('hi'), extra: {
          'background': {'hex': '#FFFFFF', 'dark': '#000000', 'opacity': 1.0},
        }))
      ]);

      final light = r.file('android/app/src/main/res/values/mosaic_colors.xml');
      final night =
          r.file('android/app/src/main/res/values-night/mosaic_colors.xml');

      // Light has the light color, night has the dark color.
      expect(light, contains('#FFFFFF'));
      expect(night, contains('#000000'));

      // Both reference a mosaic_ color name.
      expect(light, contains('<color name="mosaic_'));
      expect(night, contains('<color name="mosaic_'));

      // Both start with the XML declaration then the sentinel then <resources>.
      expect(light.split('\n').first, startsWith('<?xml'));
      expect(night.split('\n').first, startsWith('<?xml'));
      expect(light, contains('MOSAIC-GENERATED'));
      expect(night, contains('MOSAIC-GENERATED'));
      expect(light, contains('<resources>'));
      expect(night, contains('<resources>'));

      // The layout/drawable references @color/mosaic_.
      final resDir = Directory('${r.root.path}/android/app/src/main/res');
      final allRes = resDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.xml') && !f.path.contains('mosaic_colors'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(allRes, contains('@color/mosaic_'));
    });

    test('adaptive text color emits color resources and references @color/',
        () async {
      final r = await runAndroid([
        irDef(text('hi', style: {
          'color': {'hex': '#112233', 'dark': '#445566', 'opacity': 1.0},
        }))
      ]);
      final layout = r.file('android/app/src/main/res/layout/hw_testw.xml');
      expect(layout, contains('android:textColor="@color/mosaic_'));
      expect(r.file('android/app/src/main/res/values-night/mosaic_colors.xml'),
          contains('#445566'));
    });
  });

  group('bind colors', () {
    test('bind background resolves color at runtime in the provider', () async {
      final r = await runAndroid([
        irDef(container(text('hi'), extra: {
          'background': {'bind': 'accent', 'opacity': 1.0},
        }))
      ]);
      final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt',
      );
      expect(kt, contains('Color.parseColor'));
      expect(kt, contains('setBackgroundColor'));
      // References the original bind key.
      expect(kt, contains('"accent"'));
    });

    test('bind text color resolves at runtime via setTextColor', () async {
      final r = await runAndroid([
        irDef(text('hi', style: {
          'color': {'bind': 'fg', 'opacity': 1.0},
        }))
      ]);
      final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt',
      );
      expect(kt, contains('Color.parseColor'));
      expect(kt, contains('setTextColor'));
      expect(kt, contains('"fg"'));
    });

    test('bind color does not crash and produces a valid layout', () async {
      final r = await runAndroid([
        irDef(container(text('hi'), extra: {
          'background': {'bind': 'accent', 'opacity': 1.0},
        }))
      ]);
      expect(r.exists('android/app/src/main/res/layout/hw_testw.xml'), isTrue);
      expect(r.firstNonXmlDeclFile(), isNull);
    });
  });
}
