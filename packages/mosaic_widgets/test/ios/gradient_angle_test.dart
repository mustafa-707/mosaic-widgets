import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('gradient angle 0 maps left->right (.leading -> .trailing)', () async {
    final r = await runIos([
      irDef(container(text('hi'), extra: {
        'gradient': {
          '__type': 'HWLinearGradient',
          'colors': [
            {'hex': '#FF0000', 'opacity': 1.0},
            {'hex': '#0000FF', 'opacity': 1.0}
          ],
          'stops': null,
          'angle': 0.0,
        }
      }))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('startPoint:'));
    expect(s, contains('endPoint:'));
    expect(s, contains('UnitPoint(x: 0.0, y: 0.5)'));
    expect(s, contains('UnitPoint(x: 1.0, y: 0.5)'));
    // No longer hardcoded diagonal.
    expect(s, isNot(contains('startPoint: .topLeading')));
  });

  test('gradient angle 90 maps top->bottom', () async {
    final r = await runIos([
      irDef(container(text('hi'), extra: {
        'gradient': {
          '__type': 'HWLinearGradient',
          'colors': [
            {'hex': '#FF0000', 'opacity': 1.0},
            {'hex': '#0000FF', 'opacity': 1.0}
          ],
          'stops': null,
          'angle': 90.0,
        }
      }))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('UnitPoint(x: 0.5, y: 0.0)'));
    expect(s, contains('UnitPoint(x: 0.5, y: 1.0)'));
  });
}
