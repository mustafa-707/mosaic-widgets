---
name: mosaic-widgets
description: Use when building or editing native iOS/Android home-screen widgets, lock-screen (accessory) widgets, Live Activities, or Dynamic Island with the Mosaic Flutter framework — e.g. a project containing a mosaic.yaml, files importing package:mosaic_widgets, or *.widget.dart / *.live.dart definition files.
---

# Mosaic Widgets

## Overview
Mosaic generates **native** iOS (WidgetKit / Live Activities / Dynamic Island) and Android
(AppWidget / RemoteViews) code from a single Dart DSL. You write declarative `MosaicDefinition`
(widget) and `MosaicLiveActivity` (Live Activity) builder functions; the `mosaic_cli build`
command runs them and emits native Swift/Kotlin/XML. The app pushes live data through
`MosaicBridge`; the OS renders the widget. Mosaic is NOT in model training data — use the real
API below, do not invent classes or imports.

## The one rule that trips everyone up
- **Widget/Live-Activity definition files import `package:mosaic_widgets/dsl.dart`** (pure Dart — the build
  runner executes them under `dart run`, which cannot compile Flutter).
- **App code** (using `MosaicBridge` / `MosaicLiveActivities`) imports `package:mosaic_widgets/mosaic_widgets.dart`.
Putting `package:mosaic_widgets/mosaic_widgets.dart` in a definition file breaks `mosaic_cli build`.

## Starting from nothing

```bash
dart run mosaic_cli init                    # mosaic.yaml, identifiers detected
dart run mosaic_cli add widget News         # creates the file and registers it
dart run mosaic_cli add live-activity Order # lock screen + Dynamic Island
dart run mosaic_cli add control Torch       # Control Center / Quick Settings
dart run mosaic_cli build                   # generates native code
dart run mosaic_cli doctor --fix            # repairs setup, reports the rest
dart run mosaic_cli list                    # what is declared, and its status
```

`init` reads `applicationId` from `android/app/build.gradle*` and the Runner
target's `PRODUCT_BUNDLE_IDENTIFIER` from `project.pbxproj`, so the App Group it
derives is right the first time. `doctor` exits non-zero on fatal problems. It cross-checks
`android_package` against your real `applicationId`, requires the `group.`
prefix on `ios_app_group`, verifies an Xcode app-extension target actually
compiles the generated Swift, and checks **both** hosts register `MosaicPlugin` — an unwired `MainActivity`
makes every `MosaicBridge` call throw `MissingPluginException`.

## Workflow
1. `dart run mosaic_cli init` → creates `mosaic.yaml` + `lib/home_widgets/`.
2. `dart run mosaic_cli add widget MyWidget` → scaffolds `lib/home_widgets/mywidget.widget.dart`.
3. Define the widget: a top-level `MosaicDefinition build<Name>()` (convention: `build` + the
   config `name`). Live activities: a `MosaicLiveActivity build<Name>()` in a `*.live.dart` file.
4. Register it in `mosaic.yaml` (see Config). The `entry:` path is arbitrary — relative to the
   project root; any directory works (the scaffold default is `lib/home_widgets/`, but e.g.
   `lib/platform/widgets/` is fine). The config `name:` must match the `build<Name>()` suffix
   **exactly, case-sensitive** (`name: NewsWidget` ⇒ `MosaicDefinition buildNewsWidget()`).
5. `dart run mosaic_cli build` → generates native code (idempotent; `clean` removes it).
6. iOS: add the generated files to your Widget Extension target in Xcode (one-time). Wire
   `AppDelegate.swift` / `MainActivity.kt` from the generated templates (see docs/IOS_SETUP.md,
   docs/ANDROID_SETUP.md). `doctor` checks setup.

