# Android Setup Guide for Mosaic

Android configuration is mostly automated by the `mosaic_cli`, but here are the key steps to ensure everything works correctly.

## 1. Automated Configuration

When you run `dart run mosaic_widgets:mosaic build`, the CLI performs the following:
1.  Generates `mosaic_*.xml` layouts in `res/layout`.
2.  Generates `mosaic_*_info.xml` configurations in `res/xml`.
3.  Generates Kotlin Provider classes under your package's `mosaic_generated` segment (e.g. `com.example.myapp.mosaic_generated`).
4.  **Auto-Registration**: Adds the necessary `<receiver>` tags to your `AndroidManifest.xml` automatically.

## 2. Syncing Assets

> Removing or renaming a widget in `mosaic.yaml` makes its generated provider,
> layout, and info XML unreferenced. `build` deletes those orphans and logs each
> one; only files carrying the `MOSAIC-GENERATED` sentinel are eligible, so
> anything you wrote by hand stays.


Images placed in `assets/widgets/` in your Flutter project are automatically copied to `android/app/src/main/res/drawable/`.

-   **Important**: Filenames are automatically normalized (lower-cased, hyphens to underscores) to comply with Android resource naming rules.

## 3. Register the Mosaic Plugin

`dart run mosaic_widgets:mosaic build` generates `MosaicPlugin.kt` into your app's
`mosaic_generated` package. It contains the whole host side of the bridge: the
`mosaic_bridge` method channel (`saveString`, `saveBool`, `refresh`,
`refreshAll`, the Live Activity lifecycle), the receiver that forwards widget
button callbacks to Dart, and deep-link handling.

Two overrides in `MainActivity.kt` — there is no channel code to copy:

```kotlin
package com.example.your_app

import android.content.Intent
import com.example.your_app.mosaic_generated.MosaicPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val mosaic = MosaicPlugin()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mosaic.register(this, flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        mosaic.handleIntent(intent)
    }
}
```

`onNewIntent` is the second override because a warm app receives widget taps
there; without it a tap on a running app is silently dropped. `register` handles
the launch intent itself, so a cold start from a widget keeps its deep link.

The reference is `examples/demo_app/.../MainActivity.kt` — 24 lines, all of it
above.

> Earlier versions of this guide had you write the channel by hand. If you still
> have that code, delete it and call `MosaicPlugin` instead: the generated
> version also registers the callback receiver on the application context behind
> a guard (the hand-written one leaked a receiver on every activity recreation)
> and preserves `saveBool` as a real boolean, which `MosaicData.resolveBool`
> needs.


## 4. Adaptive Colors, RTL & Locale

- **Dark mode**: adaptive colors (`MColor.hex(..., dark: ...)`) are generated as a `res/values/mosaic_colors.xml` + `res/values-night/mosaic_colors.xml` pair and referenced by `@color/mosaic_<hash>`. Android applies the night variant automatically based on the system theme. (`dart run mosaic_widgets:mosaic clean` removes these generated `values*/mosaic_colors.xml` files.)
- **Runtime-bound colors** (`MColor.bind(...)`) are resolved at update time from the data store and applied to the `RemoteViews`.
- **RemoteViews size limit**: a widget update crosses a Binder transaction with a hard size cap. Exceed it and the launcher drops the **whole** update — the widget shows only its static layout, every bound value vanishes at once, and nothing is logged. Mosaic keeps every bitmap it sends inside that budget for you: network images are decoded downsampled (bounds first, power-of-two `inSampleSize`, longest side ≤ 320px), and `MSparkline`/`MBarChart` bitmaps are scaled from the widget's dp bounds but clamped to ~60k pixels with the aspect ratio preserved. `MImage` costs nothing here — asset and file images are passed as a URI the launcher resolves itself.
- **Cross-platform layout parity**: an `MRow` sizes to its tallest child but centres vertically inside a taller parent (a container, a button, a stack), matching SwiftUI's behaviour when an `HStack` sits in a filled frame. A bound key drives every view it appears in — a battery level rendered as both `MText` and `MProgressBar` updates both. Both were Android-only divergences from iOS.
- **RTL**: layouts use `start`/`end` gravity and padding so they mirror automatically. Ensure your manifest's `<application>` has `android:supportsRtl="true"` — `doctor` warns when it is `false` **or absent**, since Android ignores `start`/`end` gravity without the opt-in.
- **Formatting**: `MFormat` on bound `MText` values is applied with the device locale via `NumberFormat` / `DateFormat` / `DateUtils` when the provider updates.
- **Translated text**: keys declared under `strings:` in `mosaic.yaml` and used as `MText(const MLocalized('key'))` are generated into `res/values/mosaic_localized.xml` (the first-listed locale, used as fallback) plus one `res/values-<locale>/mosaic_localized.xml` per additional locale, and referenced from the layout as `@string/mosaic_s_<key>`. Android resolves the right table from the device language with no code on your side — this is why widget text cannot use `intl`/`AppLocalizations`, which need the Flutter engine the widget process does not have. Values are XML-escaped, and `build` fails if a key is used but missing from the default locale — otherwise the only symptom is a runtime resource-resolution failure on devices in an unlisted language. (`dart run mosaic_widgets:mosaic clean` removes these generated files.)

## 5. Control Widgets (Quick Settings Tiles)

Control widgets appear in the Android Quick Settings panel. Users add them manually from the Quick Settings edit screen.

### What `dart run mosaic_widgets:mosaic build` generates

For each entry under `controls:` in `mosaic.yaml` the CLI:

