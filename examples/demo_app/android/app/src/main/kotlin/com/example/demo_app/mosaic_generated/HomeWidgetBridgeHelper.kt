// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.content.Context

object HomeWidgetBridgeHelper {
    fun refreshAll(context: Context) {
                context.sendBroadcast(android.content.Intent(context, ProfileVPProvider::class.java).apply {
            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = android.appwidget.AppWidgetManager.getInstance(context)
                .getAppWidgetIds(android.content.ComponentName(context, ProfileVPProvider::class.java))
            putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        })
        context.sendBroadcast(android.content.Intent(context, NewsWidgetProvider::class.java).apply {
            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = android.appwidget.AppWidgetManager.getInstance(context)
                .getAppWidgetIds(android.content.ComponentName(context, NewsWidgetProvider::class.java))
            putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        })
        context.sendBroadcast(android.content.Intent(context, CryptoWidgetProvider::class.java).apply {
            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = android.appwidget.AppWidgetManager.getInstance(context)
                .getAppWidgetIds(android.content.ComponentName(context, CryptoWidgetProvider::class.java))
            putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        })
        context.sendBroadcast(android.content.Intent(context, WeatherProvider::class.java).apply {
            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = android.appwidget.AppWidgetManager.getInstance(context)
                .getAppWidgetIds(android.content.ComponentName(context, WeatherProvider::class.java))
            putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        })
    }

    fun refresh(context: Context, widgetName: String) {
        when (widgetName) {
                        "ProfileVP" -> {
                context.sendBroadcast(android.content.Intent(context, ProfileVPProvider::class.java).apply {
                    action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val ids = android.appwidget.AppWidgetManager.getInstance(context)
                        .getAppWidgetIds(android.content.ComponentName(context, ProfileVPProvider::class.java))
                    putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                })
            }
            "NewsWidget" -> {
                context.sendBroadcast(android.content.Intent(context, NewsWidgetProvider::class.java).apply {
                    action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val ids = android.appwidget.AppWidgetManager.getInstance(context)
                        .getAppWidgetIds(android.content.ComponentName(context, NewsWidgetProvider::class.java))
                    putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                })
            }
            "CryptoWidget" -> {
                context.sendBroadcast(android.content.Intent(context, CryptoWidgetProvider::class.java).apply {
                    action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val ids = android.appwidget.AppWidgetManager.getInstance(context)
                        .getAppWidgetIds(android.content.ComponentName(context, CryptoWidgetProvider::class.java))
                    putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                })
            }
            "Weather" -> {
                context.sendBroadcast(android.content.Intent(context, WeatherProvider::class.java).apply {
                    action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val ids = android.appwidget.AppWidgetManager.getInstance(context)
                        .getAppWidgetIds(android.content.ComponentName(context, WeatherProvider::class.java))
                    putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                })
            }
        }
    }
}
