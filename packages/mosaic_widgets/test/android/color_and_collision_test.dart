import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('duplicate lowercased names throw a collision error', () async {
    expect(
      () => runAndroid([
        irDef(text('a'), name: 'Weather'),
        irDef(text('b'), name: 'weather'),
      ]),
      throwsA(
          predicate((e) => e.toString().toLowerCase().contains('collision'))),
    );
  });

  test('container with missing hex falls back without throwing', () async {
    final r = await runAndroid([
      irDef(container(text('hi'), extra: {
        'background': {'opacity': 1.0}
      }))
    ]);
    expect(r.exists('android/app/src/main/res/layout/hw_testw.xml'), isTrue);
  });
}
