# DSL Reference

The Mosaic DSL lets you build native UIs using a Flutter-like declarative syntax. All DSL symbols are prefixed with `M`, and the root type is `MosaicDefinition`.

Widget definition files import the pure-Dart DSL:

```dart
import 'package:mosaic_widgets/dsl.dart';
```

## Root

### MosaicDefinition
The top-level definition returned by a widget builder function. The function must
be named `build<Name>()`, where `<Name>` is the widget's `name:` in
`mosaic.yaml` — `build` verifies this before generating and reports the expected
name and file if they disagree.
- `name`: `String` — widget identifier (must match `mosaic.yaml`).
- `root`: `MNode` — the root component.
- `width`, `height`: `int` — grid cells.
- `updateInterval`: `Duration?` — how often the timeline refreshes.
- `previewImage`: `String?`
- `resizeMode`: `MResizeMode` (`none` | `horizontal` | `vertical` | `both`).
- `compactRoot`: `MNode?` — an alternate tree for the smallest sizes. **iOS
  only** (see below).

#### `compactRoot` — a second tree for small tiles

A `systemSmall` tile is about a quarter of a `systemLarge` one, so a definition
that renders one tree at both sizes either wastes the large or overflows the
small. Pass `compactRoot:` and iOS renders it for `systemSmall`,
`accessoryCircular`, and `accessoryInline`; every other family renders `root`.
The choice happens at render time via `@Environment(\.widgetFamily)`, so both
trees ship in the same widget.

```dart
MosaicDefinition(
  name: 'ProfileVP',
  compactRoot: MText(MDeviceValue(MDeviceMetric.batteryLevel)),  // one number
  root: MColumn([...]),                                          // the full card
);
```

**Android** hands the launcher a `RemoteViews(Map<SizeF, RemoteViews>)` on
API 31+, which picks the largest entry that fits. The breakpoint is the widget's
own declared minimum (`70dp` per cell less `30dp` padding), so the full tree
appears at the size you designed it for and the compact one only when the user
resizes below that. On API 30 and older the platform cannot switch, so `root`
renders at every size.

### Minimal widget config

A widget needs only a name and an entry in `mosaic.yaml`:

```yaml
widgets:
  - name: Steps
    entry: lib/home_widgets/steps.widget.dart
```

`dart run mosaic_widgets:mosaic add widget Steps` scaffolds the file and adds this for you, choosing
the directory your existing entries already use.

- **`ios: { families: [...] }`** — optional; defaults to `[systemSmall, systemMedium]`.
- **`android: { min_sdk, sizes }`** — optional and **inert**. Both keys are reserved and change nothing in the output: a widget's grid footprint comes from `MosaicDefinition(width:, height:)` and its resize behaviour from `resizeMode`. They are still accepted so existing configs keep working.

## Core Components

### Layouts
- **MContainer**: Box with `background` (`MColor`), `gradient` (`MGradient`), `radius`, `border` (`MBorder`), `width`, `height`, `margin` (`MInsets`), and `padding` (`MInsets`). `padding` sits **inside** the background and border — like Flutter's `Container(padding:)` — so it saves wrapping the child in an `MPadding`; `margin` sits outside. Both mirror in RTL locales.
- **MPadding**: Adds space (`MInsets`) around its child.
- **MColumn**: Vertical stack of children. Props: `mainAxisAlignment`, `crossAxisAlignment`.
- **MRow**: Horizontal stack of children. Props: `mainAxisAlignment`, `crossAxisAlignment`.
- **MStack**: Layers children on top of each other.
- **MPositioned**: Absolute positioning (`top`, `left`, `right`, `bottom`) for children of an `MStack`.
- **MCenter**: Centers its child within its parent.
- **MSpacer**: Flexible space that expands to fill available room.
- **MDivider**: A rule — `MDivider(thickness: 1, color: …, vertical: false, indent: 0)`. `vertical: true` gives a column separator; `indent` insets both ends.
- **MSizedBox**: A fixed-size box. `MSizedBox.height(8)` / `MSizedBox.width(8)` are exact gaps — unlike `MSpacer`, which absorbs whatever room is left. `MSizedBox(width:, height:, child:)` constrains a child; `MSizedBox.square(40)` sizes both axes. An unset axis sizes itself.
- **MFlexible**: Gives a child a proportional share of the free space along its parent's main axis — only meaningful as a direct child of an `MRow`/`MColumn`. `MFlexible(flex: 2, child: …)` beside `flex: 1` takes twice the room.
  - **Android** honours the exact ratio (`layout_weight` with `0dp` on the main axis).
  - **iOS** has no proportional flex in SwiftUI, so every `MFlexible` sibling splits the space *equally* regardless of `flex`. `flex: 1` behaves identically on both; other ratios are Android-only. Use explicit `MSizedBox` sizes when a ratio must hold on both platforms.
