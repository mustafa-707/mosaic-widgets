import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/gen_harness.dart';

Future<String> _swift(Map<String, dynamic> style) async {
  final def = IRDefinition(
    name: 'TestW',
    root:
        IRNode.fromJson({'__type': 'HWText', 'text': 'hello', 'style': style}),
    resizeMode: 'both',
  );
  return (await runIos([def])).swiftForTestW();
}

void main() {
  test('a bundled font becomes Font.custom with the style size', () async {
    final s = await _swift({
      'size': 14,
      'bold': true,
      'font': {'android': 'zain_bold', 'ios': 'Zain-Bold'},
    });
    expect(s, contains('.font(.custom("Zain-Bold", size: 14))'));
    // The font file is the weight: nothing is layered on top of it.
    expect(s, isNot(contains('.bold()')));
  });

  test('a font with no iOS name leaves the system font alone', () async {
    final s = await _swift({
      'size': 14,
      'font': {'android': 'zain_bold'},
    });
    expect(s, isNot(contains('.custom(')));
    expect(s, contains('.font(.system(size: 14))'));
  });

  test('an unsafe PostScript name cannot break out of the string', () async {
    final s = await _swift({
      'size': 14,
      'font': {'ios': 'X") + evil("'},
    });
    expect(s, isNot(contains('evil')));
    expect(s, isNot(contains('.custom(')));
  });
}
