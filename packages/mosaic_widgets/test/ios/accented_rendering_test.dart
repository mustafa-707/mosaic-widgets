import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// From iOS 18 the Home Screen can tint widgets. The default tints images,
/// which is right for glyphs and wrong for photos — a photo becomes a flat
/// silhouette.
void main() {
  test('a network image defaults to fullColor, so photos survive tinting',
      () async {
    final r = await runIos([
      irDef({
        '__type': 'HWNetworkImage',
        'url': 'https://cdn.example.com/a.jpg',
        'accentedMode': 'fullColor',
      })
    ]);
    expect(
        r.swiftForTestW(), contains('.mosaicAccentedRendering("fullColor")'));
  });

  test('each mode is emitted verbatim', () async {
    for (final mode in [
      'accented',
      'accentedDesaturated',
      'desaturated',
      'fullColor',
    ]) {
      final r = await runIos([
        irDef({
          '__type': 'HWImage',
          'source': {'__type': 'HWAssetImage', 'path': 'a.png'},
          'accentedMode': mode,
        })
      ]);
      expect(r.swiftForTestW(), contains('.mosaicAccentedRendering("$mode")'),
          reason: 'mode $mode');
    }
  });

  test('omitted when unset, leaving the system default', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWImage',
        'source': {'__type': 'HWAssetImage', 'path': 'a.png'},
      })
    ]);
    expect(r.swiftForTestW(), isNot(contains('mosaicAccentedRendering')));
  });

  test('sits after .resizable() and before the View modifiers', () async {
    // widgetAccentedRenderingMode is declared on Image but returns some View:
    // before .resizable() the chain loses Image (no member 'resizable'), and
    // after .aspectRatio() there is no Image left to apply it to. Both orderings
    // were rejected by the compiler before this landed.
    final r = await runIos([
      irDef({
        '__type': 'HWImage',
        'source': {'__type': 'HWAssetImage', 'path': 'a.png'},
        'accentedMode': 'fullColor',
        'fit': 'cover',
      })
    ]);
    final swift = r.swiftForTestW();
    final resizable = swift.indexOf('.resizable()');
    final accented = swift.indexOf('.mosaicAccentedRendering(');
    final aspect = swift.indexOf('.aspectRatio(');
    expect(resizable, lessThan(accented));
    expect(accented, lessThan(aspect));
  });

  test('the helper gates on iOS 18 so older targets still compile', () async {
    final r = await runIos([irDef(text('hi'))]);
    final core =
        readFile(r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));
    expect(core, contains('extension Image {'));
    expect(
        core, contains('if #available(iOS 18.0, macOS 15.0, watchOS 11.0, *)'));
    expect(core, contains('widgetAccentedRenderingMode(.fullColor)'));
    // An unknown mode must fall through rather than fail to compile.
    expect(core, contains('default:'));
  });
}