- **MAlign**: Positions a child within the space the parent offers, via `MAlignment` (`topStart` … `bottomEnd`, `center`). Uses start/end rather than left/right, so it mirrors in RTL locales — on Android as `layout_gravity`, on iOS as a SwiftUI `Alignment`. `MCenter` is the `center` case.

### Alignment enums
- **MMainAxisAlignment**: `start` · `center` · `end` · `spaceBetween` · `spaceAround` · `spaceEvenly` — distributes children along a Row/Column's main axis.
- **MCrossAxisAlignment**: `start` · `center` · `end` · `stretch` — positions them across it.
- **MAlignment** (for `MAlign`): `topStart` … `bottomEnd`, plus `center`.
- **MStackAlignment** (for `MStack`): `topLeading` … `bottomTrailing` — where unpositioned children sit.

### Basic Widgets
- **MText**: Displays a `String` or an `MBind` value. Props: `style` (`MTextStyle`), `format` (`MFormat?`). _Runtime binding: text supports `MBind`._ When `format` is set on a bound value, the value is formatted with the device locale at render (see [MFormat](#mformat-locale-aware-formatting)).
- **MImage**: Displays an image from `MAssetImage(path)` or `MFileImage(path)`. Props: `fit` (`MBoxFit`). _Runtime binding: `MFileImage` path supports `MBind` (e.g. a file path pushed from the app)._
- **MNetworkImage**: Displays a remote image — `MNetworkImage(MBind('avatar_url'), placeholder: …, radius: 16)` or `circle: true` for avatars. The widget process downloads and disk-caches it **itself**, so the picture appears with the app closed.
  - Follows `http`→`https` redirects manually and retries over https, because `HttpURLConnection` silently drops cross-protocol redirects and cleartext is blocked by default in release builds.
  - Decoded **downsampled** (longest side ≤ 320px). A full-resolution photo would exceed Android's RemoteViews transaction limit and silently blank the entire widget — every bound value at once, with nothing logged.
- **MProgressBar**: Native progress bar. Props: `value` (`double` or `MBind`), `max`, `color`. _Runtime binding: `value` supports `MBind`._
- **MTimer**: Native chronometer counting up or down to a `target` (`DateTime`). Props: `countUp`, `style`. _Runtime binding: the timer target is resolvable at runtime._
- **MButton**: Makes its `child` clickable, triggering an `MAction`.

### Charts
- **MSparkline**: A line chart of a bound numeric series — `MSparkline(bind: MBind('prices'), color: …, strokeWidth: 2, fill: true, height: 40)`. Push the data with `MosaicBridge.saveList('prices', [1, 2, 3])`.
  - Values are **normalised across the series**, so only the shape matters, not the absolute range. A flat series draws down the middle instead of dividing by zero, and fewer than two points draws nothing.
  - **iOS** draws a real SwiftUI `Path`. **Android** cannot: RemoteViews has no vector drawing, so the provider rasterises the series to a bitmap with `Canvas` at update time and sets it on an `ImageView`. Same picture; the Android one is resolution-fixed to the widget's current size.
  - `color` must be a literal — the Android bitmap is rasterised with a fixed paint, so bound colours are not supported here.
- **MBarChart**: Bars for a bound numeric series — `MBarChart(bind: MBind('week'), color: …, spacing: 3, radius: 2, height: 24)`.
  - Unlike `MSparkline`, bars are scaled **from zero**, not from the series minimum: a bar's length reads as its magnitude, so starting the axis at the smallest value would overstate small differences. A series with no positive value renders empty, and a zero bucket keeps a hairline so it reads as a bucket rather than a gap.
  - Same split as `MSparkline`: real SwiftUI shapes on iOS, a rasterised bitmap on Android.

### Icons, indicators and decoration
- **MIcon**: `MIcon(sfSymbol: 'cloud.sun.fill', androidDrawable: 'ic_weather', size: 24, color: …)`. Each platform uses its own name; a missing `androidDrawable` fails the build with the drawable named, rather than at AAPT time.
- **MGauge**: Circular/arc progress — `MGauge(value: MBind('pct'), max: 100, trackColor: …, fillColor: …, lineWidth: 6)`. `value` accepts a literal or an `MBind`.
- **MBadge**: Count or dot overlay on a child — `MBadge(child: MIcon(...), count: MBind('unread'), color: …)`.
- **MActivityIndicator**: `MActivityIndicator(size: 20, color: …)`. **Spins on Android only** (indeterminate `ProgressBar`); static on iOS. Pair with `MVisibility(bind: MBind('mosaic_refreshing'), …)` — Mosaic sets that key around an in-widget refresh.
- **MFlipper**: `MFlipper([child, child], interval: Duration(seconds: 4))` cycles its children. **Android only** — a `ViewFlipper` self-advances with the app closed; **iOS renders the first child only**, so put the lead content first.
- **MSemantics**: `MSemantics(label: 'Battery level', child: …, excludeChildren: false)` → iOS `.accessibilityLabel`, Android `contentDescription`. `label` accepts an `MBind`. `excludeChildren` collapses the subtree to one element on **both** platforms (iOS `.accessibilityElement(children: .ignore)`, Android `importantForAccessibility="noHideDescendants"` — a static layout attribute, so nothing needs to cross the RemoteViews boundary).

### Device metrics
- **MDeviceValue(MDeviceMetric.x)**: Read natively, usable anywhere an `MBind` is (text, progress, gauge). Metrics: `batteryLevel`, `batteryCharging`, `storageFreeGb`, `storageUsedPercent`, `memoryFreeMb`, `memoryTotalMb`, `memoryUsedPercent`.
  - Read **in the widget process**, so values stay correct when the app has not run for days — with one exception.
  - **Battery on iOS is the exception.** `isBatteryMonitoringEnabled` is a no-op inside an app extension, so `batteryLevel` there is always `-1`, on real devices as much as the simulator. Mosaic publishes it from the *app* instead, so on iOS the value appears once the app has run and then tracks changes while it lives. It never resolves in the iOS simulator, which has no battery at all. Android reads it in the widget process as normal.
  - **Memory on iOS** uses `ProcessInfo.physicalMemory` for the total and Mach `host_statistics64` for free pages (counting `inactive`, which is reclaimable, so the figure matches what a system memory panel shows).

### Lists
- **MListView**: Repeats an `itemTemplate` (`MNode`) over a bound list (`bind`: `MBind`). Push the data with `MosaicBridge.saveList('key', [{...}, ...])`; each entry is a map, and the item template binds its keys by name (`MText(MBind('title'))`).
  - **iOS**: renders real per-element item templates.
  - **Android**: backed by a generated `RemoteViewsService`/`RemoteViewsFactory`, so the list scrolls with the app closed. The `<service>` is registered in the manifest by `dart run mosaic_widgets:mosaic build`.
  - Item templates are rendered once per row, so keep them shallow — RemoteViews has a hard limit on the total view count in a widget.

### Visibility
- **MVisibility**: Toggles visibility of a `child` based on a binding (`bind`: `MBind`), with an optional `replacement` node. _Runtime binding: visibility is driven by a bound boolean._

## Styling

### MTextStyle
- `color`: `MColor`
- `size`: `double`
- `opacity`: `double`
- `bold`: `bool`

### MColor
- **Plain / opacity**: `MColor.hex("#RRGGBB")`, optionally with `opacity:` (e.g. `MColor.hex("#F43F5E", opacity: 0.1)`).
- **Adaptive (OS light/dark)**: `MColor.hex("#FFFFFF", dark: "#E5E7EB")` — the first value is used in light appearance, the `dark:` value in dark appearance.
  - **iOS**: resolved via `@Environment(\.colorScheme)`.
  - **Android**: emitted as a `res/values/` + `res/values-night/` color resource pair, referenced by `@color/mosaic_<hash>`.
- **System theme (Material You)**: `MColor.system(MSystemColor.accent, fallback: "#2563EB", fallbackDark: "#60A5FA")` — draws from the user's own theme so the widget matches the rest of their phone.
  - Roles: `accent`, `accentMuted`, `surface`, `onSurface`, `onSurfaceMuted`. Each has a light and a dark form, like `dark:` above.
  - **Android 12+ (API 31)**: resolves to the live wallpaper-derived palette. Emitted as four resources — `values/` and `values-night/` hold the fallback, `values-v31/` and `values-night-v31/` override with `@android:color/system_*`. The framework names do not exist below API 31, so referencing them unqualified would fail resource linking; the qualifier is what keeps older devices building.
  - **Older Android, and all of iOS**: render `fallback` / `fallbackDark`. iOS has no wallpaper-derived palette, so **the fallback is what users actually see there** — choose colours that stand on their own.
- **Runtime-bound**: `MColor.bind("accent")` — resolves a hex string pushed from the app via the data store at render/update time. Falls back to the light value (iOS) / clear when the key is missing. Accepts `opacity:`.
  - **Rounded containers**: a bound background on an `MContainer` with a `radius` keeps its corners. The layout carries a real shape and the provider *tints* it (`setBackgroundTintList`) rather than replacing the background — `setBackgroundColor` installs a flat `ColorDrawable` and would discard the shape. Tinting is **API 31+**; on older Android the flat fill is the only option RemoteViews offers, so the colour is right and the corners are square there.
- **Lock-screen note**: on iOS accessory (Lock Screen) widgets the OS renders content tinted/monochrome, so custom colors are largely ignored; Mosaic emits `.widgetAccentable()` on accent-able content.

### Reading back, files, and rendering Flutter into a widget

The shared store is not write-only. The widget writes to it too — an
`MToggleAction` flips its bool on-device with the app closed, and a declared
`refresh:` source stores what it fetched.

```dart
final on    = await MosaicBridge.getValue<bool>('torch_on') ?? false;
final rows  = await MosaicBridge.getValue<List<dynamic>>('tasks');
final placed = await MosaicBridge.installedWidgets();   // stop nagging once one exists
```

`MFileImage` needs a file in shared storage, and these put one there:

```dart
final path = await MosaicBridge.saveFile('avatar', bytes);          // raw bytes
final path = await MosaicBridge.saveImage('avatar', NetworkImage(u)); // any ImageProvider
```

**`renderFlutterWidget` is the escape hatch** for anything the DSL cannot
express — a chart, a `CustomPaint`, a layout with no widget-safe equivalent:

```dart
final path = await MosaicBridge.renderFlutterWidget(
  MyChart(data),
  key: 'chart',
  logicalSize: const Size(160, 120),
);
await MosaicBridge.saveString('chart_path', path!);   // shown via MFileImage(MBind('chart_path'))
```

The cost is that the result is a **static bitmap**: it does not adapt to
light/dark or to the widget's real size, and it must be re-rendered whenever the
content changes. Prefer real DSL nodes where they exist. Keep `logicalSize`
modest on Android — the bitmap crosses a Binder transaction with the RemoteViews
update, and an oversized one silently drops the whole update.

### Sizing a column inside a widget

The OS chooses a widget's height, not you. `MMainAxisAlignment.spaceBetween` on
a root `MColumn` therefore distributes *whatever height the family happened to
have* — a tree that looks balanced on a 2x2 Android cell opens holes on an iOS
`systemMedium`, and pushes a three-row `systemSmall` to its extremes.

Prefer `start` (or `center` for a single figure) with explicit `MSizedBox.height`
gaps, so spacing is deliberate rather than leftover. Reach for `spaceBetween`
only when you genuinely want the first and last children pinned to the edges.

### MFormat (locale-aware formatting)
`enum MFormat { decimal, currency, percent, date, relativeTime }`. Pass to `MText(..., format:)` to format a **bound** value with the device locale at render time:

```dart
MText(MBind("btc_price"), format: MFormat.currency);
MText(MBind("change"),    format: MFormat.percent);
MText(MBind("when"),      format: MFormat.relativeTime);
```

- **iOS**: maps to `formatted(.number/.currency/.percent)`, `Date(...).formatted(...)`, and `Text(date, style: .relative)`.
- **Android**: maps to `NumberFormat` (instance/currency/percent), `DateFormat.getDateInstance()`, and `DateUtils.getRelativeTimeSpanString`.
- Locale-dependent formats require a bound value; a missing key falls back to `--`.

### MShadow
`MShadow(color: …, blur: 8, dx: 0, dy: 2)` on `MContainer`. **iOS** uses `.shadow`, so `blur` is honoured. **Android** draws a `layer-list` with an offset silhouette behind the shape, matching its corner radius — RemoteViews has no blur primitive and `elevation` needs a view hierarchy the launcher does not provide, so `blur` is accepted and ignored there and the edge is hard. Offsets work in every direction; `dx`/`dy` read the same on both platforms.

### MRadius
Per-corner rounding: `MRadius.all(12)` or `MRadius(topLeft: 12, topRight: 12, bottomLeft: 0, bottomRight: 0)`. Takes precedence over `MContainer.radius`.

### MTextAlign
`start` · `center` · `end`, via `MText(..., align: MTextAlign.center)`. Start/end rather than left/right, so it mirrors in RTL.

### MInsets
`MInsets.all(value)`, `MInsets.symmetric(vertical:, horizontal:)`, or `MInsets.only(left:, top:, right:, bottom:)`.

### MBorder
`MBorder(color: MColor, width: double)` — rendered as real native borders.

### MLinearGradient
`MLinearGradient(colors: [MColor, ...], stops: [double, ...]?)` — rendered as real native linear gradients.

### MBoxFit
`fill` | `contain` | `cover` | `fitWidth` | `fitHeight` | `none` | `scaleDown`.

---

## Data Binding

Use `MBind("key")` anywhere a dynamic value is expected. Runtime binding is supported for:
- **Text** (`MText`)
- **Image file paths** (`MFileImage`)
- **Progress values** (`MProgressBar`)
- **Visibility** (`MVisibility`)
- **Timer targets** (`MTimer`)

Push values from your app through `MosaicBridge` (which imports the full barrel `package:mosaic_widgets/mosaic_widgets.dart`), then call `refresh` / `refreshAll`:

```dart
import 'package:mosaic_widgets/mosaic_widgets.dart';

await MosaicBridge.saveString("news_title", "Breaking News!");
await MosaicBridge.saveBool("is_online", true);
await MosaicBridge.saveJson("payload", {"id": 1});
await MosaicBridge.saveList("items", ["a", "b", "c"]);

await MosaicBridge.refresh("NewsWidget"); // single widget
await MosaicBridge.refreshAll();           // all widgets
```

## Actions

Actions are passed to `MButton(action: ...)`:

- **MLaunchUrlAction(url)**: Opens the app or a browser with the given URL.
  - A custom-scheme URL **must** use the `deep_link_scheme` from `mosaic.yaml` (default `mosaic`). Only that scheme is registered — as an Android `<intent-filter>` and an iOS `CFBundleURLTypes` entry, both written by `build` — so any other custom scheme produces a button that resolves to nothing. `build` fails rather than shipping a dead button.
  - `http`/`https` URLs are passed through to the browser and need no registration.
  - Changing `deep_link_scheme` replaces the previously generated registration on both platforms; a hand-written one is never touched.
- **MActionCallback(name)**: Triggers a Flutter background callback (registered via `MosaicBridge.registerBackgroundCallback`).
- **MRefreshAction()**: Reloads the widget in place, naming no callback. iOS reloads the timeline; Android refetches every `refresh:` source supplying a key this widget binds, then redraws. Both work with the app closed. `mosaic_refreshing` is true while the fetch is in flight.
- **MToggleAction(key)**: Flips a stored bool **entirely on-device** and redraws — no app launch, no network, works with the app closed. Pair with `MVisibility(bind: MBind(key), …)` to swap what is shown.

## Motion and tinting

Widgets render static snapshots on both platforms, so there is no general
animation and **Lottie is impossible** — it needs a live animation view neither
WidgetKit nor RemoteViews provides. What does exist:

- **MContentTransition**: `none` · `numericText`. On `MText(..., contentTransition: MContentTransition.numericText)` the digits roll to the new value. **iOS 17+ only**; Android ignores it.
- **MAccentedRendering**: `accented` · `accentedDesaturated` · `desaturated` · `fullColor`, via `MImage(..., accentedMode:)`. Controls how an image behaves when the user tints their widgets. **iOS 18+**; a no-op on Android. Photos usually want `fullColor`; glyphs want `accented`.
- See also `MActivityIndicator` (Android spins), `MFlipper` (Android cycles), and `MTimer` (ticks live on both).

## Configurable widgets

`MParam` declares a user-editable setting, surfaced by the OS: an
`AppIntentConfiguration` on iOS (17+) and a configuration `Activity` on Android.

```dart
params: [
  MParam(key: 'city', label: 'City', type: MParamType.choice,
         defaultValue: 'SF', choices: ['SF', 'NYC', 'London']),
]
```

- **MParamType**: `text` · `number` · `toggle` · `choice`.
- The chosen value lands in the widget's bind namespace under `key`, so `MBind('city')` reads it like any other value.

## Locale & RTL

- Layouts **auto-mirror** in RTL locales: generators emit `start`/`end` and `leading`/`trailing` (never absolute `left`/`right`). On iOS SwiftUI mirrors by locale; on Android the manifest needs `android:supportsRtl="true"`.
- Use `MFormat` (above) to format bound numeric/date values with the device locale.

### Translated text (`MLocalized`)

A widget renders outside the Flutter engine, so `intl`, `AppLocalizations`, and
anything else in your Dart localization stack are unreachable from it. Declare
widget text under `strings:` in `mosaic.yaml` instead and Mosaic emits **real
platform resources**, which the OS selects by device language — including when
the app has never launched.

```yaml
# mosaic.yaml — first locale listed is the fallback for unlisted languages
strings:
  en:
    trending_now: TRENDING NOW
    read_action: READ
  ar:
    trending_now: الأكثر تداولاً
    read_action: اقرأ
```

```dart
MText(const MLocalized("trending_now"), style: ...)
```

| | Generated | Selected by |
|---|---|---|
| Android | `res/values/mosaic_localized.xml` (default) + `res/values-<locale>/…`, referenced as `@string/mosaic_s_<key>` | system resource resolution |
| iOS | `HomeWidgetExtension/<locale>.lproj/Localizable.strings`, emitted as `Text(LocalizedStringKey("<key>"))` | bundle lookup in the extension |

Notes:
- Values are escaped per platform (XML entities / `\"`), so quotes and `&` are safe.
- A key missing from a **secondary** locale falls back to the default locale; `build` prints a warning naming the untranslated keys.
- A key missing from the **default** locale fails the build, because that locale is the only fallback: Android would emit no entry in the unqualified `values/` table and iOS would render the raw key.
- The strings live in the **widget extension's** bundle on iOS, not the app's — the app's `Localizable.strings` is not visible to it.
- `MLocalized` is for static text. Values that change at runtime are still `MBind`; combine with `MFormat` for locale-correct numbers and dates.

## iOS Lock-Screen Accessory Families

Widget families are declared per widget in `mosaic.yaml` under `ios.families`. In addition to the system families (`systemSmall`, `systemMedium`, `systemLarge`, ...), iOS 16+ Lock Screen accessory families are supported:

| Family | Rendering |
|--------|-----------|
| `accessoryRectangular` | The full small layout. |
| `accessoryCircular` | A single gauge/progress or primary value. |
| `accessoryInline` | Leading image + a single text. |

Accessory families are gated `if #available(iOS 16.0, *)`. **Android skips accessory families** (with a build-time notice) — there are no general user Lock Screen widgets on Android.

## Live Activities

Live Activities are described with their own DSL (separate from `MosaicDefinition`) and declared in `mosaic.yaml` under `live_activities:`. Define one per `*.live.dart` entry that imports `package:mosaic_widgets/dsl.dart` and exports `MosaicLiveActivity build<Name>()`. Binds inside any of these trees resolve against the activity's content-state data map (the `Map<String,String>` pushed from Flutter), not the widget data store.

### MosaicLiveActivity
- `name`: `String` — must match the `name` in `mosaic.yaml`.
- `lockScreen`: `MNode` — the lock-screen / banner presentation.
- `dynamicIsland`: `MDynamicIsland` — the iOS Dynamic Island regions (ignored on Android).

### MDynamicIsland
- `compactLeading`: `MNode` — leading content in the compact (pill) presentation.
- `compactTrailing`: `MNode` — trailing content in the compact presentation.
- `minimal`: `MNode` — the minimal presentation (shown when multiple activities are active).
- `expanded`: `MExpanded` — the long-press expanded presentation.

### MExpanded
Optional layout slots for the expanded Dynamic Island (each `MNode?`):
- `leading`, `trailing`, `center`, `bottom`.

```dart
import 'package:mosaic_widgets/dsl.dart';

MosaicLiveActivity buildOrderTracker() {
  return MosaicLiveActivity(
    name: 'OrderTracker',
    lockScreen: MColumn([
      const MText('Order on the way',
          style: MTextStyle(color: MColor.hex('#FFFFFF'), size: 14, bold: true)),
      MText(MBind('status'), style: const MTextStyle(color: MColor.hex('#9CA3AF'), size: 12)),
      MProgressBar(value: MBind('progress'), color: const MColor.hex('#34D399')),
    ]),
    dynamicIsland: MDynamicIsland(
      compactLeading: const MText('🛵', style: MTextStyle(size: 14)),
      compactTrailing: MText(MBind('eta')),
      minimal: const MText('🛵', style: MTextStyle(size: 12)),
      expanded: MExpanded(
        leading: const MText('Order'),
        trailing: MText(MBind('eta')),
        center: MText(MBind('status')),
        bottom: MProgressBar(value: MBind('progress'), color: const MColor.hex('#34D399')),
      ),
    ),
  );
}
```

The Flutter lifecycle API (`MosaicLiveActivities.start/update/end`, imported from `package:mosaic_widgets/mosaic_widgets.dart`) is documented in the [Live Activities Guide](LIVE_ACTIVITIES.md).

> **Android 16 Live Updates:** on API 36+ the ongoing notification is upgraded to a `Notification.ProgressStyle` promoted-ongoing notification (Android 16 "Live Update"). The `progress` key in the data map (integer 0–100) drives the progress bar. The custom-RemoteViews ongoing notification remains the pre-36 fallback.

---

## Control Widgets

Control widgets surface in iOS Control Center / Lock Screen (iOS 18+) and Android Quick Settings (API 24+). They are defined separately from home-screen widgets.

### File layout

Create a `*.control.dart` file that imports `package:mosaic_widgets/dsl.dart` and exports a top-level `MControl build<Name>()` function. Register it under `controls:` in `mosaic.yaml`:

```yaml
controls:
  - name: Torch
    entry: lib/platform/controls/torch.control.dart
```

### MControl

```dart
import 'package:mosaic_widgets/dsl.dart';

MControl buildTorch() => const MControl(
  name: 'Torch',
  kind: MControlKind.toggle,
  label: 'Flashlight',
  sfSymbol: 'flashlight.on.fill',
  androidIcon: 'ic_torch',
  valueKey: 'torch_on',
  action: MActionCallback('toggle_torch'),
);
```

Constructor (all named):

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `name` | `String` | yes | Must match the `mosaic.yaml` entry and the `build<Name>()` suffix. |
| `kind` | `MControlKind` | yes | `MControlKind.toggle` or `MControlKind.button`. |
| `label` | `String` | yes | Label shown beneath the control. |
| `sfSymbol` | `String?` | no | iOS SF Symbol name. |
| `androidIcon` | `String?` | no | Android drawable resource name. |
| `valueKey` | `String?` | no | Toggles only: the App Group / `widget_data` bool key for the on/off state. |
| `action` | `MAction` | yes | `MActionCallback`, `MLaunchUrlAction`, or `MRefreshAction`. |

### MControlKind

```dart
enum MControlKind { toggle, button }
```

- **toggle** — stateful control; state is read from and written to the shared store under `valueKey`. Emits `ControlWidgetToggle` (iOS) / a `TileService` that tracks `STATE_ACTIVE`/`STATE_INACTIVE` (Android).
- **button** — stateless control; fires its action on tap. Emits `ControlWidgetButton` (iOS) / a `TileService` `onClick` handler (Android).

### Platform notes

- **iOS (18+):** `dart run mosaic_widgets:mosaic build` emits `<Name>Control.swift` into `ios/HomeWidgetExtension/`, gated `@available(iOS 18.0, *)`. Toggle state is read from the App Group `UserDefaults` bool at `valueKey`. Controls share the existing Widget Extension — no new Xcode target is needed.
- **Android (API 24+):** `dart run mosaic_widgets:mosaic build` emits `<Name>TileService.kt` under `mosaic_generated` and auto-inserts the `<service>` declaration (with `BIND_QUICK_SETTINGS_TILE` permission) into `AndroidManifest.xml`. QS tiles are user-added from the Quick Settings edit panel.
