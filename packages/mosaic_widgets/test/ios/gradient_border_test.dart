import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('gradient container emits LinearGradient', () async {
    final r = await runIos([
      irDef(container(text('hi'), extra: {
        'gradient': {
          '__type': 'HWLinearGradient',
          'colors': [
            {'hex': '#FF0000', 'opacity': 1.0},
            {'hex': '#0000FF', 'opacity': 1.0}
          ],
          'stops': null
        }
      }))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('LinearGradient'));
    expect(s, contains('Gradient(colors:'));
    // No angle key → default 0° → left→right (leading → trailing).
    expect(s, contains('startPoint: UnitPoint(x: 0.0, y: 0.5)'));
    expect(s, contains('endPoint: UnitPoint(x: 1.0, y: 0.5)'));
    // both colors present (red and blue, opacity honored)
    expect(s, contains('red: 1.0, green: 0.0, blue: 0.0'));
    expect(s, contains('red: 0.0, green: 0.0, blue: 1.0'));
    expect(s, contains('opacity: 1.0'));
  });

  test('border container emits a stroke overlay', () async {
    final r = await runIos([
      irDef(container(text('hi'), extra: {
        'border': {
          'color': {'hex': '#00FF00', 'opacity': 1.0},
          'width': 2.0
        },
        'radius': 8.0
      }))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('stroke'));
    expect(s, contains('.overlay(RoundedRectangle(cornerRadius: 8'));
    expect(s, contains('red: 0.0, green: 1.0, blue: 0.0'));
    expect(s, contains('lineWidth: 2'));
  });
}
