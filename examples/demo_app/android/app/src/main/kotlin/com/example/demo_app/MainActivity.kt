package com.example.demo_app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "mosaic_bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "saveString" -> {
                    val key = call.argument<String>("key")
                    val value = call.argument<String>("value")
                    if (key != null && value != null) {
                        saveToSharedPrefs(key, value)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Key or value is null", null)
                    }
                }
                "saveBool" -> {
                    val key = call.argument<String>("key")
                    val value = call.argument<Boolean>("value")
                    if (key != null && value != null) {
                        saveBoolToSharedPrefs(key, value)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Key or value is null", null)
                    }
                }
                "refreshAll" -> {
                    com.example.demo_app.mosaic_generated.HomeWidgetBridgeHelper.refreshAll(this)
                    result.success(null)
                }
                "refresh" -> {
                    val widgetName = call.argument<String>("widgetName")
                    if (widgetName != null) {
                        com.example.demo_app.mosaic_generated.HomeWidgetBridgeHelper.refresh(this, widgetName)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Widget name is null", null)
                    }
                }
                "startActivity" -> {
                    val type = call.argument<String>("activityType")
                    @Suppress("UNCHECKED_CAST")
                    val state = (call.argument<Map<String, Any?>>("state") ?: emptyMap())
                        .mapValues { it.value?.toString() ?: "" }
                    if (type != null) {
                        val id = com.example.demo_app.mosaic_generated.MosaicLiveActivityManager.start(this, type, state)
                        result.success(id)
                    } else {
                        result.error("INVALID_ARGUMENTS", "activityType is null", null)
                    }
                }
                "updateActivity" -> {
                    val id = call.argument<String>("id")
                    @Suppress("UNCHECKED_CAST")
                    val state = (call.argument<Map<String, Any?>>("state") ?: emptyMap())
                        .mapValues { it.value?.toString() ?: "" }
                    @Suppress("UNCHECKED_CAST")
                    val alert = call.argument<Map<String, Any?>>("alert")
                    val alertTitle = alert?.get("title")?.toString()
                    val alertBody = alert?.get("body")?.toString()
                    if (id != null) {
                        com.example.demo_app.mosaic_generated.MosaicLiveActivityManager.update(this, id, state, alertTitle, alertBody)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "id is null", null)
                    }
                }
                "endActivity" -> {
                    val id = call.argument<String>("id")
                    if (id != null) {
                        com.example.demo_app.mosaic_generated.MosaicLiveActivityManager.end(this, id)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "id is null", null)
                    }
                }
                "activitiesEnabled" -> {
                    result.success(com.example.demo_app.mosaic_generated.MosaicLiveActivityManager.enabled(this))
                }
                "activeActivities" -> {
                    result.success(com.example.demo_app.mosaic_generated.MosaicLiveActivityManager.active(this))
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Register receiver to forward widget callbacks to Flutter
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

        // Handle initial intent
        handleIntent(intent, channel)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        flutterEngine?.let {
            handleIntent(intent, MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL))
        }
    }

    private fun handleIntent(intent: Intent, channel: MethodChannel) {
        if (Intent.ACTION_VIEW == intent.action) {
            val data = intent.dataString
            if (data != null) {
                channel.invokeMethod("onDeepLink", mapOf("url" to data))
            }
        }
    }

    private fun saveToSharedPrefs(key: String, value: String) {
        val prefs = getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        prefs.edit().putString(key, value).apply()
    }

    private fun saveBoolToSharedPrefs(key: String, value: Boolean) {
        val prefs = getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        prefs.edit().putBoolean(key, value).apply()
    }


}