## Minimal widget
```dart
import 'package:mosaic_widgets/dsl.dart';

MosaicDefinition buildNews() => MosaicDefinition(
  name: 'News',                 // must match the mosaic.yaml entry name
  width: 4, height: 1,
  root: MContainer(
    background: const MColor.hex('#111827', dark: '#000000'),
    radius: 16,
    child: MPadding(const MInsets.all(12), MColumn(
      crossAxisAlignment: MCrossAxisAlignment.start,
      [
        const MText('Headlines', style: MTextStyle(color: MColor.hex('#FFFFFF'), bold: true)),
        MText(MBind('headline'), maxLines: 2),   // live value pushed by the app
      ],
    )),
  ),
);
```

## Quick reference

**Definition:** `MosaicDefinition({required name, required root, MNode? compactRoot, Duration? updateInterval, int width=2, int height=2, String? previewImage, MResizeMode resizeMode, List<MParam> params})`.

`compactRoot` is a second tree for the smallest sizes, so a `systemSmall` tile is not the `systemLarge` layout squeezed down. iOS picks it via `@Environment(\.widgetFamily)` (`systemSmall`, `accessoryCircular`, `accessoryInline`); Android via `RemoteViews(Map<SizeF, RemoteViews>)` on API 31+, keyed on the widget's own declared minimum, falling back to `root` below 31.

**Layout nodes:** `MContainer({required child, MColor? background, MLinearGradient? gradient, double radius, MBorder? border, double? width, double? height, MInsets? margin, MShadow? shadow, MRadius? corners})`, `MColumn(children, {mainAxisAlignment, crossAxisAlignment})`, `MRow(...)`, `MPadding(insets, child)`, `MStack(children)`, `MPositioned({required child, top,left,right,bottom})`, `MCenter({required child})`, `MSpacer()`, `MDivider({thickness, color, vertical, indent})`.

**Content nodes:** `MText(textOrBind, {MTextStyle style, MFormat? format, int? maxLines, MTextAlign? align})`, `MImage(source, {MBoxFit fit})`, `MIcon({sfSymbol, androidDrawable, size, MColor? color})`, `MProgressBar({required value, double max, MColor color})`, `MGauge({required value, max, trackColor, fillColor, lineWidth})`, `MBadge({required child, required count, MColor? color})`, `MTimer({required target, bool countUp, MTextStyle style})`, `MButton({required child, required MAction action})`, `MVisibility({required bind, required child, MNode? replacement})`, `MListView({required bind, required itemTemplate})`.

**Bindings:** `MBind('key')` anywhere a value is accepted (text, image path, progress value, visibility, timer target, gauge value, color). The app supplies values via `MosaicBridge`. `MText` `format:` (`MFormat.currency/decimal/percent/signedPercent/date/relativeTime`) formats a bound value in the device locale; `date`/`relativeTime` expect **epoch milliseconds**. `percent` treats the value as a *fraction* (`0.15` → 15%); use `signedPercent` for a change already in percent units (`1.33` → `+1.33%`), which is what most APIs return — `percent` would render it 100x too large. Pass `currencyCode: 'USD'` with `MFormat.currency` when the amount is in a known currency: without it the value is formatted in the *device's* currency, relabelling the number without converting it.

**Colors/theme:** `MColor.hex('#RRGGBB', {String? dark, double opacity})` (OS light/dark), `MColor.bind('key')` (runtime), or `MColor.system(MSystemColor.accent, fallback: '#2563EB', fallbackDark: …)` — the user's Material You palette on Android 12+, the fallback everywhere else including all of iOS. Roles: `accent`, `accentMuted`, `surface`, `onSurface`, `onSurfaceMuted`. A bound colour on a container with a `radius` keeps its corners (the shape is tinted, not replaced; API 31+). **Style:** `MTextStyle({double? size, MColor? color, double? opacity, bool? bold})`. **Insets:** `MInsets.all(v)` / `.symmetric(vertical:, horizontal:)` / `.only(...)`. **Gradient:** `MLinearGradient({required List<MColor> colors, List<double>? stops, double angle})`. **Shape:** `MBorder({required color, width})`, `MRadius({topLeft,topRight,bottomLeft,bottomRight})`/`MRadius.all(v)`, `MShadow({color, blur, dx, dy})` — iOS `.shadow` honours `blur`; Android draws a `layer-list` offset silhouette matching the corner radius and ignores `blur`, since RemoteViews has no blur primitive. A container with no background casts nothing, as on iOS. Enums: `MBoxFit`, `MMainAxisAlignment`, `MCrossAxisAlignment`, `MTextAlign`, `MResizeMode`.

