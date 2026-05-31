# Antigravity Home Widgets (hw_flutter)

A powerful, DSL-based framework for building native iOS and Android home widgets using Flutter-like syntax.

## 🚀 Features

- **Single DSL for Both Platforms**: Write once in Dart, generate native Swift (iOS) and XML/Kotlin (Android).
- **Native Performance**: Widgets are rendered using standard platform components (`RemoteViews` on Android, `SwiftUI` on iOS).
- **Interactive**: Support for buttons, deep linking, and background refreshes.
- **Dynamic Data**: Simple shared preferences-based data binding system.
- **Rich UI**: Support for Gradients, Stacks, Columns, Rows, Images, and more.
- **Asset Sync**: Automatically syncs images from your Flutter project to native drawable/xcassets folders.

## 🏗️ Architecture

- `hw_core`: The Intermediate Representation (IR) and basic widget runner.
- `hw_flutter`: The Flutter DSL and the Bridge used to communicate with native code.
- `hw_android`: Generator for Android AppWidget code.
- `hw_ios`: Generator for iOS WidgetKit code.
- `hw_cli`: CLI tool to orchestrate code generation and automated configuration.

## 🛠️ Getting Started

### 1. Add Dependencies
Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  hw_flutter: ^1.0.0 # or path: ...
  
dev_dependencies:
  hw_cli: ^1.0.0 # or path: ...
```

### 2. Initialize
Create a `home_widget.yaml` in your project root:

```yaml
app:
  bundle_id: com.example.myapp
  android_package: com.example.myapp
  ios_app_group: group.com.example.myapp.widgets

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
In `lib/widgets/news.widget.dart`:

```dart
import 'package:hw_flutter/hw_dsl.dart';

HWDefinition buildNewsWidget() {
  return HWDefinition(
    name: "NewsWidget",
    width: 4, height: 1,
    root: HWContainer(
      background: HWColor.hex("#FFFFFF"),
      child: HWText(HWBind("news_title")),
    ),
  );
}
```

### 4. Build
Run the build command to generate native code:
```bash
dart run hw_cli build
```

---

## 📱 Platform Setup

Follow these guides for platform-specific configuration:

- [Android Setup Guide](DOCS/ANDROID_SETUP.md)
- [iOS Setup Guide](DOCS/IOS_SETUP.md)

## 📖 DSL Documentation

See the [DSL Reference](DOCS/DSL_REFERENCE.md) for a full list of supported components and attributes.
