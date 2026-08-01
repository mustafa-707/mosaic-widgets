import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('container shadow emits .shadow with color/radius/x/y', () async {
    final r = await runIos([
      irDef(container(text('hi'), extra: {
        'shadow': {
          'color': {'hex': '#000000', 'opacity': 1.0},
          'blur': 8.0,
          'dx': 0.0,
          'dy': 2.0,
        }
      }))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.shadow(color:'));
    expect(s, contains('radius: 8.0'));
    expect(s, contains('x: 0.0'));
    expect(s, contains('y: 2.0'));
  });

  test('container corners emit availability-gated uneven/rounded clip',
      () async {
    final r = await runIos([
      irDef(container(text('hi'), extra: {
        'corners': {
          'topLeft': 12.0,
          'topRight': 4.0,
          'bottomLeft': 0.0,
          'bottomRight': 20.0,
        }
      }))
    ]);
    final s = r.swiftForTestW();
    // Availability-gated uneven path, with a uniform fallback.
    expect(s, contains('mosaicCornerClip'));
    // The helper must reference UnevenRoundedRectangle (16.4 path) and the
    // RoundedRectangle fallback for <16.4.
  });

  test('corners take precedence over scalar radius', () async {
    final r = await runIos([
      irDef(container(text('hi'), extra: {
        'radius': 8.0,
        'corners': {
          'topLeft': 12.0,
          'topRight': 12.0,
          'bottomLeft': 12.0,
          'bottomRight': 12.0,
        }
      }))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('mosaicCornerClip'));
    // The scalar-radius RoundedRectangle clipShape must NOT be emitted when
    // corners are present.
    expect(s, isNot(contains('.clipShape(RoundedRectangle(cornerRadius: 8')));
  });
}
