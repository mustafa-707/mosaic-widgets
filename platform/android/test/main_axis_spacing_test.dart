import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

Map<String, dynamic> column(
  List<Map<String, dynamic>> children, {
  String? mainAxisAlignment,
  String? crossAxisAlignment,
}) =>
    {
      '__type': 'HWColumn',
      'children': children,
      if (mainAxisAlignment != null) 'mainAxisAlignment': mainAxisAlignment,
      if (crossAxisAlignment != null) 'crossAxisAlignment': crossAxisAlignment,
    };

Map<String, dynamic> row(
  List<Map<String, dynamic>> children, {
  String? mainAxisAlignment,
  String? crossAxisAlignment,
}) =>
    {
      '__type': 'HWRow',
      'children': children,
      if (mainAxisAlignment != null) 'mainAxisAlignment': mainAxisAlignment,
      if (crossAxisAlignment != null) 'crossAxisAlignment': crossAxisAlignment,
    };

void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  test('column spaceBetween emits weighted Space spacers between children only',
      () async {
    final r = await runAndroid([
      irDef(column([text('a'), text('b'), text('c')],
          mainAxisAlignment: 'spaceBetween'))
    ]);
    final xml = layout(r);
    // 3 children => 2 spacers between them.
    expect('<Space '.allMatches(xml).length, 2);
    expect(xml, contains('android:layout_weight="1"'));
  });

  test('column spaceEvenly emits equal spacers before/between/after', () async {
    final r = await runAndroid([
      irDef(column([text('a'), text('b')], mainAxisAlignment: 'spaceEvenly'))
    ]);
    final xml = layout(r);
    // 2 children => 3 spacers (before, between, after).
    expect('<Space '.allMatches(xml).length, 3);
    expect(xml, contains('android:layout_weight="1"'));
  });

  test('column spaceAround emits approximation comment and spacers', () async {
    final r = await runAndroid([
      irDef(column([text('a'), text('b')], mainAxisAlignment: 'spaceAround'))
    ]);
    final xml = layout(r);
    expect(xml, contains('spaceAround approximated'));
    expect(xml, contains('<Space '));
    expect(xml, contains('android:layout_weight'));
  });

  test('row spaceBetween emits weighted spacers between children', () async {
    final r = await runAndroid([
      irDef(row([text('a'), text('b')], mainAxisAlignment: 'spaceBetween'))
    ]);
    final xml = layout(r);
    expect('<Space '.allMatches(xml).length, 1);
    expect(xml, contains('android:layout_weight="1"'));
  });

  test('spacers carry the right cross-axis dimension for vertical column',
      () async {
    final r = await runAndroid([
      irDef(column([text('a'), text('b')], mainAxisAlignment: 'spaceBetween'))
    ]);
    final xml = layout(r);
    // Vertical: spacer grows on height (0dp + weight), width wrap_content.
    expect(xml, contains('<Space android:layout_width="wrap_content"'));
    expect(xml, contains('android:layout_height="0dp"'));
  });
}
