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
- **MText**: Displays a `String` or an `MBind` value. Props: `style` (`MTextStyle`). _Runtime binding: text supports `MBind`._
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
Use `MColor.hex("#RRGGBB")`, optionally with `opacity:` (e.g. `MColor.hex("#F43F5E", opacity: 0.1)`).

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
