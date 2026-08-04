# Changelog

## 0.3.0 - 2026-08-04
### Added
- `MRaw(swift:, androidXml:, binds:)` — verbatim native code. Your SwiftUI or
  layout XML is inserted unchanged while Mosaic still generates the App Group
  wiring, timeline and update path. Removes the DSL's ceiling: what the
  vocabulary cannot express, you can now hand-write. Declare the bind keys —
  the generator cannot parse a snippet, so an undeclared key is never fetched.
- `MAdaptive(ios:, android:)` — a different subtree per platform, chosen at
  generation time. For the cases the DSL already documents as divergent:
  `MFlipper` renders one child on iOS, `MActivityIndicator` animates only on
  Android, `MFlexible` ratios hold only on Android.
- `MBind(defaultValue:)` — what renders before the app first writes. Seeds the
  iOS `placeholder(in:)`, which the OS shows in the widget gallery *before your
  app has ever run*; it previously shipped an empty dictionary, so every bound
  value previewed as `--`.
- `MTextRole` — semantic type scale (title … captionSmall). `.headline` on iOS,
  a matching sp on Android; the roles line up, the sizes deliberately do not.
- `MTextStyle`: `weight` (`MFontWeight.w100`–`w900`), `italic`, `copyWith`, and
  `baseStyle`. iOS honours all nine weights; Android collapses w200/w600/w800
  because `textFontWeight` is API 28 against a floor of 21.
- `MosaicBridge.initialDeepLink()` — the tap that launched the app.

### Fixed
- A widget tap that cold-launched the app could be lost entirely. `onDeepLink`
  is a broadcast stream and the native side delivers during registration, so
  the link arrived before anything could subscribe and the app opened on its
  default screen.
- `MosaicTv.publish` reported success on devices with no TV provider — a phone
  claimed to have published a row that was never written.

## 0.2.0 - 2026-08-02
### Added
- `MosaicBridge.getValue<T>` — read the shared store back. The widget writes to
  it too (an `MToggleAction` flips its bool on-device), and none of that was
  visible to the app before.
- `MosaicBridge.saveFile` / `saveImage` — put a file where `MFileImage` can find
  it. The node was documented but unusable without this.
- `MosaicBridge.renderFlutterWidget` — rasterise any Flutter widget to a PNG,
  the escape hatch for what the DSL cannot express.
- `MosaicBridge.installedWidgets()` — which widgets the user actually placed.
- `MosaicTv` + `tv_channels:` — Android TV / Google TV home-screen channels.
  Not widgets: the TV launchers host no AppWidgets at all.
- macOS and watchOS: the generated Swift now compiles for both, including
  watch complications and the watchOS-only `accessoryCorner` family.

### Fixed
- `MPositioned` ignored its offsets on iOS, so every decorative element sat
  flush to its corner.
- `MListView` was always empty on iOS: `saveList` JSON-encodes, and the
  generator cast straight to an array.
- Battery never resolved on iOS — `isBatteryMonitoringEnabled` is a no-op in an
  app extension, so the app publishes it instead.
## 0.1.0 - 2026-08-01
### Added
- Initial release. Flutter-style Dart DSL for building native iOS and Android home-screen widgets, lock-screen widgets, and Live Activities from a single codebase.
