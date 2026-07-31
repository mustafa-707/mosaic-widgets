import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  test('visibility with replacement emits two views toggled inversely',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWVisibility',
        'bind': {'__type': 'HWBind', 'key': 'show'},
        'child': text('shown'),
        'replacement': text('hidden'),
      })
    ]);
    final xml = layout(r);
    // Two container views: the child view and the replacement view.
    expect(xml, contains('@+id/hw_visibility_show'));
    expect(xml, contains('@+id/hw_visibility_show_alt'));

    final kt = provider(r);
    // child visible when true
    expect(
        kt,
        contains(
            'views.setViewVisibility(R.id.hw_visibility_show, if (MosaicData.resolveBool(context, "show")) android.view.View.VISIBLE else android.view.View.GONE)'));
    // replacement visible when false (inverse)
    expect(
        kt,
        contains(
            'views.setViewVisibility(R.id.hw_visibility_show_alt, if (MosaicData.resolveBool(context, "show")) android.view.View.GONE else android.view.View.VISIBLE)'));
  });

  test('visibility without replacement keeps single GONE-toggle behavior',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWVisibility',
        'bind': {'__type': 'HWBind', 'key': 'show'},
        'child': text('shown'),
      })
    ]);
    final xml = layout(r);
    expect(xml, contains('@+id/hw_visibility_show'));
    expect(xml, isNot(contains('hw_visibility_show_alt')));

    final kt = provider(r);
    expect(kt, isNot(contains('_alt')));
  });

  test(
      'visibility+replacement inside spaceBetween Column occupies one slot wrapped in a single FrameLayout',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'mainAxisAlignment': 'spaceBetween',
        'children': [
          {
            '__type': 'HWVisibility',
            'bind': {'__type': 'HWBind', 'key': 'show'},
            'child': text('shown'),
            'replacement': text('hidden'),
          },
          text('other'),
        ],
      })
    ]);
    final xml = layout(r);

    // The two toggled ids live inside a single wrapper FrameLayout. Find the
    // wrapper that opens before hw_visibility_show and confirm both ids and the
    // close tag fall within one element (no intervening sibling at column level).
    final showIdx = xml.indexOf('hw_visibility_show"');
    final altIdx = xml.indexOf('hw_visibility_show_alt"');
    expect(showIdx, greaterThanOrEqualTo(0));
    expect(altIdx, greaterThan(showIdx));

    final otherIdx = xml.indexOf('android:text="other"');
    expect(otherIdx, greaterThan(altIdx));

    // Single slot: the visibility node must render as ONE container element, not
    // two sibling FrameLayouts. Within the region from the slot start up to the
    // spacer/next child there must be a wrapper FrameLayout enclosing BOTH ids,
    // i.e. three opening <FrameLayout tags (wrapper + child + alt) closed by
    // three </FrameLayout> tags before the spacer.
    // Spacers are FrameLayouts carrying a weight — structural ones are not.
    final spacer = RegExp(r'<FrameLayout [^>]*android:layout_weight=');
    final spacerIdx = spacer.firstMatch(xml)!.start;
    // The child's own FrameLayout open tag is the one immediately preceding its
    // id; the wrapper is the FrameLayout open tag before THAT.
    final childOpen = xml.lastIndexOf('<FrameLayout', showIdx);
    final wrapperOpen = xml.lastIndexOf('<FrameLayout', childOpen - 1);
    expect(wrapperOpen, greaterThanOrEqualTo(0));
    // The wrapper open tag is distinct from the two id'd FrameLayouts.
    expect(wrapperOpen, lessThan(showIdx));
    final slotRegion = xml.substring(wrapperOpen, spacerIdx);
    expect('<FrameLayout'.allMatches(slotRegion).length, 3);
    expect('</FrameLayout>'.allMatches(slotRegion).length, 3);

    // Exactly one main-axis spacer is injected between the two column slots
    // (visibility wrapper + the "other" text) for spaceBetween.
    final spacerCount = spacer.allMatches(xml).length;
    expect(spacerCount, 1);
    expect(xml, contains('android:layout_weight="1"'));

    final kt = provider(r);
    // Both toggled ids are still referenced for setViewVisibility.
    expect(kt,
        contains('views.setViewVisibility(R.id.hw_visibility_show,'));
    expect(kt,
        contains('views.setViewVisibility(R.id.hw_visibility_show_alt,'));
  });
}
