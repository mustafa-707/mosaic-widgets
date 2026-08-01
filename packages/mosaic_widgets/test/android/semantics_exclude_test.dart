import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// `MSemantics(excludeChildren: true)` collapses a subtree to one accessibility
/// element, so a screen reader announces "Battery level, 71 percent" rather than
/// walking every text fragment and the unlabelled bar separately.
///
/// It was iOS-only, on the stated grounds that RemoteViews cannot mark
/// descendants unimportant. RemoteViews restricts which *classes* may be
/// inflated, not which attributes they carry: `importantForAccessibility` is a
/// plain View attribute the LayoutInflater resolves, in a layout this generator
/// writes itself.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  Map<String, dynamic> semantics(String label,
          {required bool exclude, required Map<String, dynamic> child}) =>
      {
        '__type': 'HWSemantics',
        'label': label,
        'excludeChildren': exclude,
        'child': child,
      };

  test('excludeChildren hides the subtree from the screen reader', () async {
    final r = await runAndroid([
      irDef(semantics('Battery level', exclude: true, child: {
        '__type': 'HWColumn',
        'children': [text('71'), text('%')],
      }))
    ]);
    final xml = layout(r);
    expect(
        xml, contains('android:importantForAccessibility="noHideDescendants"'));
    // The label still has to be announced — hiding the children without one
    // would leave an element a screen reader cannot name at all.
    expect(xml, contains('android:contentDescription="Battery level"'));
  });

  test('the default leaves children individually readable', () async {
    final r = await runAndroid(
        [irDef(semantics('Battery level', exclude: false, child: text('71')))]);
    expect(layout(r), isNot(contains('importantForAccessibility')));
  });

  test('it applies alongside a bound label', () async {
    // A bind-form label resolves at update time via a view id, which is a
    // separate code path from the static contentDescription attribute.
    final r = await runAndroid(
        [irDef(semantics2(bind('status'), exclude: true, child: text('x')))]);
    final xml = layout(r);
    expect(
        xml, contains('android:importantForAccessibility="noHideDescendants"'));
    expect(xml, contains('@+id/hw_a11y_status'));
  });
}

Map<String, dynamic> semantics2(Object label,
        {required bool exclude, required Map<String, dynamic> child}) =>
    {
      '__type': 'HWSemantics',
      'label': label,
      'excludeChildren': exclude,
      'child': child,
    };
