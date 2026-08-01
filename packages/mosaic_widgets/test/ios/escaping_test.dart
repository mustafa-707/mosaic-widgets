import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('static text is Swift-escaped', () async {
    final r = await runIos([irDef(text('say "hi" \\ end'))]);
    final swift = r.swiftForTestW();
    expect(swift, contains(r'\"hi\"'));
    expect(swift, contains(r'\\ end'));
  });

  test('generation throws a clear error when config widget is missing', () {
    expect(
      () => runIos([irDef(text('x'), name: 'Ghost')], skipConfigWidget: true),
      throwsA(predicate((e) => e.toString().contains('Ghost'))),
    );
  });
}
