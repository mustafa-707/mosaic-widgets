import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  test('column with stretch makes children fill the horizontal cross axis',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'crossAxisAlignment': 'stretch',
        'children': [text('a'), text('b')],
      })
    ]);
    final xml = layout(r);
    // Both TextViews should get match_parent on the cross (width) axis.
    expect('android:layout_width="match_parent"'.allMatches(xml).length,
        greaterThanOrEqualTo(2));
  });

  test('column without stretch keeps default child cross-axis width', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [text('a')],
      })
    ]);
    final xml = layout(r);
    expect(xml, contains('<TextView'));
    expect(xml, contains('android:layout_width="wrap_content"'));
  });

  test('row with stretch makes children fill the vertical cross axis',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWRow',
        'crossAxisAlignment': 'stretch',
        'children': [text('a'), text('b')],
      })
    ]);
    final xml = layout(r);
    expect('android:layout_height="match_parent"'.allMatches(xml).length,
        greaterThanOrEqualTo(2));
  });
}
