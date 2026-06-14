# Android Setup Guide for Mosaic

Android configuration is mostly automated by the `mosaic_cli`, but here are the key steps to ensure everything works correctly.

## 1. Automated Configuration

When you run `dart run mosaic_cli build`, the CLI performs the following:
1.  Generates `mosaic_*.xml` layouts in `res/layout`.
2.  Generates `mosaic_*_info.xml` configurations in `res/xml`.
3.  Generates Kotlin Provider classes under your package's `mosaic_generated` segment (e.g. `com.example.myapp.mosaic_generated`).
4.  **Auto-Registration**: Adds the necessary `<receiver>` tags to your `AndroidManifest.xml` automatically.

## 2. Syncing Assets

Images placed in `assets/widgets/` in your Flutter project are automatically copied to `android/app/src/main/res/drawable/`.

-   **Important**: Filenames are automatically normalized (lower-cased, hyphens to underscores) to comply with Android resource naming rules.

## 3. MainActivity: Bridge, Callbacks, and Deep Links

Mosaic talks to native Android over the `mosaic_bridge` method channel. Your `MainActivity.kt` is the reference wiring — it must:

1.  Set up the `mosaic_bridge` `MethodChannel` and handle `saveString`, `saveBool`, `refresh`, and `refreshAll`. The `refresh` / `refreshAll` calls delegate to the generated `mosaic_generated.HomeWidgetBridgeHelper`.
2.  Register a `BroadcastReceiver` for the `"<package>.MOSAIC_CALLBACK"` action that forwards widget button callbacks to the Flutter `backgroundCallback`.
3.  Forward incoming deep-link intents (`Intent.ACTION_VIEW`) to the Flutter `onDeepLink` channel.

The current reference implementation lives at
`examples/demo_app/android/app/src/main/kotlin/com/example/demo_app/MainActivity.kt`.
The key pieces look like this:

```kotlin
class MainActivity : FlutterActivity() {
    private val CHANNEL = "mosaic_bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "saveString" -> { /* persist to SharedPreferences */ }
                "saveBool"   -> { /* persist to SharedPreferences */ }
                "refreshAll" -> {
                    com.example.demo_app.mosaic_generated.HomeWidgetBridgeHelper.refreshAll(this)
                    result.success(null)
                }
                "refresh" -> {
                    val widgetName = call.argument<String>("widgetName")
                    com.example.demo_app.mosaic_generated.HomeWidgetBridgeHelper.refresh(this, widgetName!!)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Forward widget button callbacks to Flutter
        val callbackReceiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                val name = intent.getStringExtra("callbackName")
                if (name != null) {
                    channel.invokeMethod("backgroundCallback", mapOf("callbackName" to name))
                }
            }
        }
        val filter = android.content.IntentFilter("$packageName.MOSAIC_CALLBACK")
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            registerReceiver(callbackReceiver, filter, android.content.Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(callbackReceiver, filter)
        }

        handleIntent(intent, channel)
    }

    private fun handleIntent(intent: Intent, channel: MethodChannel) {
        if (Intent.ACTION_VIEW == intent.action) {
            intent.dataString?.let { channel.invokeMethod("onDeepLink", mapOf("url" to it)) }
        }
    }
}
```

Copy this wiring into your own `MainActivity.kt`, adjusting the `mosaic_generated` package prefix to match your `android_package`.

## 4. Adaptive Colors, RTL & Locale

- **Dark mode**: adaptive colors (`MColor.hex(..., dark: ...)`) are generated as a `res/values/mosaic_colors.xml` + `res/values-night/mosaic_colors.xml` pair and referenced by `@color/mosaic_<hash>`. Android applies the night variant automatically based on the system theme. (`dart run mosaic_cli clean` removes these generated `values*/mosaic_colors.xml` files.)
- **Runtime-bound colors** (`MColor.bind(...)`) are resolved at update time from the data store and applied to the `RemoteViews`.
- **RTL**: layouts use `start`/`end` gravity and padding so they mirror automatically. Ensure your manifest's `<application>` has `android:supportsRtl="true"` (the CLI doctor warns if it is `false`).
- **Formatting**: `MFormat` on bound `MText` values is applied with the device locale via `NumberFormat` / `DateFormat` / `DateUtils` when the provider updates.

## 5. Control Widgets (Quick Settings Tiles)

Control widgets appear in the Android Quick Settings panel. Users add them manually from the Quick Settings edit screen.

### What `mosaic_cli build` generates

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

## 7. Deep Linking

The CLI automatically adds a deep-link intent filter to your `MainActivity` in `AndroidManifest.xml`. The scheme comes from `deep_link_scheme` under `app:` in `mosaic.yaml` and **defaults to `mosaic`** (so links look like `mosaic://...`). Handle these links in Flutter:

```dart
import 'package:mosaic_widgets/mosaic_widgets.dart';

MosaicBridge.onDeepLink.listen((url) {
  print('User tapped widget: $url');
});
```

## 8. Manual Verification

If widgets do not appear in the widget picker:
1.  Check `AndroidManifest.xml` to ensure the `<receiver>` tags were added correctly inside the `<application>` tag.
2.  Ensure your `android_package` in `mosaic.yaml` matches your `applicationId` in `app/build.gradle`.
