# DSL Reference

The Mosaic DSL lets you build native UIs using a Flutter-like declarative syntax. All DSL symbols are prefixed with `M`, and the root type is `MosaicDefinition`.

Widget definition files import the pure-Dart DSL:

```dart
import 'package:mosaic/dsl.dart';
```

## Root

### MosaicDefinition
The top-level definition returned by a widget builder function.
- `name`: `String` — widget identifier (must match `mosaic.yaml`).
- `root`: `MNode` — the root component.
- `width`, `height`: `int` — grid cells.
- `updateInterval`: `Duration?` — how often the timeline refreshes.
- `previewImage`: `String?`
- `resizeMode`: `MResizeMode` (`none` | `horizontal` | `vertical` | `both`).

## Core Components

### Layouts
- **MContainer**: Box with `background` (`MColor`), `gradient` (`MGradient`), `radius`, `border` (`MBorder`), `width`, `height`, and `margin` (`MInsets`).
- **MPadding**: Adds space (`MInsets`) around its child.
- **MColumn**: Vertical stack of children. Props: `mainAxisAlignment`, `crossAxisAlignment`.
- **MRow**: Horizontal stack of children. Props: `mainAxisAlignment`, `crossAxisAlignment`.
- **MStack**: Layers children on top of each other.
- **MPositioned**: Absolute positioning (`top`, `left`, `right`, `bottom`) for children of an `MStack`.
- **MCenter**: Centers its child within its parent.
- **MSpacer**: Flexible space that expands to fill available room.

### Basic Widgets
- **MText**: Displays a `String` or an `MBind` value. Props: `style` (`MTextStyle`), `format` (`MFormat?`). _Runtime binding: text supports `MBind`._ When `format` is set on a bound value, the value is formatted with the device locale at render (see [MFormat](#mformat-locale-aware-formatting)).
- **MImage**: Displays an image from `MAssetImage(path)` or `MFileImage(path)`. Props: `fit` (`MBoxFit`). _Runtime binding: `MFileImage` path supports `MBind` (e.g. a file path pushed from the app)._
- **MProgressBar**: Native progress bar. Props: `value` (`double` or `MBind`), `max`, `color`. _Runtime binding: `value` supports `MBind`._
- **MTimer**: Native chronometer counting up or down to a `target` (`DateTime`). Props: `countUp`, `style`. _Runtime binding: the timer target is resolvable at runtime._
- **MButton**: Makes its `child` clickable, triggering an `MAction`.

### Lists
- **MListView**: Repeats an `itemTemplate` (`MNode`) over a bound list (`bind`: `MBind`).
  - **iOS**: renders real per-element item templates.
  - **Android**: **not yet implemented** — the build throws a clear error at build time. Use an `MColumn` for now.

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
- **Runtime-bound**: `MColor.bind("accent")` — resolves a hex string pushed from the app via the data store at render/update time. Falls back to the light value (iOS) / clear when the key is missing.
- **Lock-screen note**: on iOS accessory (Lock Screen) widgets the OS renders content tinted/monochrome, so custom colors are largely ignored; Mosaic emits `.widgetAccentable()` on accent-able content.

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

Push values from your app through `MosaicBridge` (which imports the full barrel `package:mosaic/mosaic.dart`), then call `refresh` / `refreshAll`:

```dart
import 'package:mosaic/mosaic.dart';

await MosaicBridge.saveString("news_title", "Breaking News!");
await MosaicBridge.saveBool("is_online", true);
await MosaicBridge.saveJson("payload", {"id": 1});
await MosaicBridge.saveList("items", ["a", "b", "c"]);

await MosaicBridge.refresh("NewsWidget"); // single widget
await MosaicBridge.refreshAll();           // all widgets
```

## Actions

Actions are passed to `MButton(action: ...)`:

- **MLaunchUrlAction(url)**: Opens the app or a browser with the given URL (deep links use the `deep_link_scheme` from `mosaic.yaml`, default `mosaic`).
- **MActionCallback(name)**: Triggers a Flutter background callback (registered via `MosaicBridge.registerBackgroundCallback`).
- **MRefreshAction()**: Forces the widget to refresh immediately.

## Locale & RTL

- Layouts **auto-mirror** in RTL locales: generators emit `start`/`end` and `leading`/`trailing` (never absolute `left`/`right`). On iOS SwiftUI mirrors by locale; on Android the manifest needs `android:supportsRtl="true"`.
- Use `MFormat` (above) to format bound numeric/date values with the device locale.

## iOS Lock-Screen Accessory Families

Widget families are declared per widget in `mosaic.yaml` under `ios.families`. In addition to the system families (`systemSmall`, `systemMedium`, `systemLarge`, ...), iOS 16+ Lock Screen accessory families are supported:

| Family | Rendering |
|--------|-----------|
| `accessoryRectangular` | The full small layout. |
| `accessoryCircular` | A single gauge/progress or primary value. |
| `accessoryInline` | Leading image + a single text. |

Accessory families are gated `if #available(iOS 16.0, *)`. **Android skips accessory families** (with a build-time notice) — there are no general user Lock Screen widgets on Android.

## Live Activities

Live Activities are described with their own DSL (separate from `MosaicDefinition`) and declared in `mosaic.yaml` under `live_activities:`. Define one per `*.live.dart` entry that imports `package:mosaic/dsl.dart` and exports `MosaicLiveActivity build<Name>()`. Binds inside any of these trees resolve against the activity's content-state data map (the `Map<String,String>` pushed from Flutter), not the widget data store.

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
import 'package:mosaic/dsl.dart';

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

The Flutter lifecycle API (`MosaicLiveActivities.start/update/end`, imported from `package:mosaic/mosaic.dart`) is documented in the [Live Activities Guide](LIVE_ACTIVITIES.md).
