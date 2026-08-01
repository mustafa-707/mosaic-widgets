import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('Row spaceAround emits a visibility comment', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWRow',
        'mainAxisAlignment': 'spaceAround',
        'children': [text('a'), text('b')],
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('HStack'));
    expect(s, contains('spaceAround'));
  });

  test('Row spaceEvenly does not carry the spaceAround comment', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWRow',
        'mainAxisAlignment': 'spaceEvenly',
        'children': [text('a'), text('b')],
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, isNot(contains('spaceAround')));
  });
}
