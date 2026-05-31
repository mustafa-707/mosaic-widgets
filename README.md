# Mosaic

**One DSL. Live native tiles. iOS + Android.**

A powerful, DSL-based framework for building native iOS and Android home widgets using Flutter-like syntax.

## 🚀 Features

- **Single DSL for Both Platforms**: Write once in Dart, generate native Swift (iOS) and XML/Kotlin (Android).
- **Native Performance**: Widgets are rendered using standard platform components (`RemoteViews` on Android, `SwiftUI` on iOS).
- **Interactive**: Support for buttons, deep linking, and background refreshes.
- **Live Runtime Data Binding**: Bind text, image file paths, progress values, visibility, and timer targets at runtime with `MBind`. Push values from your app via `MosaicBridge` and `refresh`/`refreshAll`.
- **Rich UI**: Real linear gradients and borders, Stacks, Columns, Rows, Images (asset + file sources), and more.
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

## 📱 Platform Setup

Follow these guides for platform-specific configuration:

- [Android Setup Guide](DOCS/ANDROID_SETUP.md)
- [iOS Setup Guide](DOCS/IOS_SETUP.md)

## 📖 DSL Documentation

See the [DSL Reference](DOCS/DSL_REFERENCE.md) for a full list of supported components and attributes.
