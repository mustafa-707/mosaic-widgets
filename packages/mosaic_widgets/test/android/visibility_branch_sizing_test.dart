import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// An `MVisibility` with a replacement renders both branches and toggles them.
/// Both are alternative roots of one slot, so they have to size identically and
/// fill it — otherwise toggling visibly resizes the widget.
///
/// Found on a 1x1 flashlight tile: the shown branch filled the cell and the
/// hidden one hugged its icon, so the tile rendered as a small circle in the
/// corner instead of a full-bleed button.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  Map<String, dynamic> filled(String hex) => {
        '__type': 'HWContainer',
        'radius': 20.0,
        'background': {'hex': hex, 'opacity': 1.0},
        'child': text('x'),
      };

  Map<String, dynamic> toggle() => {
        '__type': 'HWVisibility',
        'bind': {'__type': 'HWBind', 'key': 'on'},
        'child': filled('#FDE047'),
        'replacement': filled('#334155'),
      };

  test('both branch wrappers fill the slot', () async {
    final xml = layout(await runAndroid([irDef(toggle())]));
    for (final id in ['hw_visibility_on', 'hw_visibility_on_alt']) {
      final at = xml.indexOf('@+id/$id"');
      expect(at, greaterThan(-1), reason: '$id missing');
      final decl = xml.substring(at, at + 140);
      expect(decl, contains('android:layout_width="match_parent"'),
          reason: '$id does not fill');
      expect(decl, contains('android:layout_height="match_parent"'),
          reason: '$id does not fill');
    }
  });

  test('both branches size the same, so toggling does not resize', () async {
    // The root-fill flag is consumed by the first container it reaches. Without
    // restoring it for the second branch, the shown one was match_parent and
    // the hidden one wrap_content.
    final xml = layout(await runAndroid([irDef(toggle())]));
    final widths = RegExp(r'hw_bg_\d+"\s*>\s*|android:layout_width="(\w+)"')
        .allMatches(xml);
    expect(widths, isNotEmpty);
    // Both branch containers carry a rounded background; neither may be
    // wrap_content while the other fills.
    final containers = RegExp(
            r'android:layout_width="(\w+)" android:layout_height="\w+"\s*\n?\s*android:background="@drawable/hw_bg_')
        .allMatches(xml)
        .map((m) => m.group(1))
        .toList();
    expect(containers.length, 2, reason: 'expected one box per branch');
    expect(containers.first, equals(containers.last),
        reason: 'branches disagree on size: $containers');
  });

  test('inside a Column the slot still sizes to the axis', () async {
    // The fill only applies to the inner wrappers; the outer slot keeps the
    // Column sizing so siblings are not displaced.
    final xml = layout(await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [text('above'), toggle(), text('below')],
      })
    ]));
    expect(xml, contains('above'));
    expect(xml, contains('below'));
    expect(xml, contains('@+id/hw_visibility_on_alt'));
  });
}
