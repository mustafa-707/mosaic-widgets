# Android Setup Guide for Antigravity Home Widgets

Android configuration is mostly automated by the `hw_cli`, but here are the key steps to ensure everything works correctly.

## 1. Automated Configuration

When you run `dart run hw_cli build`, the CLI performs the following:
1.  Generates `hw_*.xml` layouts in `res/layout`.
2.  Generates `hw_*_info.xml` configurations in `res/xml`.
3.  Generates Kotlin Provider classes in your package's `hw_generated` folder.
4.  **Auto-Registration**: Adds the necessary `<receiver>` tags to your `AndroidManifest.xml` automatically.

## 2. Syncing Assets

Images placed in `assets/widgets/` in your Flutter project are automatically copied to `android/app/src/main/res/drawable/`. 

-   **Important**: Filenames are automatically normalized (lower-cased, hyphens to underscores) to comply with Android resource naming rules.

## 3. Deep Linking

The CLI automatically adds a Deep Link intent filter to your `MainActivity` in `AndroidManifest.xml`. By default, it uses the `hwdemo://` scheme. You can handle these links in Flutter:

```dart
HomeWidgetBridge.onDeepLink.listen((url) {
  print('User tapped widget: $url');
});
```

## 4. Manual Verification

If widgets do not appear in the widget picker:
1.  Check `AndroidManifest.xml` to ensure the `<receiver>` tags were added correctly inside the `<application>` tag.
2.  Ensure your `android_package` in `home_widget.yaml` matches your `applicationId` in `app/build.gradle`.
