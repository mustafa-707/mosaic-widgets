import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('gradient with stops emits Gradient(stops:) and .init(color:)',
      () async {
    final r = await runIos([
      irDef(container(text('hi'), extra: {
        'gradient': {
          '__type': 'HWLinearGradient',
          'colors': [
            {'hex': '#FF0000', 'opacity': 1.0},
            {'hex': '#0000FF', 'opacity': 1.0}
          ],
          'stops': [0.0, 1.0]
        }
      }))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('Gradient(stops:'));
    expect(s, contains('.init(color:'));
    expect(s, contains('location: 0.0'));
    expect(s, contains('location: 1.0'));
    expect(s, isNot(contains('Gradient(colors:')));
  });

  test('gradient without stops keeps Gradient(colors:)', () async {
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
    expect(s, contains('Gradient(colors:'));
    expect(s, isNot(contains('Gradient(stops:')));
  });
}
