# mosaic_ios

**iOS WidgetKit, Live Activity, and Dynamic Island code generator for the Mosaic ecosystem.**

`mosaic_ios` walks the Mosaic IR tree and emits the Swift/SwiftUI source files required
to render a Mosaic widget on iOS home screens, lock screens, and the Dynamic Island —
including full ActivityKit Live Activity support (iOS 16.1+).

This package is **used by `mosaic_cli`** during `dart run mosaic_cli build`. App
developers do not add it directly — add [`mosaic_cli`](https://pub.dev/packages/mosaic_cli)
as a dev dependency instead.

## Ecosystem

| Package | Role |
|---------|------|
| [mosaic](https://pub.dev/packages/mosaic) | Flutter DSL + `MosaicBridge` runtime |
| [mosaic_core](https://pub.dev/packages/mosaic_core) | IR, config, runner primitives |
| [mosaic_android](https://pub.dev/packages/mosaic_android) | Android RemoteViews/Kotlin generator |
| **mosaic_ios** ← _you are here_ | iOS WidgetKit/Live Activity generator |
| [mosaic_cli](https://pub.dev/packages/mosaic_cli) | `dart run mosaic_cli build` and friends |

## Install

Only add this explicitly if you are building a custom code-generation pipeline.

```yaml
dev_dependencies:
  mosaic_ios: ^1.0.0
```

## What's generated

For each widget registered in `mosaic.yaml`, `mosaic_ios` emits:

- A SwiftUI `View` struct (`<Name>EntryView.swift`) built from the Mosaic IR, with
  full `@Environment(\.colorScheme)` handling for adaptive `MColor.hex(dark:)` colors.
- A `TimelineProvider` and `Widget` struct that registers the widget with WidgetKit.
- Lock-screen accessory family views (`accessoryRectangular`, `accessoryCircular`,
  `accessoryInline`) gated `if #available(iOS 16.0, *)`, with `.widgetAccentable()`
  emitted on accent-able content.
- For Live Activities (iOS 16.1+): `MosaicActivityAttributes.swift` and
  `<Name>LiveActivity.swift` covering the lock-screen banner and all three Dynamic
  Island presentations (compact leading/trailing, minimal, expanded). Registered in
  the widget bundle under an `@available(iOS 16.1, *)` gate.
- `MosaicActivityController.swift` — the `AppDelegate` bridge that routes Flutter
  `MosaicLiveActivities.start/update/end` method-channel calls to ActivityKit.

## Supported DSL features

The full DSL surface is supported on iOS, including:

- All layout nodes (`MContainer`, `MColumn`, `MRow`, `MStack`, `MPositioned`, `MCenter`, …)
- `MListView` — renders real per-element item templates via SwiftUI `ForEach`.
- `MFormat` locale-aware formatting (`.currency`, `.percent`, `.relativeTime`, `.date`, …)
- `MTimer` — native SwiftUI `Text(date, style:)` chronometers.
- Lock-screen accessory families.
- Live Activities and Dynamic Island.

For all supported DSL nodes and attributes see the
[DSL Reference](https://github.com/your-org/mosaic/blob/main/DOCS/DSL_REFERENCE.md).
For Live Activity setup see the
[Live Activities Guide](https://github.com/your-org/mosaic/blob/main/DOCS/LIVE_ACTIVITIES.md).
