import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// ViewFlipper is the only self-advancing container an app widget can use: it is
/// `@RemoteView`, and with autoStart the system cycles it without the app
/// running.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  Map<String, dynamic> flipper(List<Map<String, dynamic>> children,
          {int intervalMs = 4000}) =>
      {'__type': 'HWFlipper', 'children': children, 'intervalMs': intervalMs};

  test('emits a self-advancing ViewFlipper with every child', () async {
    final r = await runAndroid([
      irDef(flipper([text('one'), text('two'), text('three')]))
    ]);
    final xml = layout(r);
    expect(xml, contains('<ViewFlipper'));
    expect(xml, contains('android:autoStart="true"'));
    expect(xml, contains('android:flipInterval="4000"'));
    for (final label in ['one', 'two', 'three']) {
      expect(xml, contains('android:text="$label"'));
    }
  });

  test('honours a custom interval', () async {
    final r = await runAndroid([
      irDef(flipper([text('a'), text('b')], intervalMs: 1500))
    ]);
    expect(layout(r), contains('android:flipInterval="1500"'));
  });

  test('an empty flipper degrades to a comment rather than broken XML',
      () async {
    final r = await runAndroid([irDef(flipper([]))]);
    final xml = layout(r);
    expect(xml, contains('flipper has no children'));
    expect(xml, isNot(contains('<ViewFlipper')));
  });

  test('ViewFlipper is inflatable by RemoteViews', () async {
    final r = await runAndroid([irDef(flipper([text('a'), text('b')]))]);
    final xml = layout(r);
    expect(xml, isNot(contains('<Space')));
    expect(xml, isNot(contains('<View ')));
  });

  test('children do not carry layout weights — a flipper is a FrameLayout',
      () async {
    final r = await runAndroid([
      irDef(flipper([
        {
          '__type': 'HWRow',
          'mainAxisAlignment': 'spaceBetween',
          'children': [text('a'), text('b')],
        },
      ]))
    ]);
    final xml = layout(r);
    final flipperStart = xml.indexOf('<ViewFlipper');
    final flipperEnd = xml.indexOf('</ViewFlipper>');
    final body = xml.substring(flipperStart, flipperEnd);
    // The Row inside must not be told to fill a non-existent weighted axis.
    expect(body, contains('<LinearLayout'));
  });
}
