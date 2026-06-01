# Mosaic

**One DSL. Live native tiles. iOS + Android.**

A powerful, DSL-based framework for building native iOS and Android home widgets using Flutter-like syntax.

## 🚀 Features

- **Single DSL for Both Platforms**: Write once in Dart, generate native Swift (iOS) and XML/Kotlin (Android).
- **Native Performance**: Widgets are rendered using standard platform components (`RemoteViews` on Android, `SwiftUI` on iOS).
- **Interactive**: Support for buttons, deep linking, and background refreshes.
- **Live Runtime Data Binding**: Bind text, image file paths, progress values, visibility, and timer targets at runtime with `MBind`. Push values from your app via `MosaicBridge` and `refresh`/`refreshAll`.
- **Rich UI**: Real linear gradients and borders, Stacks, Columns, Rows, Images (asset + file sources), and more.
- **Adaptive Widgets**: OS light/dark theming and runtime-bound colors (`MColor.hex(dark:)`, `MColor.bind`), locale-aware value formatting (`MFormat`), automatic RTL mirroring, and iOS lock-screen accessory widgets.
- **Live Activities & Dynamic Island**: Declare a `MosaicLiveActivity` (lock-screen banner + Dynamic Island) and drive it from Flutter with `MosaicLiveActivities.start/update/end`. Full iOS ActivityKit support; Android falls back to an ongoing notification.
- **Asset Sync**: Automatically syncs images from your Flutter project to native drawable/xcassets folders.

## 🏗️ Architecture

- `mosaic_core`: The Intermediate Representation (IR), config parsing, and basic widget runner.
- `mosaic`: The Flutter DSL and `MosaicBridge` used to communicate with native code.
- `mosaic_android`: Generator for Android AppWidget code.
- `mosaic_ios`: Generator for iOS WidgetKit code.
- `mosaic_cli`: CLI tool to orchestrate code generation and automated configuration.

## 🛠️ Getting Started

### 1. Add Dependencies
Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  mosaic:
    path: path/to/mosaic/platform/flutter
  mosaic_core:
    path: path/to/mosaic/platform/core

dev_dependencies:
  mosaic_cli:
    path: path/to/mosaic/platform/cli
```

### 2. Initialize
Create a `mosaic.yaml` in your project root (or run `dart run mosaic_cli init`):

```yaml
app:
  bundle_id: com.example.myapp
  android_package: com.example.myapp
  ios_app_group: group.com.example.myapp.widgets
  deep_link_scheme: mosaic # optional, defaults to "mosaic"

widgets:
  - name: MyNewsWidget
    entry: lib/widgets/news.widget.dart
    android:
      min_sdk: 21
      sizes: [medium]
    ios:
      families: [systemMedium]
```

### 3. Create a Widget
In `lib/widgets/news.widget.dart`. Widget definition files import the **pure-Dart DSL** (`package:mosaic/dsl.dart`) so the build runner can execute them under `dart run`:

```dart
import 'package:mosaic/dsl.dart';

MosaicDefinition buildNewsWidget() {
  return MosaicDefinition(
    name: "NewsWidget",
    width: 4,
    height: 1,
    root: MContainer(
      background: MColor.hex("#FFFFFF"),
      radius: 16,
      child: MText(
        MBind("news_title"),
        style: const MTextStyle(color: MColor.hex("#0F172A"), bold: true),
      ),
    ),
  );
}
```

### 4. Build
Run the build command to generate native code:
```bash
dart run mosaic_cli build
```

Other CLI commands:
```bash
dart run mosaic_cli init            # create mosaic.yaml
dart run mosaic_cli add widget <Name>  # scaffold a new widget
dart run mosaic_cli build           # generate native code
dart run mosaic_cli doctor          # diagnose configuration
dart run mosaic_cli clean           # remove generated artifacts
```

### 5. Connect Your App
App code that uses the bridge imports the **full barrel** (`package:mosaic/mosaic.dart` = DSL + `MosaicBridge`):

```dart
import 'package:mosaic/mosaic.dart';

await MosaicBridge.setAppGroupId('group.com.example.myapp.widgets');
await MosaicBridge.saveString('news_title', 'Hello widgets!');
await MosaicBridge.refreshAll();
```

---

## 🎨 Theming (Adaptive Colors & Formatting)

Colors adapt to the OS light/dark appearance and can be pushed at runtime, and bound values can be formatted with the device locale. Layouts also auto-mirror in RTL locales.

```dart
import 'package:mosaic/dsl.dart';

MosaicDefinition buildCryptoWidget() {
  return MosaicDefinition(
    name: "CryptoWidget",
    width: 2,
    height: 2,
    root: MColumn([
      // Light/dark adaptive color (white in light mode, soft grey in dark).
      const MText(
        "BTC/USD",
        style: MTextStyle(color: MColor.hex("#FFFFFF", dark: "#E5E7EB"), bold: true),
      ),
      // Locale-aware currency formatting of a bound numeric value.
      MText(MBind("btc_price"), format: MFormat.currency),
      // Runtime-bound color: the app pushes an "accent" hex string.
      const MContainer(background: MColor.bind("accent"), child: MSpacer()),
    ]),
  );
}
```

## 🔒 Lock Screen (iOS Accessory Widgets)

Add an accessory family to a widget in `mosaic.yaml` to render it on the iOS 16+ Lock Screen. On accessory widgets the OS tints content (custom colors are largely ignored), and Mosaic emits `.widgetAccentable()`. Android skips accessory families (no general user Lock Screen widgets).

```yaml
widgets:
  - name: CryptoWidget
    entry: lib/widgets/crypto.widget.dart
    ios:
      families: [systemMedium, accessoryRectangular]  # also accessoryCircular, accessoryInline
```

## 🔴 Live Activities & Dynamic Island

Declare a Live Activity in a `*.live.dart` entry (pure-Dart DSL), register it in `mosaic.yaml`, then drive its lifecycle from your app.

```dart
// lib/live_activities/order_tracker.live.dart
import 'package:mosaic/dsl.dart';

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

```yaml
live_activities:
  - name: OrderTracker
    entry: lib/live_activities/order_tracker.live.dart
```

```dart
// App code drives the lifecycle (full barrel import).
import 'package:mosaic/mosaic.dart';

final id = await MosaicLiveActivities.start('OrderTracker', {
  'status': 'Preparing', 'progress': '0.1', 'eta': '25 min',
});
await MosaicLiveActivities.update(id!, {'status': 'On the way', 'progress': '0.6', 'eta': '8 min'},
    alert: const MActivityAlert(title: 'Order update', body: 'Your courier is nearby'));
await MosaicLiveActivities.end(id, policy: MEndPolicy.afterDefault);
```

See the [Live Activities Guide](DOCS/LIVE_ACTIVITIES.md) for the full walkthrough.

---

## 📱 Platform Setup

Follow these guides for platform-specific configuration:

- [Android Setup Guide](DOCS/ANDROID_SETUP.md)
- [iOS Setup Guide](DOCS/IOS_SETUP.md)

## 📖 DSL Documentation

See the [DSL Reference](DOCS/DSL_REFERENCE.md) for a full list of supported components and attributes, including adaptive colors, `MFormat`, accessory families, and the Live Activity components. For the focused Live Activity lifecycle guide, see the [Live Activities Guide](DOCS/LIVE_ACTIVITIES.md).
