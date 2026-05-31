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
    // diagonal start/end points per spec
    expect(s, contains('startPoint: .topLeading'));
    expect(s, contains('endPoint: .bottomTrailing'));
    // both colors present
    expect(s, contains('Color(hex: "#FF0000")'));
    expect(s, contains('Color(hex: "#0000FF")'));
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
    expect(s, contains('Color(hex: "#00FF00")'));
    expect(s, contains('lineWidth: 2'));
  });
}
