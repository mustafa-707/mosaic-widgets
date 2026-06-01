# mosaic_android

**Android RemoteViews and Kotlin code generator for the Mosaic ecosystem.**

`mosaic_android` walks the Mosaic IR tree and emits the Kotlin `AppWidgetProvider`
subclasses, `RemoteViews` builders, XML metadata, and `res/values` color resources
required to render a Mosaic widget on Android home screens.

This package is **used by `mosaic_cli`** during `dart run mosaic_cli build`. App
developers do not add it directly — add [`mosaic_cli`](https://pub.dev/packages/mosaic_cli)
as a dev dependency instead.

## Ecosystem

| Package | Role |
|---------|------|
| [mosaic](https://pub.dev/packages/mosaic) | Flutter DSL + `MosaicBridge` runtime |
| [mosaic_core](https://pub.dev/packages/mosaic_core) | IR, config, runner primitives |
| **mosaic_android** ← _you are here_ | Android RemoteViews/Kotlin generator |
| [mosaic_ios](https://pub.dev/packages/mosaic_ios) | iOS WidgetKit/Live Activity generator |
| [mosaic_cli](https://pub.dev/packages/mosaic_cli) | `dart run mosaic_cli build` and friends |

## Install

Only add this explicitly if you are building a custom code-generation pipeline.

```yaml
dev_dependencies:
  mosaic_android: ^1.0.0
```

## What's generated

For each widget registered in `mosaic.yaml`, `mosaic_android` emits:

- A Kotlin `AppWidgetProvider` subclass (`<Name>Provider.kt`) that builds a
  `RemoteViews` tree from the Mosaic IR.
- `MosaicData.kt` — reads the shared `HomeWidgetPlugin` data store and exposes
  bound `MBind` values to the provider at update time.
- `res/values/mosaic_colors.xml` and `res/values-night/mosaic_colors.xml` — adaptive
  color resources for `MColor.hex(dark:)` pairs.
- `res/xml/<name>_info.xml` — AppWidget provider metadata files.
- For Live Activities: `MosaicLiveActivityManager.kt` that maps Flutter
  `MosaicLiveActivities.start/update/end` calls to Android ongoing notifications
  built from the `lockScreen` tree.

## Supported DSL features

All core layout and widget nodes are supported.

- **`MListView`** renders a real Android collection via `RemoteViewsService` /
  `RemoteViewsFactory`. The generator emits a `<ListView>` in the widget layout,
  a per-row item layout (`hw_listitem_<widget>_<key>.xml`) rendered from the
  `itemTemplate`, and a shared `MosaicListService.kt` whose factory reads
  `MosaicData.resolveList(context, "<key>")` and sets each per-row bound field
  (`hw_item_<field>`) from the row map. The provider wires the adapter with
  `setRemoteAdapter` + `notifyAppWidgetViewDataChanged`. The `mosaic_cli build`
  manifest automation declares the service with
  `android:permission="android.permission.BIND_REMOTEVIEWS"`. Item templates of
  Text/Image/Row/Column are the supported priority; deeply nested or unsupported
  item nodes are rendered best-effort.

For all supported DSL nodes and attributes see the
[DSL Reference](https://github.com/your-org/mosaic/blob/main/DOCS/DSL_REFERENCE.md).
