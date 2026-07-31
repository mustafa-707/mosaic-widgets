import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// `MShadow` used to emit `<!-- shadow not supported -->` and nothing else on
/// Android, while `docs/DSL_REFERENCE.md` told developers it rendered "a
/// layered outline". The docs described something that was never built.
///
/// RemoteViews genuinely cannot blur, and `elevation` needs a view hierarchy
/// the launcher does not provide. A `layer-list` *can* put an offset silhouette
/// behind the shape, which is what the docs promised — so that is what it does
/// now, with `blur` accepted and ignored.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');
  String drawable(r, String ref) => r.file(
      'android/app/src/main/res/drawable/${ref.replaceFirst('@drawable/', '')}.xml');

  String bgRef(String xml) =>
      RegExp(r'android:background="(@drawable/hw_shadowed_\d+)"')
          .firstMatch(xml)!
          .group(1)!;

  Map<String, dynamic> shadowed({
    double dx = 0,
    double dy = 2,
    double blur = 8,
    Map<String, dynamic>? color,
    double radius = 12,
  }) =>
      {
        '__type': 'HWContainer',
        'radius': radius,
        'background': {'hex': '#FFFFFF', 'opacity': 1.0},
        'shadow': {
          'color': color,
          'blur': blur,
          'dx': dx,
          'dy': dy,
        },
        'child': text('x'),
      };

  test('a shadow produces a layer-list, not a comment', () async {
    final r = await runAndroid([irDef(shadowed())]);
    final xml = layout(r);
    expect(xml, isNot(contains('shadow not supported')));
    final layer = drawable(r, bgRef(xml));
    expect(layer, contains('<layer-list'));
    // Silhouette first, so it sits behind.
    expect(layer.indexOf('hw_shadow_'), lessThan(layer.indexOf('hw_bg_')));
  });

  test('a downward shadow insets the silhouette from the top', () async {
    final layer = await runAndroid([irDef(shadowed(dy: 4))])
        .then((r) => drawable(r, bgRef(layout(r))));
    expect(layer, contains('android:top="4.0dp"'));
    // ...and the foreground from the opposite side, so both layers match size.
    expect(layer, contains('android:bottom="4.0dp"'));
  });

  test('a negative offset is expressed without a negative inset', () async {
    // Layer-list insets cannot be negative; shifting up means insetting the
    // foreground from the top instead.
    final layer = await runAndroid([irDef(shadowed(dx: -3, dy: -3))])
        .then((r) => drawable(r, bgRef(layout(r))));
    expect(layer, isNot(contains(RegExp(r'="-'))),
        reason: 'no negative dimension values');
    expect(layer, contains('android:right="3.0dp"'));
  });

  test('the silhouette takes the container\'s corner radius', () async {
    final r = await runAndroid([irDef(shadowed(radius: 20))]);
    final layer = drawable(r, bgRef(layout(r)));
    final ref = RegExp(r'"(@drawable/hw_shadow_\d+)"').firstMatch(layer)!.group(1)!;
    expect(drawable(r, ref), contains('20.0dp'));
  });

  test('blur-only differences share one drawable', () async {
    // Android cannot blur, so two shadows differing only in blur are the same
    // picture here and should dedupe. They still differ on iOS, where the
    // Swift carries the blur radius into `.shadow`.
    final a = await runAndroid([irDef(shadowed(blur: 4))]);
    final b = await runAndroid([irDef(shadowed(blur: 24))]);
    expect(bgRef(layout(a)), equals(bgRef(layout(b))));
  });

  test('a container with no shadow is untouched', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWContainer',
        'radius': 12.0,
        'background': {'hex': '#FFFFFF', 'opacity': 1.0},
        'child': text('x'),
      })
    ]);
    expect(layout(r), isNot(contains('hw_shadowed_')));
  });
}
