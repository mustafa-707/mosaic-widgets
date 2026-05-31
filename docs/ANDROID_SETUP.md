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

## 4. Deep Linking

The CLI automatically adds a deep-link intent filter to your `MainActivity` in `AndroidManifest.xml`. The scheme comes from `deep_link_scheme` under `app:` in `mosaic.yaml` and **defaults to `mosaic`** (so links look like `mosaic://...`). Handle these links in Flutter:

```dart
import 'package:mosaic/mosaic.dart';

MosaicBridge.onDeepLink.listen((url) {
  print('User tapped widget: $url');
});
```

## 5. Manual Verification

If widgets do not appear in the widget picker:
1.  Check `AndroidManifest.xml` to ensure the `<receiver>` tags were added correctly inside the `<application>` tag.
2.  Ensure your `android_package` in `mosaic.yaml` matches your `applicationId` in `app/build.gradle`.
