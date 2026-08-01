import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('badge emits overlay topTrailing with Text + Capsule background',
      () async {
    final r = await runIos([
      irDef({
        '__type': 'HWBadge',
        'child': text('hi'),
        'count': 3,
        'color': {'hex': '#FF0000', 'opacity': 1.0},
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.overlay(alignment: .topTrailing'));
    expect(s, contains('Capsule()'));
    expect(s, contains('Text("3")'));
    expect(s, contains('red: 1.0, green: 0.0, blue: 0.0'));
  });

  test('badge with bound count resolves through bindSource', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWBadge',
        'child': text('hi'),
        'count': bind('unread'),
        'color': null,
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.overlay(alignment: .topTrailing'));
    expect(s, contains('entry.data["unread"]'));
  });
}
