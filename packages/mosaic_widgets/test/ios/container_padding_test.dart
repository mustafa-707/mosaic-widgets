import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// The iOS container already handled a `padding` key; this locks in that the
/// DSL now actually sends it, and that it lands inside the background.
void main() {
  Map<String, dynamic> container(Map<String, dynamic>? padding) => {
        '__type': 'HWContainer',
        'radius': 0,
        'child': {'__type': 'HWText', 'text': 'hi'},
        if (padding != null) 'padding': padding,
      };

  test('padding maps to EdgeInsets with leading/trailing', () async {
    final r = await runIos([
      irDef(container({'left': 8, 'top': 4, 'right': 12, 'bottom': 6}))
    ]);
    final swift = r.swiftForTestW();
    expect(
        swift,
        contains(
            '.padding(EdgeInsets(top: 4, leading: 8, bottom: 6, trailing: 12))'));
  });

  test('omitted sides default to 0', () async {
    final r = await runIos([
      irDef(container({'top': 5}))
    ]);
    expect(
        r.swiftForTestW(),
        contains(
            '.padding(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0))'));
  });

  test('no padding emits no padding modifier', () async {
    final r = await runIos([irDef(container(null))]);
    expect(r.swiftForTestW(), isNot(contains('.padding(EdgeInsets(')));
  });
}
