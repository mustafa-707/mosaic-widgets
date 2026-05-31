# Antigravity Home Widgets (hw_flutter)

A powerful, DSL-based framework for building native iOS and Android home widgets using Flutter-like syntax.

## 📦 Package Installation

To use this framework in any Flutter project, add the following to your `pubspec.yaml`:

```yaml
dependencies:
  hw_flutter:
    path: path/to/antigravity/hw_flutter
  hw_core:
    path: path/to/antigravity/hw_core

dev_dependencies:
  hw_cli:
    path: path/to/antigravity/hw_cli
```

## 🚀 Setup Guides

Detailed setup instructions for each platform:

1.  **[General Quickstart](README.md)**
2.  **[iOS WidgetKit Setup](DOCS/IOS_SETUP.md)**
3.  **[Android AppWidget Setup](DOCS/ANDROID_SETUP.md)**
4.  **[DSL Component Reference](DOCS/DSL_REFERENCE.md)**

## 🛠️ Typical Workflow

1.  **Define**: Create a `.widget.dart` file using the `HWDSL`.
2.  **Config**: Register the widget in `home_widget.yaml`.
3.  **Build**: Run `dart run hw_cli build`.
4.  **Connect**: Use `HomeWidgetBridge` in your Flutter app to send data.
5.  **Run**: Launch the app and add the widget to your home screen!

## 🔧 Troubleshooting

-   **iOS**: If data isn't showing, double-check your **App Group ID** in both targets and `home_widget.yaml`.
-   **Android**: If the widget isn't in the list, check `AndroidManifest.xml` for the generated `<receiver>` tags.
-   **Assets**: Ensure images are in `assets/widgets/` and follow Android naming rules (no hyphens, lowercase).
