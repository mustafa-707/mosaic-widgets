import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('Column with crossAxisAlignment stretch generates and contains stretch comment', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWColumn',
        'children': [
          {'__type': 'HWText', 'text': 'hi', 'style': <String, dynamic>{}}
        ],
        'mainAxisAlignment': 'start',
        'crossAxisAlignment': 'stretch',
      })
    ]);
    final s = r.swiftForTestW();
    // stretch falls through to .center alignment (SwiftUI can't stretch children)
    expect(s, contains('VStack('));
    expect(s, contains('// stretch approximated as center'));
  });

  test('Row with crossAxisAlignment stretch generates and contains stretch comment', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWRow',
        'children': [
          {'__type': 'HWText', 'text': 'hi', 'style': <String, dynamic>{}}
        ],
        'mainAxisAlignment': 'start',
        'crossAxisAlignment': 'stretch',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('HStack('));
    expect(s, contains('// stretch approximated as center'));
  });
}
