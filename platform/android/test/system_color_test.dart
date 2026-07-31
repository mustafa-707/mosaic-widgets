import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// `MColor.system` draws from the user's wallpaper-derived Material You palette
/// on Android 12+, so a widget matches whatever they themed their phone to.
///
/// The framework colours (`@android:color/system_accent1_600`, …) do not exist
/// below API 31 — referencing one unconditionally fails resource linking on
/// older devices. They are therefore emitted as a `-v31` override over a literal
/// fallback, which is what makes the fallback real rather than aspirational.
void main() {
  String colors(r, String dir) =>
      r.file('android/app/src/main/res/$dir/mosaic_colors.xml');
  String? colorsOrNull(r, String dir) =>
      r.fileOrNull('android/app/src/main/res/$dir/mosaic_colors.xml');

  Map<String, dynamic> sysText(String name) => {
        '__type': 'HWText',
        'text': 'x',
        'style': {
          'color': {
            'hex': '#6750A4',
            'dark': '#D0BCFF',
            'opacity': 1.0,
            'system': name,
          },
        },
      };

  test('the base files hold the fallback, so pre-31 links cleanly', () async {
    final r = await runAndroid([irDef(sysText('accent'))]);
    expect(colors(r, 'values'), contains('#6750A4'));
    expect(colors(r, 'values-night'), contains('#D0BCFF'));
    // No framework reference in the unqualified files — that is the whole point.
    expect(colors(r, 'values'), isNot(contains('@android:color/')));
    expect(colors(r, 'values-night'), isNot(contains('@android:color/')));
  });

  test('the v31 files point at the live palette', () async {
    final r = await runAndroid([irDef(sysText('accent'))]);
    expect(colors(r, 'values-v31'),
        contains('@android:color/system_accent1_600'));
    expect(colors(r, 'values-night-v31'),
        contains('@android:color/system_accent1_200'));
  });

  test('the same resource name is used across all four files', () async {
    // A mismatch would silently leave the override unapplied.
    final r = await runAndroid([irDef(sysText('surface'))]);
    final name = RegExp(r'<color name="(mosaic_sys_\d+)">')
        .firstMatch(colors(r, 'values'))
        ?.group(1);
    expect(name, isNotNull);
    for (final dir in ['values-night', 'values-v31', 'values-night-v31']) {
      expect(colors(r, dir), contains('name="$name"'));
    }
  });

  test('a project using no system colour gets no v31 files at all', () async {
    // Emitting empty override files would add resource dirs for nothing.
    final r = await runAndroid([irDef(text('plain'))]);
    expect(colorsOrNull(r, 'values-v31'), isNull);
    expect(colorsOrNull(r, 'values-night-v31'), isNull);
  });

  test('ordinary adaptive colours still work alongside', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [
          sysText('accent'),
          {
            '__type': 'HWText',
            'text': 'y',
            'style': {
              'color': {'hex': '#FF0000', 'dark': '#00FF00', 'opacity': 1.0},
            },
          },
        ],
      })
    ]);
    expect(colors(r, 'values'), contains('#FF0000'));
    expect(colors(r, 'values'), contains('#6750A4'));
    // The plain colour must not leak into the v31 override.
    expect(colors(r, 'values-v31'), isNot(contains('#FF0000')));
  });

  test('an unrecognised name falls back instead of failing the build', () async {
    // A DSL newer than the generator should degrade, not break.
    final r = await runAndroid([irDef(sysText('someFutureRole'))]);
    expect(colors(r, 'values'), contains('#6750A4'));
    expect(colorsOrNull(r, 'values-v31'), isNull);
  });
}
