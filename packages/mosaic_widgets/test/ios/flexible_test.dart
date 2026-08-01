import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('a flexible child claims the free space', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWRow',
        'children': [
          {'__type': 'HWFlexible', 'flex': 1, 'child': text('a')},
        ],
      })
    ]);
    final swift = r.swiftForTestW();
    expect(swift, contains('Text("a")'));
    expect(
        swift, contains('.frame(maxWidth: .infinity, maxHeight: .infinity)'));
  });

  test('flex ratios are not faked with GeometryReader arithmetic', () async {
    // SwiftUI has no proportional flex; inventing one from geometry would break
    // the moment the widget renders at another family size. The limit is
    // documented on MFlexible instead.
    final r = await runIos([
      irDef({
        '__type': 'HWRow',
        'children': [
          {'__type': 'HWFlexible', 'flex': 3, 'child': text('a')},
          {'__type': 'HWFlexible', 'flex': 1, 'child': text('b')},
        ],
      })
    ]);
    final swift = r.swiftForTestW();
    expect(swift, isNot(contains('* 3')));
    expect(swift, isNot(contains('0.75')));
    // Both siblings ask for the space equally.
    expect(
        '.frame(maxWidth: .infinity, maxHeight: .infinity)'
            .allMatches(swift)
            .length,
        greaterThanOrEqualTo(2));
  });
}
