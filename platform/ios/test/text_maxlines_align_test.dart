import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('maxLines emits lineLimit', () async {
    final r = await runIos([irDef({'__type':'HWText','text':'hello',
      'style': <String,dynamic>{}, 'maxLines': 2, 'align': null})]);
    expect(r.swiftForTestW(), contains('.lineLimit(2)'));
  });
  test('align emits multilineTextAlignment', () async {
    final r = await runIos([irDef({'__type':'HWText','text':'hi',
      'style': <String,dynamic>{}, 'maxLines': null, 'align': 'center'})]);
    expect(r.swiftForTestW(), contains('.multilineTextAlignment(.center)'));
  });
}
