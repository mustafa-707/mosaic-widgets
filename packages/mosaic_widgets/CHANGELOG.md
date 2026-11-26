# Changelog

## 0.5.2 - 2026-11-26
### Fixed
- iOS: a widget with network images could stay on its placeholder for good. The
  cache stored each picture as downloaded, and a widget extension is killed at
  about 30MB, so one decoded 12-megapixel photo took the whole widget down; the
  downloads were also sequential on a 60-second timeout, so a slow one kept the
  timeline from ever completing. Pictures are now decoded straight to a 640px
  thumbnail (PNG when they have transparency, JPEG otherwise), fetched together
  on a session with 6s/9s timeouts, and files older than 14 days are pruned.
  Cache files moved to `.t640`; the old full-size `.img` files are deleted.
- iOS: when a picture is still missing at the end of a pass, the timeline asks for
  another pass in a minute instead of waiting out `updateInterval` (or never
  refreshing, with no interval).

## 0.5.1 - 2026-11-26
### Fixed
- iOS: a network image was never found again after the widget process restarted.
  The cache file name came from `String.hashValue`, which Swift seeds per launch,
  so the image downloaded by one run was looked up under another name by the next
  and the widget showed its placeholder forever. The name now comes from FNV-1a,
  which is the same in every process.
- iOS: the keys a widget loads, refreshes and downloads images for came from the
  default tree only. Anything bound solely in `compactRoot` or `largeRoot`
  rendered blank (the large widget's third and fourth offers, for example), and
  its images were never prefetched. All trees are now read, and the same URL
  bound by several trees is fetched once.

## 0.5.0 - 2026-11-26
### Added
- `MFont` and `MTextStyle(font:)`: bundled custom fonts in widgets, named once per
  platform (`MFont(android: 'zain_bold', ios: 'Zain-Bold')`).
  - `mosaic build` copies `assets/widgets/fonts/*.ttf|otf` to
    `android/app/src/main/res/font/` (resource names lowercased) and to
    `ios/HomeWidgetExtension/Fonts/`.
  - Android writes `android:fontFamily="@font/<name>"` on `MText` and `MTimer`
    (API 26+; older devices use the default font). iOS writes
    `.font(.custom("<PostScriptName>", size: N))`; a glyph the font lacks falls back
    to the system font.
  - A font is one weight, so `weight:` and `bold:` are ignored on a style that sets
    `font:`. Names are validated before they reach the generated XML or Swift.
  - iOS still needs a one-time Xcode step: add the font files to the widget
    extension target and list them under `UIAppFonts`.

### Fixed
- iOS: a container that is the direct child of an `MFlexible` now fills its slot.
  Before, only the outermost container filled; a nested card kept its content size
  and sat centred in a large empty frame (Android, whose weighted wrapper gives the
  container the whole slot, was already right).
- iOS: an `MNetworkImage` with `fit: cover` can no longer grow past the box it is
  given. An aspect-fill image reports the size of its scaled picture, so inside a
  flexible slot it pushed its siblings out of the widget; it is now an overlay on a
  clear box and clipped.


## 0.4.0 - 2026-11-25
### Added
- `MosaicDefinition(largeRoot:)`: a third layout for the largest sizes, so one
  widget can carry a small, a medium and a large tree instead of one stretched
  layout. `compactRoot` stays the small tree and `root` the default (medium)
  one; `largeRoot` is optional and, when null, the large sizes render `root`.
  - iOS: `systemLarge` and `systemExtraLarge` take `largeRoot`, picked from
    `@Environment(\.widgetFamily)` through the new `mosaicPrefersLarge` helper.
  - Android (API 31+): the launcher's size map gets a `largeRoot` entry two rows
    (140dp) above the declared height, written to `hw_<name>_large.xml`. Below
    API 31 `root` is used at every size, as with `compactRoot`.
  - `mosaic build` keeps `hw_<name>_large.xml` as part of its widget rather than
    pruning it as an orphan.

## 0.3.3 - 2026-11-24
### Fixed
- Security: the generated widget `<receiver>` entries are now
  `android:exported="false"`. Their `onReceive` handles `MOSAIC_TOGGLE`,
  `MOSAIC_CALLBACK` and refresh actions with no sender check, so while exported
  any app could flip stored values or trigger callbacks. The system still
  delivers `APPWIDGET_UPDATE`, and widget buttons are the app's own immutable
  `PendingIntent`s, so widgets behave as before. The configuration activity and
  Quick Settings tiles stay exported because the platform must reach them.
  `mosaic build` rewrites the manifest entries, so re-running it applies this.
- Security: the in-app `MOSAIC_CALLBACK` receiver registered by `MosaicPlugin`
  was reachable by other apps below API 33. Broadcasts must now carry a
  per-install token held in app-private storage (the Quick Settings tile adds
  it); anything else is dropped. No new Gradle dependency or manifest entry.
- Android: the repeating alarm armed when the first widget is added is now
  cancelled in `onDisabled` when the last one is removed, instead of waking the
  app forever. `updatePeriodMillis` is unaffected.
- iOS: `systemSmall` supports one `widgetURL` only (`Link` views inside the tree
  do nothing there) and the generated view resolved it from an unset
  `global_url` key, i.e. to nil. See `MosaicDefinition(widgetUrl:)` below.

### Added
- `MosaicDefinition(widgetUrl:)` — a `String` or an `MBind`: the URL a tap opens
  anywhere that has no button of its own. iOS emits it as `.widgetURL(...)`
  (the only tap target on `systemSmall`); Android attaches it to the root view,
  so buttons keep their own action. Optional: definitions without it generate
  the same output as before. A literal is validated against `deep_link_scheme`
  like `MLaunchUrlAction`.
- `MTimer.bound(MBind('key'))` — a timer whose target is epoch milliseconds the
  app pushes at runtime (an offer's own end time). Android computes the
  `setChronometer` base on every provider update; iOS reads the timeline entry.
  A missing key, or a count-down already past at the last update, shows zero;
  on iOS 16+ a countdown also stops at `0:00` by itself. Limitation: the
  Android base is set only when the provider updates, so a countdown expiring
  between updates ticks into negative time until the next one. Push a new
  target and `refreshAll()` (or use `updateInterval`) to refresh it.
- Upgrade note: the in-app `MOSAIC_CALLBACK` receiver now requires the
  `MosaicCallbackAuth.EXTRA` token. Only the generated Quick Settings tile sends
  that broadcast and it adds the token; hand-written senders must do the same.

## 0.3.2 - 2026-11-24
### Fixed
- The generated Android `MosaicPlugin.register(...)` and its callback-receiver
  registration now take `android.app.Activity` instead of `FlutterActivity`.
  Apps whose `MainActivity` extends `FlutterFragmentActivity` (required by
  `local_auth` for biometrics) can now call `mosaic.register(this, flutterEngine)`.
  Only `applicationContext` and the launch `intent` were ever used, so behaviour
  is unchanged and existing `FlutterActivity` hosts compile as before.
  Re-run `dart run mosaic_widgets:mosaic build` to regenerate.

## 0.3.1 - 2026-11-18
### Added
- UIScene lifecycle support. The generated `MosaicPlugin` now also registers a
  scene delegate, so deep links (including the tap that cold-launches the app)
  and the pending widget-callback drain keep working in apps on the scene
  lifecycle, which Flutter 3.50 makes the default. Hosts that have not migrated
  keep working unchanged. `docs/IOS_SETUP.md` shows the scene-based
  `AppDelegate`.

### Changed
- Verified against Flutter 3.50.0 / Dart 3.14: library tests and analysis pass,
  and the generated code builds in the demo app for iOS and Android (Gradle
  9.5, AGP 9.3, Kotlin 2.4). The package SDK constraint is unchanged.

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
