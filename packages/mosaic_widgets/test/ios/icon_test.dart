import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('icon emits Image(systemName:) with size + color', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWIcon',
        'sfSymbol': 'star.fill',
        'androidDrawable': null,
        'size': 18.0,
        'color': {'hex': '#00FF00', 'opacity': 1.0},
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('Image(systemName: "star.fill")'));
    expect(s, contains('.font(.system(size: 18.0))'));
    expect(s, contains('.foregroundColor('));
    expect(s, contains('red: 0.0, green: 1.0, blue: 0.0'));
  });

  test('icon with null sfSymbol falls back to placeholder system name',
      () async {
    final r = await runIos([
      irDef({
        '__type': 'HWIcon',
        'sfSymbol': null,
        'androidDrawable': 'ic_foo',
        'size': 24.0,
        'color': null,
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('Image(systemName: "questionmark")'));
  });
}
