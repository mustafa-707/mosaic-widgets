import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Golden tests for new props on existing components:
/// MText.maxLines/align, MContainer.shadow/corners, MLinearGradient.angle.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  List<String> drawables(GenResult r) {
    return r
        .resXmlFiles()
        .where((f) => f.path.contains('/drawable/'))
        .map((f) => f.readAsStringSync())
        .toList();
  }

  group('MText maxLines/align', () {
    test('maxLines emits maxLines + ellipsize=end', () async {
      final r = await runAndroid([
        irDef(text('Hello world', style: {})
          ..['maxLines'] = 2),
      ]);
      final xml = layout(r);
      expect(xml, contains('android:maxLines="2"'));
      expect(xml, contains('android:ellipsize="end"'));
    });

    test('no maxLines omits maxLines + ellipsize', () async {
      final r = await runAndroid([irDef(text('Hello'))]);
      final xml = layout(r);
      expect(xml, isNot(contains('android:maxLines')));
      expect(xml, isNot(contains('ellipsize')));
    });

    test('align=center emits center gravity + textAlignment', () async {
      final r = await runAndroid([
        irDef(text('Hi')..['align'] = 'center'),
      ]);
      final xml = layout(r);
      expect(xml, contains('android:gravity="center"'));
      expect(xml, contains('android:textAlignment="center"'));
    });

    test('align=start -> viewStart, align=end -> viewEnd', () async {
      final rs = await runAndroid([irDef(text('A')..['align'] = 'start')]);
      expect(layout(rs), contains('android:textAlignment="viewStart"'));
      expect(layout(rs), contains('android:gravity="start"'));

      final re = await runAndroid([irDef(text('B')..['align'] = 'end')]);
      expect(layout(re), contains('android:textAlignment="viewEnd"'));
      expect(layout(re), contains('android:gravity="end"'));
    });

    test('align null omits gravity/textAlignment', () async {
      final r = await runAndroid([irDef(text('A'))]);
      expect(layout(r), isNot(contains('android:textAlignment')));
    });
  });

  group('MContainer shadow', () {
    test('a shadow with no background draws nothing, layout still valid',
        () async {
      final r = await runAndroid([
        irDef(container(text('x'), extra: {
          'shadow': {
            'color': {'hex': '#000000', 'opacity': 0.5},
            'blur': 8.0,
            'dx': 0.0,
            'dy': 2.0,
          },
        })),
      ]);
      final xml = layout(r);
      // This container has no background, and a shape with nothing in it casts
      // nothing — the same as iOS, where `.shadow` on a transparent view draws
      // no shadow. A silhouette here would render as a stray grey rectangle.
      // The drawn case is covered in shadow_test.dart.
      expect(xml, isNot(contains('hw_shadowed_')));
      expect(xml, isNot(contains('shadow not supported')));
      // Layout still valid: declaration first line, FrameLayout present.
      expect(xml.split('\n').first, startsWith('<?xml'));
      expect(xml, contains('<FrameLayout'));
      expect(r.firstNonXmlDeclFile(), isNull);
    });
  });

  group('MContainer corners', () {
    test('corners emit per-corner radii in the shape drawable', () async {
      final r = await runAndroid([
        irDef(container(text('x'), extra: {
          'background': {'hex': '#112233', 'opacity': 1.0},
          'corners': {
            'topLeft': 4.0,
            'topRight': 8.0,
            'bottomLeft': 12.0,
            'bottomRight': 16.0,
          },
        })),
      ]);
      final xml = layout(r);
      expect(xml, contains('android:background="@drawable/hw_bg_'));
      final draws = drawables(r);
      final shape = draws.firstWhere((d) => d.contains('topLeftRadius'));
      expect(shape, startsWith('<?xml'));
      expect(shape, contains('android:topLeftRadius="4.0dp"'));
      expect(shape, contains('android:topRightRadius="8.0dp"'));
      expect(shape, contains('android:bottomLeftRadius="12.0dp"'));
      expect(shape, contains('android:bottomRightRadius="16.0dp"'));
    });

    test('corners take precedence over scalar radius', () async {
      final r = await runAndroid([
        irDef(container(text('x'), extra: {
          'background': {'hex': '#112233', 'opacity': 1.0},
          'radius': 20.0,
          'corners': {
            'topLeft': 4.0,
            'topRight': 4.0,
            'bottomLeft': 4.0,
            'bottomRight': 4.0,
          },
        })),
      ]);
      final draws = drawables(r);
      final shape = draws.firstWhere((d) => d.contains('topLeftRadius'));
      // scalar radius="20.0dp" must NOT appear; per-corner wins.
      expect(shape, isNot(contains('android:radius="20.0dp"')));
      expect(shape, contains('android:topLeftRadius="4.0dp"'));
    });
  });

  group('MLinearGradient angle', () {
    test('angle quantized to nearest multiple of 45', () async {
      final r = await runAndroid([
        irDef(container(text('x'), extra: {
          'gradient': {
            '__type': 'HWLinearGradient',
            'colors': [
              {'hex': '#FF0000', 'opacity': 1.0},
              {'hex': '#0000FF', 'opacity': 1.0},
            ],
            'angle': 100.0,
          },
        })),
      ]);
      final draws = drawables(r);
      final grad = draws.firstWhere((d) => d.contains('<gradient'));
      // 100 -> nearest multiple of 45 is 90.
      expect(grad, contains('android:angle="90"'));
      expect(grad, startsWith('<?xml'));
    });

    test('angle 0 stays 0 (left->right)', () async {
      final r = await runAndroid([
        irDef(container(text('x'), extra: {
          'gradient': {
            '__type': 'HWLinearGradient',
            'colors': [
              {'hex': '#FF0000', 'opacity': 1.0},
              {'hex': '#0000FF', 'opacity': 1.0},
            ],
            'angle': 0.0,
          },
        })),
      ]);
      final draws = drawables(r);
      final grad = draws.firstWhere((d) => d.contains('<gradient'));
      expect(grad, contains('android:angle="0"'));
    });

    test('angle 20 rounds down to 0, angle 30 rounds up to 45', () async {
      final r20 = await runAndroid([
        irDef(container(text('x'), extra: {
          'gradient': {
            '__type': 'HWLinearGradient',
            'colors': [
              {'hex': '#FF0000', 'opacity': 1.0},
              {'hex': '#0000FF', 'opacity': 1.0},
            ],
            'angle': 20.0,
          },
        })),
      ]);
      expect(
        drawables(r20).firstWhere((d) => d.contains('<gradient')),
        contains('android:angle="0"'),
      );

      final r30 = await runAndroid([
        irDef(container(text('x'), extra: {
          'gradient': {
            '__type': 'HWLinearGradient',
            'colors': [
              {'hex': '#FF0000', 'opacity': 1.0},
              {'hex': '#0000FF', 'opacity': 1.0},
            ],
            'angle': 30.0,
          },
        })),
      ]);
      expect(
        drawables(r30).firstWhere((d) => d.contains('<gradient')),
        contains('android:angle="45"'),
      );
    });
  });
}