1. Emits `<Name>TileService.kt` under your `mosaic_generated` package — a `TileService` subclass that reads/writes the `widget_data` SharedPreferences store and broadcasts `MOSAIC_CALLBACK` intents (same path as widget button callbacks).
2. **Auto-inserts** a `<service>` declaration into `AndroidManifest.xml` with `android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"` and the `QS_TILE` intent-filter. No manual manifest editing is needed.

No `MainActivity.kt` changes are required for controls — callbacks arrive via the existing `MOSAIC_CALLBACK` broadcast receiver already set up for widget buttons (Section 3).

### Defining a control

```dart
// lib/platform/controls/torch.control.dart
import 'package:mosaic_widgets/dsl.dart';

MControl buildTorch() => const MControl(
  name: 'Torch',
  kind: MControlKind.toggle,
  label: 'Flashlight',
  androidIcon: 'ic_torch',
  valueKey: 'torch_on',
  action: MActionCallback('toggle_torch'),
);
```

```yaml
# mosaic.yaml
controls:
  - name: Torch
    entry: lib/platform/controls/torch.control.dart
```

QS tiles require API 24+. The generated `TileService` reads the on/off state from `widget_data` SharedPreferences under `valueKey` and updates `STATE_ACTIVE` / `STATE_INACTIVE` accordingly.

## 6. Live Activities (Ongoing Notification Fallback)

Android has no true Live Activity, so Mosaic maps a `MosaicLiveActivity` to a promoted ongoing notification. The Dynamic Island is **not applicable** on Android (those regions are ignored).

**Android 16 / API 36+ (Live Updates):** on API 36+ the generated `MosaicLiveActivityManager` builds the notification with `Notification.ProgressStyle` + the promoted-ongoing flag, which Android 16 surfaces as a "Live Update" in the status bar chip and on the lock screen. The `progress` key in the activity data map (integer string, 0–100) drives the progress bar; if absent, an indeterminate style is used.

**Pre-API 36 fallback:** a custom-`RemoteViews` ongoing notification is built from the activity's `lockScreen` tree (same as before).

- Requires the `POST_NOTIFICATIONS` runtime permission on **API 33+**; your app should request it before starting an activity.
- `MainActivity.kt` routes the lifecycle method-channel calls (`startActivity`, `updateActivity`, `endActivity`, `activitiesEnabled`, `activeActivities`) to the generated `MosaicLiveActivityManager`:

```kotlin
"startActivity" -> {
    val type = call.argument<String>("activityType")
    val state = (call.argument<Map<String, Any?>>("state") ?: emptyMap())
        .mapValues { it.value?.toString() ?: "" }
    val id = com.example.demo_app.mosaic_generated.MosaicLiveActivityManager.start(this, type!!, state)
    result.success(id)
}
"updateActivity" -> {
    val id = call.argument<String>("id")
    val state = (call.argument<Map<String, Any?>>("state") ?: emptyMap())
        .mapValues { it.value?.toString() ?: "" }
    val alert = call.argument<Map<String, Any?>>("alert")
    com.example.demo_app.mosaic_generated.MosaicLiveActivityManager.update(
        this, id!!, state, alert?.get("title")?.toString(), alert?.get("body")?.toString())
    result.success(null)
}
"endActivity" -> {
    val id = call.argument<String>("id")
    com.example.demo_app.mosaic_generated.MosaicLiveActivityManager.end(this, id!!)
    result.success(null)
}
"activitiesEnabled" -> result.success(
    com.example.demo_app.mosaic_generated.MosaicLiveActivityManager.enabled(this))
"activeActivities" -> result.success(
    com.example.demo_app.mosaic_generated.MosaicLiveActivityManager.active(this))
```

See the [Live Activities Guide](LIVE_ACTIVITIES.md) for the full walkthrough.

## 7. Prompting the User to Add a Widget

`AppWidgetManager.requestPinAppWidget` lets your app open the launcher's
"add widget" dialog directly, which matters because most users never find the
widget picker themselves. The generated `MosaicPlugin` exposes it:

```dart
if (await MosaicBridge.canRequestPinWidget()) {
  await MosaicBridge.requestPinWidget('News');   // the mosaic.yaml name
}
```

- Requires **API 26+** and a launcher that reports `isRequestPinAppWidgetSupported`. Both are checked for you; an unsupported launcher returns false rather than throwing, so you can fall back to instructions.
- The plugin maps the mosaic.yaml widget name to its generated provider class, so you never reference Kotlin class names from Dart. An unknown name returns an `UNKNOWN_WIDGET` error listing the valid ones — a typo should not be indistinguishable from an unsupported launcher.
- The result reports only that the dialog appeared. Android does not tell the app whether the user accepted; watch for the widget's first update if you need to know.

## 8. Deep Linking

> `build` injects the `<intent-filter>` for `app.deep_link_scheme` into `MainActivity` and **fails** if any `MLaunchUrlAction` uses a different custom scheme — otherwise the only symptom is a tap that does nothing, with no error in logcat. Re-running after a scheme change replaces the generated filter instead of leaving the old scheme registered.


The CLI automatically adds a deep-link intent filter to your `MainActivity` in `AndroidManifest.xml`. The scheme comes from `deep_link_scheme` under `app:` in `mosaic.yaml` and **defaults to `mosaic`** (so links look like `mosaic://...`). Handle these links in Flutter:

```dart
import 'package:mosaic_widgets/mosaic_widgets.dart';

MosaicBridge.onDeepLink.listen((url) {
  print('User tapped widget: $url');
});
```

## 9. Manual Verification

If widgets do not appear in the widget picker:
1.  Check `AndroidManifest.xml` to ensure the `<receiver>` tags were added correctly inside the `<application>` tag.
2.  Ensure your `android_package` in `mosaic.yaml` matches your `applicationId` in `app/build.gradle`.
