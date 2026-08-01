import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/gen_harness.dart';

/// `MPositioned` picked a corner on iOS but ignored the distances entirely, so
/// `top: -34` and `top: 10` produced identical output — flush to the corner.
///
/// Android honours them as margins, so every decorative element (the discs bled
/// off the corners of ProfileVP, Crypto and Flashlight) sat correctly on
/// Android and wrongly on iOS. Caught by rendering the flashlight tile in the
/// simulator, where the halo appeared as a full circle rather than a corner
/// highlight.
IRDefinition _def(Map<String, dynamic> pos) => IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson({
        '__type': 'HWStack',
        'children': [
          {
            '__type': 'HWPositioned',
            ...pos,
            'child': {'__type': 'HWText', 'text': 'dot', 'style': {}},
          },
        ],
      }),
    );

void main() {
  Future<String> swift(Map<String, dynamic> pos) async =>
      (await runIos([_def(pos)])).swiftForTestW();

  test('a negative top-left bleeds off that corner', () async {
    final s = await swift({'top': -34.0, 'left': -34.0});
    expect(s, contains('alignment: .topLeading'));
    expect(s, contains('.offset(x: -34.0, y: -34.0)'));
  });

  test('a positive inset moves inward from the corner', () async {
    final s = await swift({'top': 10.0, 'left': 12.0});
    expect(s, contains('.offset(x: 12.0, y: 10.0)'));
  });

  test('a trailing inset moves the opposite way', () async {
    // right: -20 means 20 points *past* the trailing edge, which is +20 on x.
    final s = await swift({'top': -20.0, 'right': -20.0});
    expect(s, contains('alignment: .topTrailing'));
    expect(s, contains('.offset(x: 20.0, y: -20.0)'));
  });

  test('a bottom inset moves down when negative', () async {
    final s = await swift({'bottom': -8.0, 'right': 4.0});
    expect(s, contains('alignment: .bottomTrailing'));
    expect(s, contains('.offset(x: -4.0, y: 8.0)'));
  });

  test('no distances emit no offset at all', () async {
    // Nothing to move, so nothing should be added to the view chain.
    final s = await swift({'top': 0.0, 'left': 0.0});
    expect(s, isNot(contains('.offset(')));
  });
}
