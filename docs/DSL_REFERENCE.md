# DSL Reference

The Antigravity Home Widget DSL allow you to build native UIs using a Flutter-like declarative syntax.

## Core Components

### Layouts
- **HWContainer**: Box with background, radius, border, width, height, and margin.
- **HWPadding**: Adds space around its child.
- **HWColumn**: Vertical stack of children.
- **HWRow**: Horizontal stack of children.
- **HWStack**: Layers children on top of each other.
- **HWPositioned**: Absolute positioning (top, left, right, bottom) for children of a `HWStack`.
- **HWCenter**: Centers its child within its parent.
- **HWSpacer**: Flexible space that expands to fill available room.

### Basic Widgets
- **HWText**: Displays a string or a `HWBind` value.
- **HWImage**: Displays an asset image or a file image (can be bound to a path).
- **HWProgressBar**: Displays a native progress bar (value can be bound).
- **HWTimer**: Displays a native chronometer (counting up or down to a target).
- **HWButton**: Makes its child clickable, triggering a native action.

### Visibility
- **HWVisibility**: Toggles visibility of a child based on a boolean value or binding.

## Styling

### HWTextStyle
- `color`: `HWColor` (hex or RGB)
- `size`: `double`
- `bold`: `bool`

### HWColor
Use `HWColor.hex("#RRGGBB")` or `HWColor.rgba(r, g, b, a)`.

---

## Data Binding

Use `HWBind("key")` anywhere a dynamic value is expected (Text, ProgressBar, Image paths).

In Flutter:
```dart
await HomeWidgetBridge.saveString("news_title", "Breaking News!");
await HomeWidgetBridge.refreshAll();
```

## Actions

- **HWLaunchUrlAction(url)**: Opens the app or a browser with the given URL.
- **HWActionCallback(name)**: Triggers a Flutter background callback.
- **HWRefreshAction()**: Forces the widget to refresh immediately.
