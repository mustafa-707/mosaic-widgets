import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('HWListView generation throws a clear UnsupportedError', () async {
    expect(
      () => runAndroid([
        irDef({
          '__type': 'HWListView',
          'bind': {'__type': 'HWBind', 'key': 'items'},
          'itemTemplate': text('row'),
        })
      ]),
      throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains('HWListView'),
        ),
      ),
    );
  });
}
