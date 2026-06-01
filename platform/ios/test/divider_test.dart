import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('horizontal divider emits Rectangle with thickness height + indent', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWDivider',
        'thickness': 2.0,
        'color': {'hex': '#FF0000', 'opacity': 1.0},
        'vertical': false,
        'indent': 8.0,
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('Rectangle()'));
    expect(s, contains('.frame(height: 2.0)'));
    expect(s, contains('.padding(.horizontal, 8.0)'));
    expect(s, contains('red: 1.0, green: 0.0, blue: 0.0'));
  });

  test('vertical divider emits Rectangle with thickness width', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWDivider',
        'thickness': 3.0,
        'color': null,
        'vertical': true,
        'indent': 4.0,
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('Rectangle()'));
    expect(s, contains('.frame(width: 3.0)'));
    expect(s, contains('.padding(.vertical, 4.0)'));
  });
}
