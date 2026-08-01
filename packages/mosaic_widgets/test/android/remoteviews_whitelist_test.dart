import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// RemoteViews only inflates classes annotated `@RemoteView`. Anything else
/// fails the WHOLE layout with "Class not allowed to be inflated", which the
/// launcher surfaces as "Can't load widget" — so a single stray view breaks the
/// widget entirely, not just that one element.
///
/// https://developer.android.com/reference/android/widget/RemoteViews
const remoteViewsWhitelist = {
  // Layouts
  'FrameLayout', 'GridLayout', 'LinearLayout', 'RelativeLayout',
  'AdapterViewFlipper', 'GridView', 'ListView', 'StackView', 'ViewFlipper',
  // Widgets
  'AnalogClock', 'Button', 'Chronometer', 'ImageButton', 'ImageView',
  'ProgressBar', 'TextClock', 'TextView',
};

void main() {
  test('spacers use a whitelisted view, not android.widget.Space', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWRow',
        'mainAxisAlignment': 'spaceBetween',
        'children': [text('a'), text('b')],
      })
    ]);
    final xml = r.file('android/app/src/main/res/layout/hw_testw.xml');
    expect(xml, isNot(contains('<Space')));
    expect(xml, contains('<FrameLayout'));
  });

  test('every view in a generated layout is inflatable by RemoteViews',
      () async {
    // Exercises the alignments and nodes that emit filler views.
    final r = await runAndroid([
      irDef(container({
        '__type': 'HWColumn',
        'mainAxisAlignment': 'spaceEvenly',
        'children': [
          {
            '__type': 'HWRow',
            'mainAxisAlignment': 'spaceAround',
            'children': [
              text('x'),
              {'__type': 'HWSpacer'},
              text('y')
            ],
          },
          {'__type': 'HWDivider'},
          {'__type': 'HWProgressBar', 'value': 50.0, 'max': 100.0},
        ],
      }))
    ]);

    final offenders = <String>{};
    for (final file in r.resXmlFiles()) {
      if (!file.path.contains('/layout/')) continue;
      for (final match
          in RegExp(r'<([A-Z][A-Za-z]*)').allMatches(file.readAsStringSync())) {
        final view = match.group(1)!;
        if (!remoteViewsWhitelist.contains(view)) offenders.add(view);
      }
    }
    expect(offenders, isEmpty,
        reason: 'not inflatable by RemoteViews: ${offenders.join(', ')}');
  });
}
