// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Host-app side of the Mosaic bridge.
///
/// Wire it up with two overrides:
///
///     class MainActivity : FlutterActivity() {
///         private val mosaic = MosaicPlugin()
///
///         override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
///             super.configureFlutterEngine(flutterEngine)
///             mosaic.register(this, flutterEngine)
///         }
///
///         override fun onNewIntent(intent: Intent) {
///             super.onNewIntent(intent)
///             setIntent(intent)
///             mosaic.handleIntent(intent)
///         }
///     }
class MosaicPlugin {
    private var channel: MethodChannel? = null

    fun register(activity: FlutterActivity, engine: FlutterEngine) {
        val context = activity.applicationContext
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "mosaic_bridge")
        this.channel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "saveString", "saveBool" -> {
                    val key = call.argument<String>("key")
                    when (val value = call.argument<Any>("value")) {
                        null -> result.error("INVALID_ARGUMENTS", "key and value are required", null)
                        else -> {
                            if (key == null) {
                                result.error("INVALID_ARGUMENTS", "key is required", null)
                            } else {
                                val prefs = context.getSharedPreferences(
                                    "widget_data", Context.MODE_PRIVATE)
                                val editor = prefs.edit()
                                if (value is Boolean) {
                                    editor.putBoolean(key, value)
                                } else {
                                    editor.putString(key, value.toString())
                                }
                                editor.apply()
                                result.success(null)
                            }
                        }
                    }
                }
                "refreshAll" -> {
                    HomeWidgetBridgeHelper.refreshAll(context)
                    result.success(null)
                }
                "refresh" -> {
                    val widgetName = call.argument<String>("widgetName")
                    if (widgetName == null) {
                        result.error("INVALID_ARGUMENTS", "widgetName is required", null)
                    } else {
                        HomeWidgetBridgeHelper.refresh(context, widgetName)
                        result.success(null)
                    }
                }
                // Android has no WidgetKit-style widget push. Answering empty
                // keeps MosaicBridge.widgetPushTokens() honest here.
                "widgetPushTokens" -> result.success(emptyMap<String, String>())
                // Asks the launcher to show its "add widget" dialog. Only some
                // launchers implement it, hence the capability check.
                "canRequestPinWidget" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        AppWidgetManager.getInstance(context).isRequestPinAppWidgetSupported
                )
                "requestPinWidget" -> {
                    val widgetName = call.argument<String>("widgetName")
                    val provider = widgetName?.let { PIN_PROVIDERS[it] }
                    when {
                        widgetName == null ->
                            result.error("INVALID_ARGUMENTS", "widgetName is required", null)
                        provider == null ->
                            result.error(
                                "UNKNOWN_WIDGET",
                                "No widget named \"$widgetName\". Known: ${PIN_PROVIDERS.keys.joinToString(", ")}",
                                null
                            )
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ->
                            result.success(false)
                        else -> {
                            val manager = AppWidgetManager.getInstance(context)
                            if (!manager.isRequestPinAppWidgetSupported) {
                                // A launcher that does not support pinning is a
                                // normal outcome, not an error — the caller
                                // shows manual instructions instead.
                                result.success(false)
                            } else {
                                result.success(
                                    manager.requestPinAppWidget(
                                        ComponentName(context, provider), null, null
                                    )
                                )
                            }
                        }
                    }
                }
                "startActivity" -> {
                    val type = call.argument<String>("activityType")
                    if (type == null) {
                        result.error("INVALID_ARGUMENTS", "activityType is required", null)
                    } else {
                        result.success(
                            MosaicLiveActivityManager.start(context, type, stringMap(call, "state"))
                        )
                    }
                }
                "updateActivity" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("INVALID_ARGUMENTS", "id is required", null)
                    } else {
                        val alert = call.argument<Map<String, Any?>>("alert")
                        MosaicLiveActivityManager.update(
                            context, id, stringMap(call, "state"),
                            alert?.get("title")?.toString(),
                            alert?.get("body")?.toString()
                        )
                        result.success(null)
                    }
                }
                "endActivity" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("INVALID_ARGUMENTS", "id is required", null)
                    } else {
                        MosaicLiveActivityManager.end(context, id)
                        result.success(null)
                    }
                }
                "activitiesEnabled" -> result.success(MosaicLiveActivityManager.enabled(context))
                "activeActivities" -> result.success(MosaicLiveActivityManager.active(context))

                else -> result.notImplemented()
            }
        }

        registerCallbackReceiver(activity)
        // The launch intent is already set when the engine is configured, so a
        // cold start from a widget tap would otherwise lose its deep link.
        handleIntent(activity.intent)
    }

    /// Forwards a widget deep link to Dart. Call from `onNewIntent` so taps
    /// reach a warm app too.
    fun handleIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val url = intent.dataString ?: return
        channel?.invokeMethod("onDeepLink", mapOf("url" to url))
    }

    private fun registerCallbackReceiver(activity: FlutterActivity) {
        if (receiverRegistered) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                val name = intent.getStringExtra("callbackName") ?: return
                channel?.invokeMethod("backgroundCallback", mapOf("callbackName" to name))
            }
        }
        val filter = IntentFilter("com.example.demo_app.MOSAIC_CALLBACK")
        // Registered on the application context and guarded, so an activity
        // recreation neither double-registers nor leaks a receiver.
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            activity.applicationContext.registerReceiver(
                receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            activity.applicationContext.registerReceiver(receiver, filter)
        }
        receiverRegistered = true
    }

    /// Widget state arrives as strings, so coerce whatever Dart sent.
    private fun stringMap(call: MethodCall, name: String): Map<String, String> =
        (call.argument<Map<String, Any?>>(name) ?: emptyMap())
            .mapValues { it.value?.toString() ?: "" }

    private companion object {
        var receiverRegistered = false

        /// Widget name (as written in mosaic.yaml) to its generated provider.
        val PIN_PROVIDERS: Map<String, Class<*>> = mapOf(
            "ProfileVP" to com.example.demo_app.mosaic_generated.ProfileVPProvider::class.java,
            "NewsWidget" to com.example.demo_app.mosaic_generated.NewsWidgetProvider::class.java,
            "CryptoWidget" to com.example.demo_app.mosaic_generated.CryptoWidgetProvider::class.java,
            "Weather" to com.example.demo_app.mosaic_generated.WeatherProvider::class.java,
            "SearchBar" to com.example.demo_app.mosaic_generated.SearchBarProvider::class.java,
            "Tasks" to com.example.demo_app.mosaic_generated.TasksProvider::class.java,
            "Flashlight" to com.example.demo_app.mosaic_generated.FlashlightProvider::class.java,
            "Memory" to com.example.demo_app.mosaic_generated.MemoryProvider::class.java
        )
    }
}