**Actions (for MButton):** `MLaunchUrlAction('myapp://path')`, `MActionCallback('name')` (→ Dart `registerBackgroundCallback`, or a native fetch if listed under `refresh:`), `MRefreshAction()`, `MToggleAction('key')`. iOS buttons are real (AppIntent) on iOS 17+, deep-link on 14–16.

`MToggleAction('key')` flips a shared-storage bool on-device — no app launch, no network — so it suits in-widget state. Pair with `MVisibility(bind: MBind('key'), child: ..., replacement: ...)` to swap subtrees, e.g. a °C/°F switch:
```dart
MVisibility(
  bind: MBind('unit_f'),
  child: MText(MBind('temp_f')),
  replacement: MText(MBind('temp_c')),
),
MButton(action: const MToggleAction('unit_f'), child: const MText('°C / °F')),
```

**Image sources:** `MAssetImage('icon.png')`, `MFileImage(pathOrBind)`.

**Network images:** `MNetworkImage(urlOrBind, {fit, MColor? placeholder, double? radius, bool circle})` — the widget process downloads and caches to disk itself (no app launch), so a URL delivered by a `refresh:` source works with the app closed. `MImage` takes `radius`/`circle` too; `circle: true` is how you get an avatar.

**Tinted mode (iOS 18+):** from iOS 18 users can tint widgets, and the default tints images — right for glyphs, wrong for photos. `MImage`/`MNetworkImage` take `accentedMode:` (`MAccentedRendering.accented | accentedDesaturated | desaturated | fullColor`). `MNetworkImage` already defaults to `fullColor`; set it explicitly on any photo you draw via `MImage`. Ignored on Android.

**Device metrics:** `MDeviceValue(MDeviceMetric.x)` — `batteryLevel`, `batteryCharging`, `storageFreeGb`, `storageUsedPercent`, `memoryFreeMb`, `memoryTotalMb`, `memoryUsedPercent`. Read *in the widget process*, so they stay correct when the app has not run for days — **except battery on iOS**, where `isBatteryMonitoringEnabled` is a no-op inside an app extension and `batteryLevel` is always `-1` (on devices as well as the simulator). Mosaic publishes it from the app instead, so on iOS it appears once the app has run, and never resolves in the simulator at all. It is an `MBind`, so it works anywhere a bound value does:
```dart
MText(MDeviceValue(MDeviceMetric.batteryLevel))
MProgressBar(value: MDeviceValue(MDeviceMetric.batteryLevel), max: 100)
MVisibility(bind: MDeviceValue(MDeviceMetric.batteryCharging), child: boltIcon)
```
`MDeviceMetric { batteryLevel, batteryCharging, storageFreeGb, storageUsedPercent }`. Only referenced metrics are collected.

**Accessibility:** `MSemantics(label: labelOrBind, child: …, bool excludeChildren)` → iOS `.accessibilityLabel`, Android `contentDescription`. Without it a screen reader reads bare numbers with no unit or context. `excludeChildren` collapses the subtree to one element on **both** platforms (iOS `.accessibilityElement(children: .ignore)`, Android `importantForAccessibility="noHideDescendants"` — a static layout attribute, so nothing crosses the RemoteViews boundary).

**Motion — read the limits before reaching for these.** Widgets render static snapshots; there is no general animation on either platform and **Lottie is impossible** (it needs a live animation view, which neither WidgetKit nor RemoteViews provides).

