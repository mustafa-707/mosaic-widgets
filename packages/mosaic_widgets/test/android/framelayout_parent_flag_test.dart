import 'dart:io';

import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// `isInsideLinearLayout` describes a node's *immediate* parent. Handlers that
/// emit their own `FrameLayout` wrapper used to forward the flag they were
/// given, so the child sized itself for the Row or Column the wrapper sat in
/// rather than for the wrapper.
///
/// The visible symptom: an `MIcon` centred inside a fixed-size `MContainer`
/// rendered in the top-left corner, because `MCenter`'s outer box came out
/// `wrap_content` and had nothing to centre within.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  Map<String, dynamic> icon() => {
        '__type': 'HWIcon',
        'androidDrawable': 'ic_x',
        'size': 12.0,
      };

  Map<String, dynamic> centred(Map<String, dynamic> child) => {
        '__type': 'HWCenter',
        'child': child,
      };

  Map<String, dynamic> box(Map<String, dynamic> child) => {
        '__type': 'HWContainer',
        'width': 24.0,
        'height': 24.0,
        'child': child,
      };

  test('a centred icon in a fixed box gets a box to centre within', () async {
    // The Container sits in a Row, which is what used to leak through.
    final r = await runAndroid([
      irDef({
        '__type': 'HWRow',
        'children': [box(centred(icon()))],
      })
    ]);
    final xml = layout(r);
    // The Center's outer FrameLayout must fill the 24dp container. If it is
    // wrap_content, layout_gravity on the inner box centres nothing.
    expect(
      xml,
      contains(RegExp(
          r'android:layout_width="24\.0dp" android:layout_height="24\.0dp"[^>]*>\s*'
          r'<FrameLayout\s+android:layout_width="match_parent"'
          r' android:layout_height="match_parent">')),
      reason: 'MCenter inside a fixed MContainer must fill it',
    );
    expect(xml, contains('android:layout_gravity="center"'));
  });

  test('the same holds for MAlign', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWRow',
        'children': [
          box({
            '__type': 'HWAlign',
            'alignment': 'bottomEnd',
            'child': icon(),
          })
        ],
      })
    ]);
    expect(
      layout(r),
      contains(RegExp(r'<FrameLayout\s+android:layout_width="match_parent"'
          r' android:layout_height="match_parent">\s*<FrameLayout'
          r'[\s\S]{0,120}?android:layout_gravity="bottom\|end"')),
    );
  });

  test('a weighted MFlexible lets its child fill the space it won', () async {
    // Two buttons splitting a row evenly is the point of MFlexible; a
    // wrap_content child leaves them left-hugging and visibly uneven.
    final r = await runAndroid([
      irDef({
        '__type': 'HWRow',
        'children': [
          {
            '__type': 'HWFlexible',
            'child': centred(text('A')),
          },
        ],
      })
    ]);
    final xml = layout(r);
    expect(xml, contains('android:layout_weight='));
    expect(xml, contains('android:layout_width="match_parent"'));
  });

  test('no handler forwards a parent flag past its own FrameLayout', () {
    // A sweep, so a newly added wrapper fails here rather than on a home
    // screen. The generator source is the subject: any `nodeToXml(child, ...)`
    // that passes the flag it received is the bug this file exists for.
    final sources = [
      'lib/src/android/src/android_handlers.dart',
      'lib/src/android/src/android_widgets.dart',
      'lib/src/android/src/android_features.dart',
      'lib/src/android/src/android_emitters.dart',
    ];
    for (final path in sources) {
      final src = File(path).readAsStringSync();
      expect(
        src,
        isNot(contains(RegExp(
            r'nodeToXml\(\s*child\b[^)]*isInsideLinearLayout:\s*isInsideLinearLayout'))),
        reason: '$path forwards its own parent flag to a child it wraps',
      );
    }
  });
}
