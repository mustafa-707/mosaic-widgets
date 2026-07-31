# Mosaic

**One DSL. Live native tiles. iOS + Android.**

A powerful, DSL-based framework for building native iOS and Android home widgets using Flutter-like syntax.

## 📦 Package Installation

To use this framework in any Flutter project, add the following to your `pubspec.yaml`:

```yaml
dependencies:
  mosaic_widgets:
    path: path/to/mosaic/platform/flutter
  mosaic_core:
    path: path/to/mosaic/platform/core

dev_dependencies:
  mosaic_cli:
    path: path/to/mosaic/platform/cli
```

> **Import rule:** widget definition files (`*.widget.dart`) import the pure-Dart DSL
> `package:mosaic_widgets/dsl.dart` so the build runner can execute them under `dart run`.
> Application code that talks to the bridge imports the full barrel
> `package:mosaic_widgets/mosaic_widgets.dart` (DSL + `MosaicBridge`).

## 🚀 Setup Guides

Detailed setup instructions for each platform:

1.  **[General Quickstart](README.md)**
2.  **[iOS WidgetKit Setup](DOCS/IOS_SETUP.md)**
3.  **[Android AppWidget Setup](DOCS/ANDROID_SETUP.md)**
4.  **[DSL Component Reference](DOCS/DSL_REFERENCE.md)**

## 🛠️ Typical Workflow

1.  **Define**: Create a `.widget.dart` file using the Mosaic DSL (`import 'package:mosaic_widgets/dsl.dart';`) that returns a `MosaicDefinition`.
2.  **Config**: Register the widget in `mosaic.yaml`.
3.  **Build**: Run `dart run mosaic_cli build`.
4.  **Connect**: Use `MosaicBridge` (`import 'package:mosaic_widgets/mosaic_widgets.dart';`) in your Flutter app to push data and refresh widgets.
5.  **Run**: Launch the app and add the widget to your home screen!

## 🔧 Troubleshooting

-   **iOS**: If data isn't showing, double-check your **App Group ID** in both targets and in `mosaic.yaml` (`ios_app_group`), and confirm you called `MosaicBridge.setAppGroupId(...)` before saving.
-   **Android**: If the widget isn't in the list, check `AndroidManifest.xml` for the generated `<receiver>` tags.
-   **Deep links / callbacks**: Make sure your native entry points are wired up — iOS `AppDelegate.swift` forwards opened URLs to the `onDeepLink` channel, and Android `MainActivity.kt` registers a BroadcastReceiver for `"<package>.MOSAIC_CALLBACK"` that forwards to the Flutter background callback. See the platform setup guides.
-   **Assets**: Ensure images are in `assets/widgets/` and follow Android naming rules (no hyphens, lowercase).
