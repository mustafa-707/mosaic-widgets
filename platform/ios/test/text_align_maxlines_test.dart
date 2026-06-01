import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('text with maxLines emits .lineLimit', () async {
    final r = await runIos([
      irDef(text('hello', style: {'maxLines': 2}))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.lineLimit(2)'));
  });

  test('text align center emits .multilineTextAlignment(.center)', () async {
    final r = await runIos([
      irDef(text('hello', style: {'align': 'center'}))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.multilineTextAlignment(.center)'));
  });

  test('text align start maps to leading, end maps to trailing', () async {
    final rStart = await runIos([irDef(text('a', style: {'align': 'start'}))]);
    expect(rStart.swiftForTestW(),
        contains('.multilineTextAlignment(.leading)'));
    final rEnd = await runIos([irDef(text('b', style: {'align': 'end'}))]);
    expect(rEnd.swiftForTestW(), contains('.multilineTextAlignment(.trailing)'));
  });

  test('text without maxLines/align omits the modifiers', () async {
    final r = await runIos([irDef(text('plain'))]);
    final s = r.swiftForTestW();
    expect(s, isNot(contains('.lineLimit(')));
    expect(s, isNot(contains('.multilineTextAlignment(')));
  });
}
