import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// A rounded `android:background` paints *behind* children; it does not clip
/// them. So a child with square edges — an image, a coloured row, a decorative
/// shape bled into a corner — juts past the curve, while the same tree on iOS
/// is clipped by `.clipShape`.
///
/// `setClipToOutline` makes a view clip to its background's outline, which a
/// rounded shape supplies. RemoteViews cannot set it as a layout attribute but
/// can invoke the setter, which is what the clip registry emits.
///
/// Note this is invisible for a *root* container on Android 12+, where the
/// launcher already masks the whole widget to a rounded rect. It matters for
/// nested rounded containers.
void main() {
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  Map<String, dynamic> box({
    double radius = 16,
    Map<String, dynamic>? shadow,
  }) =>
      {
        '__type': 'HWContainer',
        'radius': radius,
        'background': {'hex': '#FFFFFF', 'opacity': 1.0},
        if (shadow != null) 'shadow': shadow,
        'child': text('inside'),
      };

  test('a rounded container clips its children', () async {
    final r = await runAndroid([irDef(box())]);
    expect(provider(r), contains('"setClipToOutline", true'));
    // The setter needs an id to target.
    expect(layout(r), contains('@+id/hw_clip_'));
  });

  test('a square container is left alone', () async {
    // With no radius there is nothing to clip to, and clipping would only cost
    // a draw pass.
    final r = await runAndroid([irDef(box(radius: 0))]);
    expect(provider(r), isNot(contains('setClipToOutline')));
  });

  test('a shadowed container is not clipped', () async {
    // The silhouette is drawn outside the shape; clipping to the outline would
    // erase precisely the part that reads as a shadow.
    final r = await runAndroid([
      irDef(box(shadow: {'blur': 8.0, 'dx': 0.0, 'dy': 2.0}))
    ]);
    expect(provider(r), isNot(contains('setClipToOutline')));
  });

  test('a bound background colour keeps its corner radius', () async {
    // Was a KNOWN GAP: the provider applied the resolved colour with
    // setBackgroundColor, which installs a flat ColorDrawable and discards the
    // rounded shape — so this rendered rounded on iOS and square on Android.
    //
    // Now the layout carries a real shape and the provider only *tints* it.
    final r = await runAndroid([
      irDef({
        '__type': 'HWContainer',
        'radius': 16.0,
        'background': {'bind': 'card_color', 'opacity': 1.0},
        'child': text('inside'),
      })
    ]);
    final kt = provider(r);
    expect(kt, contains('setBackgroundTintList'));
    // The shape has to exist in the layout for a tint to have anything to act
    // on; a bare colour attribute would leave nothing to round.
    expect(layout(r), contains('@drawable/hw_bgtint_'));
    // ...and it still clips its children, which a flat fill could not do.
    expect(kt, contains('"setClipToOutline", true'));
  });

  test('below API 31 it falls back to the flat fill', () async {
    // setColorStateList is API 31+. RemoteViews offers nothing else that can
    // recolour a shape, so older devices lose the corners rather than the
    // colour — stated in the generated code rather than left to be discovered.
    final r = await runAndroid([
      irDef({
        '__type': 'HWContainer',
        'radius': 16.0,
        'background': {'bind': 'card_color', 'opacity': 1.0},
        'child': text('inside'),
      })
    ]);
    final kt = provider(r);
    expect(kt, contains('SDK_INT >= 31'));
    expect(kt, contains('setBackgroundColor'));
  });

  test('a square bound background keeps the cheaper flat fill', () async {
    // No radius means no shape to preserve, so there is nothing to gain from
    // allocating a drawable and a tint.
    final r = await runAndroid([
      irDef({
        '__type': 'HWContainer',
        'radius': 0.0,
        'background': {'bind': 'card_color', 'opacity': 1.0},
        'child': text('inside'),
      })
    ]);
    expect(provider(r), isNot(contains('setBackgroundTintList')));
    expect(layout(r), isNot(contains('hw_bgtint_')));
  });
}