| Node | Behaviour |
|---|---|
| `MActivityIndicator({color, size})` | Spins on **Android only** (indeterminate `ProgressBar`). Static on iOS. Pair with `MVisibility(bind: MBind('mosaic_refreshing'), …)` — Mosaic sets that key around a refresh. |
| `MFlipper(children, {interval})` | Cycles on **Android only** (`ViewFlipper` self-advances). iOS renders the **first child only**. |
| `MText(contentTransition: MContentTransition.numericText)` | Digits roll on **iOS 17+ only**. Ignored on Android. |
| `MTimer(target:)` | Live-ticking on both. |

**Named-arg examples:** `MIcon(sfSymbol: 'cloud.sun.fill', androidDrawable: 'ic_weather', size: 32, color: MColor.hex('#FFD700'))`; `MProgressBar(value: MBind('p'), max: 100, color: MColor.hex('#34D399'))`; `MGauge(value: MBind('pct'), fillColor: MColor.hex('#FF0000'))`.

**`MSparkline(bind: MBind('series'), …)`** charts a numeric list pushed with `saveList`. Values are normalised, so only the shape matters. iOS draws a SwiftUI `Path`; Android rasterises to a bitmap because RemoteViews cannot draw vectors — so `color` must be a literal, not a bind.

**`MBarChart(bind: …)`** charts the same kind of list as `MSparkline`, but scaled **from zero** — a bar's length is its magnitude.

**`MFlexible(flex: n, child: …)`** shares a row/column's free space. Android honours the ratio exactly; **iOS splits it equally regardless of `flex`** (SwiftUI has no proportional flex), so only `flex: 1` behaves the same on both.

**Gaps and alignment:** `MSizedBox.height(8)` is an exact gap (`MSpacer` instead absorbs leftover room); `MSizedBox(width:, height:, child:)` constrains a child. `MAlign(alignment: MAlignment.bottomEnd, child: …)` places a child in the parent's box — start/end based, so it mirrors in RTL.

