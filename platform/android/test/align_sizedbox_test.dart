import 'package:mosaic_android/mosaic_android.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// `MSizedBox` and `MAlign` are the two Flutter primitives developers reach for
/// first and previously had no equivalent — a fixed gap meant an MContainer with
/// a dummy child, and any alignment other than centre was impossible.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  group('MSizedBox', () {
    test('an empty box is a gap of exactly the size asked for', () async {
      final r = await runAndroid([
        irDef({'__type': 'HWSizedBox', 'width': 12, 'height': 8})
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_width="12dp"'));
      expect(xml, contains('android:layout_height="8dp"'));
    });

    test('it is a FrameLayout, which RemoteViews can inflate', () async {
      // Space and View are both rejected by the RemoteViews whitelist.
      final r = await runAndroid([
        irDef({'__type': 'HWSizedBox', 'height': 8})
      ]);
      final xml = layout(r);
      expect(xml, contains('<FrameLayout'));
      expect(xml, isNot(contains('<Space')));
      expect(xml, isNot(contains('<View ')));
    });

    test('an unset axis adopts the parent constraint, as in Flutter', () async {
      // A height-only box spans the width, like SizedBox(height:) in a Column.
      // Hard-coding wrap_content collapsed a full-width pill to its content.
      final r = await runAndroid([
        irDef({'__type': 'HWSizedBox', 'height': 8})
      ]);
      expect(layout(r), contains('android:layout_height="8dp"'));
      expect(layout(r), contains('android:layout_width="match_parent"'));
    });

    test('a horizontal gap in a row does not swallow the row', () async {
      // The original worry behind wrap_content. It cannot happen: for a gap the
      // main axis is the explicit one, so only the cross axis ever fills.
      final r = await runAndroid([
        irDef({
          '__type': 'HWRow',
          'children': [
            {'__type': 'HWSizedBox', 'width': 8},
            text('after'),
          ],
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_width="8dp"'));
      // Cross axis wraps inside a row; a match_parent height would collapse it.
      expect(xml, contains('android:layout_width="8dp" android:layout_height="wrap_content"'));
      expect(xml, contains('after'));
    });

    test('a vertical gap in a column spans the width', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWColumn',
          'children': [
            {'__type': 'HWSizedBox', 'height': 8},
            text('after'),
          ],
        })
      ]);
      expect(
        layout(r),
        contains('android:layout_width="match_parent" android:layout_height="8dp"'),
      );
    });

    test('a child is constrained to the box', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWSizedBox',
          'width': 40,
          'height': 40,
          'child': text('hi'),
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_width="40dp"'));
      expect(xml, contains('hi'));
    });
  });

  group('MAlign', () {
    test('alignment uses start/end so it mirrors in RTL', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWAlign',
          'alignment': 'bottomEnd',
          'child': text('hi'),
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_gravity="bottom|end"'));
      expect(xml, isNot(contains('right')));
    });

    test('layout_gravity is on the child, not gravity on the parent', () async {
      // FrameLayout ignores android:gravity for child positioning.
      final r = await runAndroid([
        irDef({'__type': 'HWAlign', 'alignment': 'center', 'child': text('x')})
      ]);
      expect(layout(r), contains('android:layout_gravity="center"'));
    });

    test('every alignment maps to a distinct gravity', () {
      const names = [
        'topStart', 'topCenter', 'topEnd',
        'centerStart', 'center', 'centerEnd',
        'bottomStart', 'bottomCenter', 'bottomEnd',
      ];
      final mapped = names.map(alignmentGravity).toList();
      expect(mapped.toSet().length, names.length);
    });

    test('an unknown alignment falls back to centre', () {
      expect(alignmentGravity(null), 'center');
      expect(alignmentGravity('nonsense'), 'center');
    });
  });
}
