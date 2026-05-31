package com.example.demo_app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "hw_flutter_bridge"

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
                    com.example.demo_app.hw_generated.HomeWidgetBridgeHelper.refreshAll(this)
                    result.success(null)
                }
                "refresh" -> {
                    val widgetName = call.argument<String>("widgetName")
                    if (widgetName != null) {
                        com.example.demo_app.hw_generated.HomeWidgetBridgeHelper.refresh(this, widgetName)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Widget name is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
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
