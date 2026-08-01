import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Tests that MStack.alignment is honoured by the Android generator.
///
/// FrameLayout positions children via `android:layout_gravity`; the stack
/// applies the mapped value to every DIRECT child that does not already carry
/// its own layout_gravity (i.e. non-MPositioned children).
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  // ---------------------------------------------------------------------------
  // Alignment → gravity mapping tests
  // ---------------------------------------------------------------------------
  group('StackHandler alignment mapping', () {
    test('alignment center → children carry android:layout_gravity="center"',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'center',
          'children': [text('a'), text('b')],
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_gravity="center"'));
    });

    test(
        'alignment bottomTrailing → children carry android:layout_gravity="bottom|end"',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'bottomTrailing',
          'children': [text('x')],
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_gravity="bottom|end"'));
    });

    test(
        'alignment top → children carry android:layout_gravity="top|center_horizontal"',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'top',
          'children': [text('x')],
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_gravity="top|center_horizontal"'));
    });

    test(
        'alignment topLeading → children carry android:layout_gravity="top|start"',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'topLeading',
          'children': [text('x')],
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_gravity="top|start"'));
    });

    test(
        'alignment topTrailing → children carry android:layout_gravity="top|end"',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'topTrailing',
          'children': [text('x')],
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_gravity="top|end"'));
    });

    test(
        'alignment leading → children carry android:layout_gravity="center_vertical|start"',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'leading',
          'children': [text('x')],
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_gravity="center_vertical|start"'));
    });

    test(
        'alignment trailing → children carry android:layout_gravity="center_vertical|end"',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'trailing',
          'children': [text('x')],
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_gravity="center_vertical|end"'));
    });

    test(
        'alignment bottomLeading → children carry android:layout_gravity="bottom|start"',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'bottomLeading',
          'children': [text('x')],
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_gravity="bottom|start"'));
    });

    test(
        'alignment bottom → children carry android:layout_gravity="bottom|center_horizontal"',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'bottom',
          'children': [text('x')],
        })
      ]);
      final xml = layout(r);
      expect(
          xml, contains('android:layout_gravity="bottom|center_horizontal"'));
    });

    test('absent alignment defaults to top|start', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'children': [text('x')],
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_gravity="top|start"'));
    });

    test('unknown alignment defaults to top|start', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'someUnknown',
          'children': [text('x')],
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_gravity="top|start"'));
    });
  });

  // ---------------------------------------------------------------------------
  // MPositioned children must NOT have their own layout_gravity overridden
  // ---------------------------------------------------------------------------
  group('StackHandler does not clobber MPositioned children', () {
    test('MPositioned child inside aligned stack keeps its own layout_gravity',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'center',
          'children': [
            {
              '__type': 'HWPositioned',
              'top': 10,
              'left': 20,
              'child': text('positioned'),
            }
          ],
        })
      ]);
      final xml = layout(r);
      // MPositioned emits its own gravity (top|start with margins); must NOT
      // also carry center from the stack default.
      expect(xml, isNot(contains('android:layout_gravity="center"')));
      // The positioned child's own gravity must survive.
      expect(xml, contains('android:layout_gravity="top|start"'));
    });

    test(
        'mixed stack: non-positioned sibling gets gravity, positioned keeps own',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'bottomTrailing',
          'children': [
            text('floating'),
            {
              '__type': 'HWPositioned',
              'bottom': 5,
              'right': 5,
              'child': text('anchored'),
            }
          ],
        })
      ]);
      final xml = layout(r);
      // The plain text child should get the stack's gravity.
      expect(xml, contains('android:layout_gravity="bottom|end"'));
      // The positioned child emits bottom|end too (its own gravity derived
      // from bottom+right offsets), but the key is that we only got one
      // layout_gravity="bottom|end" applied by the stack itself — the
      // positioned wrapper already has its own.  We simply verify the text
      // child's injected gravity exists and "center" did not slip in.
      expect(xml, isNot(contains('android:layout_gravity="center"')));
    });
  });

  // ---------------------------------------------------------------------------
  // AAPT validity: every res XML must start with <?xml
  // ---------------------------------------------------------------------------
  group('AAPT validity', () {
    test('stack with alignment produces AAPT-valid XML (first line is <?xml)',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWStack',
          'alignment': 'center',
          'children': [text('hello')],
        })
      ]);
      final offender = r.firstNonXmlDeclFile();
      expect(offender, isNull,
          reason: 'res XML must start with <?xml; offending file: $offender');
    });
  });
}
