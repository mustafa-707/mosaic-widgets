# mosaic

**One DSL. Live native tiles. iOS + Android.**

Mosaic lets you define home-screen widgets and Live Activities in Dart, then generates
production-quality native code — SwiftUI/WidgetKit on iOS, RemoteViews/Kotlin on Android —
from a single source of truth. No platform-specific UI code required.

## Ecosystem

| Package | Role |
|---------|------|
| **mosaic** ← _you are here_ | Flutter DSL + `MosaicBridge` runtime |
| [mosaic_core](https://pub.dev/packages/mosaic_core) | IR, config, runner primitives |
| [mosaic_android](https://pub.dev/packages/mosaic_android) | Android RemoteViews/Kotlin generator |
| [mosaic_ios](https://pub.dev/packages/mosaic_ios) | iOS WidgetKit/Live Activity generator |
| [mosaic_cli](https://pub.dev/packages/mosaic_cli) | `dart run mosaic_cli build` and friends |

## Install

```yaml
# pubspec.yaml
dependencies:
  mosaic: ^0.0.1

dev_dependencies:
  mosaic_cli: ^1.0.0
```

---

## Quick start

### 1. Define a widget

Widget definition files import the **pure-Dart DSL** (`package:mosaic_widgets/dsl.dart`) so
the build runner can execute them with `dart run` — no Flutter runtime needed at
build time.

```dart
// lib/widgets/price.widget.dart
import 'package:mosaic_widgets/dsl.dart';

MosaicDefinition buildPriceWidget() {
  return MosaicDefinition(
    name: 'PriceWidget',
    width: 2,
    height: 2,
    root: MContainer(
      background: const MColor.hex('#1E3A8A'),
      radius: 16,
      child: MPadding(
        const MInsets.all(12),
        MColumn([
          const MText(
            'BTC / USD',
            style: MTextStyle(
              color: MColor.hex('#93C5FD'),
              size: 11,
              bold: true,
            ),
          ),
          // MBind resolves against values pushed from MosaicBridge at runtime.
          MText(
            MBind('btc_price'),
            format: MFormat.currency, // locale-aware formatting
            style: const MTextStyle(
              // Adaptive: white in light mode, soft grey in dark mode.
              color: MColor.hex('#FFFFFF', dark: '#E5E7EB'),
              size: 20,
              bold: true,
            ),
          ),
        ]),
      ),
    ),
  );
}
```

### 2. Register in `mosaic.yaml`

```yaml
app:
  bundle_id: com.example.myapp
  android_package: com.example.myapp
  ios_app_group: group.com.example.myapp.widgets

widgets:
  - name: PriceWidget
    entry: lib/widgets/price.widget.dart
    ios:
      families: [systemSmall, systemMedium]
    android:
      sizes: [medium]
```

### 3. Generate native code

```bash
dart run mosaic_cli build
```

Re-run this after every DSL change. The command is safe to run repeatedly.

### 4. Push data from your Flutter app

App code uses the **full barrel** (`package:mosaic_widgets/mosaic_widgets.dart` = DSL + `MosaicBridge`):

```dart
import 'package:mosaic_widgets/mosaic_widgets.dart';

// Called once, e.g. in main():
await MosaicBridge.setAppGroupId('group.com.example.myapp.widgets');

// Push values keyed to MBind names, then trigger a widget refresh:
await MosaicBridge.saveString('btc_price', '67420.00');
await MosaicBridge.saveString('btc_change', '+2.4%');
await MosaicBridge.refreshAll(); // or MosaicBridge.refresh('PriceWidget')
```

---

## Features

- **Single DSL for both platforms** — write once in Dart, generate native SwiftUI and Kotlin.
- **Native performance** — widgets render via SwiftUI/WidgetKit (iOS) and RemoteViews (Android); no WebView.
- **Live runtime data binding** — `MBind` binds text, image file paths, progress values,
  visibility, and timer targets; push values from your app via `MosaicBridge.saveString/saveBool/saveJson/saveList`.
- **Rich UI** — linear gradients, borders, stacks, columns, rows, images (asset + file),
  progress bars, native timers, buttons, and deep links.
- **Adaptive theming** — OS light/dark colors (`MColor.hex(dark:)`), runtime-bound colors
  (`MColor.bind`), and locale-aware value formatting (`MFormat.currency`, `.percent`,
  `.relativeTime`, …).
- **Lock-screen accessory widgets** — iOS 16+ `accessoryRectangular`, `accessoryCircular`,
  `accessoryInline` families with automatic `.widgetAccentable()` emission.
- **Live Activities & Dynamic Island** — declare a `MosaicLiveActivity` (lock-screen
  banner + Dynamic Island compact/minimal/expanded) and drive it from Flutter via
  `MosaicLiveActivities.start/update/end`. Android falls back to an ongoing notification.
- **Automatic RTL mirroring** — layouts use `start`/`end` semantics; no manual platform code.
- **Asset sync** — images from your Flutter project are automatically synced to native
  `drawable`/`xcassets` folders.

---

## Live Activities

```dart
// lib/live_activities/order.live.dart
import 'package:mosaic_widgets/dsl.dart';

MosaicLiveActivity buildOrderTracker() {
  return MosaicLiveActivity(
    name: 'OrderTracker',
    lockScreen: MText(MBind('status')),
    dynamicIsland: MDynamicIsland(
      compactLeading: const MText('🛵'),
      compactTrailing: MText(MBind('eta')),
      minimal: const MText('🛵'),
      expanded: MExpanded(
        center: MText(MBind('status')),
        bottom: MProgressBar(value: MBind('progress')),
      ),
    ),
  );
}
```

```dart
// App code — full barrel import.
import 'package:mosaic_widgets/mosaic_widgets.dart';

final id = await MosaicLiveActivities.start('OrderTracker', {
  'status': 'Preparing your order',
  'progress': '0.1',
  'eta': '25 min',
});
await MosaicLiveActivities.update(
  id!,
  {'status': 'On the way', 'progress': '0.6', 'eta': '8 min'},
  alert: const MActivityAlert(title: 'Order update', body: 'Your courier is nearby'),
);
await MosaicLiveActivities.end(id, policy: MEndPolicy.afterDefault);
```

---

## Documentation

- [DSL Reference](https://github.com/your-org/mosaic/blob/main/DOCS/DSL_REFERENCE.md) — all
  components, styling, binding, actions, and Live Activity DSL.
- [Live Activities Guide](https://github.com/your-org/mosaic/blob/main/DOCS/LIVE_ACTIVITIES.md)
- [Android Setup Guide](https://github.com/your-org/mosaic/blob/main/DOCS/ANDROID_SETUP.md)
- [iOS Setup Guide](https://github.com/your-org/mosaic/blob/main/DOCS/IOS_SETUP.md)
- [Full demo app](https://github.com/your-org/mosaic/tree/main/examples/demo_app)