**`MContainer(padding:)`** puts space inside the background/border (Flutter's `Container(padding:)`); `margin:` puts it outside. Use it instead of nesting an `MPadding`.

**`const` tip:** nodes with only literal args can be `const` (e.g. `const MText('Hi')`), but anything containing `MBind(...)` cannot be `const` (it's a runtime binding) — drop `const` on the enclosing node then.

## Data binding (app side)
```dart
import 'package:mosaic_widgets/mosaic_widgets.dart';
await MosaicBridge.setAppGroupId('group.com.example.app.widgets'); // iOS
await MosaicBridge.saveString('headline', 'Markets rally');
await MosaicBridge.saveJson('item', {...});  // also saveList / saveBool
await MosaicBridge.refresh('News');          // or refreshAll()
MosaicBridge.onDeepLink.listen((url) { ... });
MosaicBridge.registerBackgroundCallback((name) async { ... });
// Widgets declaring `push: true` (iOS 26+). Only the extension is told these
// tokens and it cannot reach your server, so relay them on launch/resume.
final tokens = await MosaicBridge.widgetPushTokens();  // {'CryptoWidget': 'abc…'}
```

## Prompting the user to add a widget

Most users never open the launcher's widget picker, so offer it in-app:

```dart
if (await MosaicBridge.canRequestPinWidget()) {
  await MosaicBridge.requestPinWidget('News');   // name from mosaic.yaml
} else {
  // iOS, or a launcher without pinning: show manual instructions.
}
```

- **Android 8+ only**, and only on launchers reporting `isRequestPinAppWidgetSupported`. iOS has no equivalent API — Apple routes adding through the widget gallery — so both calls return false there.
- The return value means "the dialog was shown", **not** "the user accepted"; Android never reports the outcome. Detect real placement by the widget's first update.
- An unknown widget name throws rather than returning false, so a typo does not look like an unsupported launcher.

## Live Activities + Dynamic Island (iOS 16.1+)
```dart
// in a *.live.dart file, imports package:mosaic_widgets/dsl.dart
MosaicLiveActivity buildOrder() => MosaicLiveActivity(
  name: 'Order',
  lockScreen: MText(MBind('status')),
  dynamicIsland: MDynamicIsland(
    compactLeading: const MText('🛵'),
    compactTrailing: MText(MBind('eta')),
    minimal: const MText('🛵'),
    expanded: MExpanded(center: MText(MBind('status')), bottom: MProgressBar(value: MBind('progress'))),
  ),
);
```
Register under `live_activities:` in `mosaic.yaml`. Control from the app (import `package:mosaic_widgets/mosaic_widgets.dart`):
```dart
final id = await MosaicLiveActivities.start('Order', {'status':'On the way','eta':'12m','progress':'40'}, push: false);
await MosaicLiveActivities.update(id!, {'progress':'80'}, alert: const MActivityAlert(title:'Almost there', body:'2 min'));
await MosaicLiveActivities.end(id, policy: MEndPolicy.afterDefault);
MosaicLiveActivities.onPushToken.listen((t) { /* send t.token to your server for APNs push */ });
```

`watch: true` adds `supplementalActivityFamilies([.small, .medium])`, putting the activity on a paired Apple Watch's Smart Stack and in CarPlay using the lock-screen layout you already wrote. The modifier is **iOS 18+** while Live Activities start at 16.1, and a `WidgetConfiguration` cannot branch on availability inside its own body — so opting in raises **that activity's** minimum to iOS 18 and it is not registered below that. Nothing else in the project is affected.
iOS needs `NSSupportsLiveActivities=true` in Info.plist. Binds in a Live Activity resolve from its
content-state (the Map passed to start/update), not the widget data store. Android renders a
best-effort ongoing notification (no Dynamic Island; updates are local, no push token).

## Configurable widgets
Declare `params` on a `MosaicDefinition`; the chosen value is available via `MBind(param.key)`:
```dart
params: const [ MParam(key:'city', label:'City', type: MParamType.choice, defaultValue:'London', choices:['London','Paris']) ],
```
`MParamType { text, number, toggle, choice }`. iOS → AppIntentConfiguration (iOS 17+); Android → a config Activity.

## Config (mosaic.yaml)
```yaml
app:
  bundle_id: com.example.app
  android_package: com.example.app
  ios_app_group: group.com.example.app.widgets
  deep_link_scheme: mosaic        # optional (default 'mosaic') — MUST match every MLaunchUrlAction URL
widgets:
  - name: News                        # requires a top-level buildNews()
    entry: lib/home_widgets/news.widget.dart
    label: Top Headline               # optional — widget picker title (defaults to name)
    description: Latest headline.     # optional — picker subtitle
    push: false                       # optional — WidgetKit push updates, iOS 26+
    ios: { families: [systemMedium, accessoryRectangular] }   # optional; accessory* = lock screen, iOS 16+
    # `android:` is optional and inert — min_sdk/sizes are reserved and change
    # nothing. Grid footprint comes from MosaicDefinition(width:, height:).
live_activities:
  - name: Order
    entry: lib/live_activities/order.live.dart
    watch: true                     # optional — also show on Apple Watch / CarPlay
refresh:                          # optional — see below
  refresh_crypto:
    url: https://api.example.com/price
    headers: { Accept: application/json }
    map: { btc_price: bitcoin.usd }
strings:                          # optional — translated widget text, see below
  en: { trending_now: TRENDING NOW }
  ar: { trending_now: الأكثر تداولاً }
```

## Translated text (`MLocalized`)

A widget runs outside the Flutter engine, so `intl` / `AppLocalizations` are
**unreachable from widget code**. Declare text under `strings:` and use
`MText(const MLocalized('key'))`; Mosaic emits real platform resources
(`res/values-<locale>/mosaic_localized.xml`, `<locale>.lproj/Localizable.strings`)
that the OS picks by device language — even if the app never launched.

- First locale listed is the fallback. `build` **fails** if a key is missing from it, and warns for keys a secondary locale omits.
- On iOS the strings land in the **extension's** bundle; the app's are not visible to it.
- `MLocalized` is static text only. Runtime values stay `MBind` (+ `MFormat` for locale-correct numbers/dates).

## In-widget refresh (`refresh:`)
A widget's refresh button runs an AppIntent **inside the widget extension**, which
cannot run Dart. So by default it can only re-render already-stored data and hand
the request to the app, which fires `backgroundCallback` on next foreground —
i.e. the button appears to do nothing until you open the app.

Listing a source under `refresh:` makes the widget's **timeline provider** fetch
it and store each mapped value, so the button works with the app closed (the
provider — not the AppIntent — is where WidgetKit allows and waits for async
work). A provider fetches whichever sources supply the keys its widget binds, so
the widget also refreshes on system-scheduled reloads. **A key with no source
here does nothing visible until the app is next opened** — that is the usual
reason a refresh button "doesn't work".

A callback may declare one source or a list of them, so one button can fetch
several endpoints (one failing does not discard the others):
```yaml
refresh:
  refresh_weather:
    - url: https://api.open-meteo.com/v1/forecast?...&current=temperature_2m
      map: { temp_c: current.temperature_2m }
    - url: https://api.open-meteo.com/v1/forecast?...&temperature_unit=fahrenheit
      map: { temp_f: current.temperature_2m }
``` Paths are dot-separated with optional `[n]` indices and an
optional leading `$.` — `articles[0].title`, `$.current.temp_f`. Values are stored
as strings (numbers via `stringValue`, booleans as `1`/`0`); there is no
formatting step, so store pre-formatted values server-side if you need them.
Callbacks not listed keep the old defer-to-app behavior. **iOS only so far** —
on Android the button still defers to the app.

## CLI
`dart run mosaic_cli init | add widget <Name> | build | doctor | clean`.

## Renaming or removing a widget

The builder function name is derived from `name:` in `mosaic.yaml`, so the two
must agree — `name: News` requires a top-level `buildNews()`. Change both, or
`build` fails naming the function and file it expected.

`build` also deletes the generated provider, layout, info XML, and Swift view of
any widget no longer declared, printing each path it removes. Only files
carrying the `MOSAIC-GENERATED` sentinel are eligible, so hand-written files are
never touched.

## Diagnosing

`doctor` covers the failures that produce no error anywhere: an unset or
badly-prefixed App Group (widget renders blank), an unregistered `MosaicPlugin`
on either host (`MissingPluginException`), generated Swift with no Xcode target
(no `.appex` ships), `android_package` disagreeing with `applicationId` ("Can't
load widget"), and a widget renamed without renaming `build<Name>()`.

`doctor --fix` repairs the mechanical ones and leaves anything needing Xcode —
adding a target, adding a file to a target — as a reported problem with the
exact steps. It never edits `project.pbxproj`.

`list` answers "is this actually wired up?" per entry, and `build --help`
documents the rest.

## Common mistakes
| Mistake | Fix |
|---|---|
| Definition file imports `package:mosaic_widgets/mosaic_widgets.dart` | Use `package:mosaic_widgets/dsl.dart` in definition files |
| Function named wrong | It must be `build<Name>()` where `<Name>` matches the `mosaic.yaml` entry |
| Forgot to register in `mosaic.yaml` | Add it under `widgets:` / `live_activities:` |
| Bound date shows wrong | `MFormat.date`/`relativeTime` expect epoch **milliseconds** |
| iOS Live Activity never starts | Add `NSSupportsLiveActivities=true`; wire AppDelegate from the generated template |
| Expecting Dynamic Island on Android | Not supported — Android live activity is an ongoing notification |
| `MGauge` arc on Android | Android approximates it as a linear ProgressBar (RemoteViews has no arc) |
| Container shadow on Android | Ignored (RemoteViews has no drop shadow) |

## Control Widgets (iOS 18 Control Center / Android Quick Settings)

Control widgets are separate from home-screen widgets. They live in `*.control.dart` files (import `package:mosaic_widgets/dsl.dart`, no Flutter), export `MControl build<Name>()`, and are registered under `controls:` in `mosaic.yaml`.

```dart
import 'package:mosaic_widgets/dsl.dart';

MControl buildTorch() => const MControl(
  name: 'Torch',
  kind: MControlKind.toggle,   // or MControlKind.button
  label: 'Flashlight',
  sfSymbol: 'flashlight.on.fill',   // iOS SF Symbol
  androidIcon: 'ic_torch',          // Android drawable (optional)
  valueKey: 'torch_on',             // toggles only — shared-store bool key
  action: MActionCallback('toggle_torch'),
);
```

`mosaic.yaml` registration (parallel to `widgets:` and `live_activities:`):
```yaml
controls:
  - name: Torch
    entry: lib/platform/controls/torch.control.dart
```

**`MControl` constructor** — all named args: `name` (String, required), `kind` (MControlKind, required), `label` (String, required), `sfSymbol` (String?), `androidIcon` (String?), `valueKey` (String?, toggles), `action` (MAction, required). `MActionCallback`, `MLaunchUrlAction`, and `MRefreshAction` are all valid actions.

**iOS behaviour (iOS 18+):** `mosaic_cli build` emits a `<Name>Control.swift` (`ControlWidgetToggle` / `ControlWidgetButton`) into `ios/HomeWidgetExtension/`, gated `@available(iOS 18.0, *)`. The toggle reads its current state from the App Group `UserDefaults` bool at `valueKey`; tapping writes the new value back and fires the action. A shared `MosaicControlIntents.swift` (also emitted) provides the `SetValueIntent`. Controls are registered in `HomeWidgetBundle.swift` under an iOS 18 gate. Controls are part of the same Widget Extension used for home-screen widgets — no additional Xcode target is required.

**Android behaviour (API 24+, user-added):** A `<Name>TileService.kt` (`TileService` subclass) is emitted under `mosaic_generated`. For toggles `onStartListening` reads `widget_data` SharedPreferences under `valueKey` and sets `STATE_ACTIVE`/`STATE_INACTIVE`; `onClick` flips the bool and broadcasts a `MOSAIC_CALLBACK` intent (same path as widget buttons). For buttons `onClick` fires the callback directly. The `<service>` tag (with `BIND_QUICK_SETTINGS_TILE` permission and the QS tile intent-filter) is **auto-added to `AndroidManifest.xml`** by `mosaic_cli build`. QS tiles are user-added from the Quick Settings edit panel.

## Platform notes
- Widget definitions, live activities, and control widgets are **pure data** — no Flutter widgets, no `setState`, no runtime logic; all dynamism comes from `MBind` + the data the app pushes.
- iOS deployment: configurable widgets and AppIntent buttons need iOS 17+; Live Activities/Dynamic Island/accessory widgets need iOS 16+/16.1+; Control widgets need iOS 18+. Non-configurable home widgets work on iOS 14+.
- Android live activities use **Android 16 Live Updates** (`Notification.ProgressStyle` + promoted-ongoing) on API 36+; the custom-RemoteViews ongoing notification is the pre-36 fallback.
- iOS ActivityKit code uses the non-deprecated iOS 16.2+ `ActivityContent` APIs with a 16.1 fallback.
- Deeper docs in the repo: `docs/DSL_REFERENCE.md`, `docs/IOS_SETUP.md`, `docs/ANDROID_SETUP.md`, `docs/LIVE_ACTIVITIES.md`, `docs/ROADMAP.md`.
