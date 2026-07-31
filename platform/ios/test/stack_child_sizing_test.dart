import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// SwiftUI's analogue of the Android `match_parent`-in-a-row trap: a child with
/// an infinite frame inside an HStack/VStack takes all the space and squeezes
/// every sibling to its minimum. It is not invisible like the Android case, but
/// it is just as wrong — and it silently diverged from Android once the Android
/// side learned to size itself to its parent.
///
/// iOS handlers were parent-blind until this was found, so they could not have
/// matched Android's semantics at all.
void main() {
  Future<String> inRow(Map<String, dynamic> child) async {
    final r = await runIos([
      irDef({
        '__type': 'HWRow',
        'children': [child, text('sibling')],
      })
    ]);
    return r.swiftForTestW();
  }

  /// The stack body only, so the widget wrapper's own infinite frame — which is
  /// correct — does not count against the assertions.
  String stackBody(String swift) {
    final start = swift.indexOf('HStack');
    final end = swift.indexOf('}', swift.indexOf('sibling'));
    return swift.substring(start, end);
  }

  test('Center wraps inside a row instead of starving its siblings', () async {
    // Matches Flutter: an unconstrained Center just wraps its child.
    final body = stackBody(await inRow({
      '__type': 'HWCenter',
      'child': text('A'),
    }));
    expect(body, contains('Text("A")'));
    expect(body, isNot(contains('.infinity')));
  });

  test('Align claims only the cross axis inside a row', () async {
    // Filling the main axis too would leave nothing for the siblings.
    final body = stackBody(await inRow({
      '__type': 'HWAlign',
      'alignment': 'topStart',
      'child': text('A'),
    }));
    expect(body, contains('maxHeight: .infinity'));
    expect(body, isNot(contains('maxWidth: .infinity')));
  });

  test('Align claims only the cross axis inside a column', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWColumn',
        'children': [
          {'__type': 'HWAlign', 'alignment': 'centerEnd', 'child': text('A')},
          text('sibling'),
        ],
      })
    ]);
    final swift = r.swiftForTestW();
    final start = swift.indexOf('VStack');
    final body = swift.substring(start, swift.indexOf('}', swift.indexOf('sibling')));
    expect(body, contains('maxWidth: .infinity'));
    expect(body, isNot(contains('maxHeight: .infinity')));
  });

  test('Center still fills when it is not inside a stack', () async {
    // As the root it must claim the whole widget, exactly as before.
    final r = await runIos([
      irDef({'__type': 'HWCenter', 'child': text('A')})
    ]);
    expect(r.swiftForTestW(),
        contains('.frame(maxWidth: .infinity, maxHeight: .infinity)'));
  });

  test('Flexible still fills, because that is its whole purpose', () async {
    final body = stackBody(await inRow({
      '__type': 'HWFlexible',
      'flex': 1,
      'child': text('A'),
    }));
    expect(body, contains('.infinity'));
  });
}
