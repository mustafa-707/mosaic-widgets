import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Several nodes emit `if #available(...) { … } else { … }` — availability
/// gates, visibility, cached network images. A parent then appends
/// `.padding(...)` or `.frame(...)`, and applying a modifier to a *statement*
/// is not valid Swift:
///
///     consecutive statements on a line must be separated by ';'
///
/// Wrapping at dispatch turns any such statement back into one view. This
/// guards the whole class, not one node.
void main() {
  Map<String, dynamic> padded(Map<String, dynamic> child) => container(
        child,
        extra: {
          'padding': {'top': 8.0, 'left': 8.0, 'bottom': 8.0, 'right': 8.0},
        },
      );

  test('a button inside a padded container is wrapped', () async {
    final r = await runIos([
      irDef(padded({
        '__type': 'HWButton',
        'child': text('go'),
        'action': {'__type': 'HWActionCallback', 'callbackName': 'refresh'},
      }))
    ]);
    final swift = r.swiftForTestW();
    expect(swift, contains('Group {'));
    // The modifier must attach to the Group's brace, never to an `if`.
    expect(swift, isNot(contains('}.padding(EdgeInsets')));
  });

  test('visibility inside a padded container is wrapped', () async {
    final r = await runIos([
      irDef(padded({
        '__type': 'HWVisibility',
        'bind': bind('flag'),
        'child': text('shown'),
      }))
    ]);
    expect(r.swiftForTestW(), isNot(contains('}.padding(EdgeInsets')));
  });

  test('a network image inside a padded container is wrapped', () async {
    final r = await runIos([
      irDef(padded({
        '__type': 'HWNetworkImage',
        'url': 'https://a/b.jpg',
      }))
    ]);
    expect(r.swiftForTestW(), isNot(contains('}.padding(EdgeInsets')));
  });

  test('a toggle button inside a padded container is wrapped', () async {
    final r = await runIos([
      irDef(padded({
        '__type': 'HWButton',
        'child': text('°C/°F'),
        'action': {'__type': 'HWToggleAction', 'key': 'unit_f'},
      }))
    ]);
    expect(r.swiftForTestW(), isNot(contains('}.padding(EdgeInsets')));
  });

  test('plain views are not wrapped', () async {
    final r = await runIos([irDef(padded(text('plain')))]);
    expect(r.swiftForTestW(), isNot(contains('Group {')));
  });
}
