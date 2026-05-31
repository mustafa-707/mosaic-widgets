package com.example.demo_app.hw_generated

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.example.demo_app.R

class ProfileVPProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
        if (intent.action == "com.example.hw_flutter.ACTION_CALLBACK") {
            val callbackName = intent.getStringExtra("callbackName")
            if (callbackName == "refresh_all") {
                HomeWidgetBridgeHelper.refreshAll(context)
            }
            // Future: Notify Flutter background engine here
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, R.layout.hw_profilevp)
        
        views.setTextViewText(R.id.hw_text_system_status, prefs.getString("system_status", null) ?: "")
        views.setTextViewText(R.id.hw_text_battery_level, prefs.getString("battery_level", null) ?: "")
        views.setProgressBar(R.id.hw_progress_battery_progress, 100, (prefs.getString("battery_progress", "0")?.toDoubleOrNull() ?: 0.0).toInt(), false)
        views.setTextViewText(R.id.hw_text_memory_usage, prefs.getString("memory_usage", null) ?: "")
        views.setProgressBar(R.id.hw_progress_memory_progress, 100, (prefs.getString("memory_progress", "0")?.toDoubleOrNull() ?: 0.0).toInt(), false)
        
        
                val intent0 = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse("hwdemo://profile/details"))
        val pendingIntent0 = android.app.PendingIntent.getActivity(context, 0, intent0, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.hw_button_main, pendingIntent0)
        
                val intent1 = android.content.Intent(context, ProfileVPProvider::class.java).apply {
            action = "com.example.hw_flutter.ACTION_CALLBACK"
            putExtra("callbackName", "refresh_all")
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val pendingIntent1 = android.app.PendingIntent.getBroadcast(context, 1, intent1, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.hw_button_1, pendingIntent1)
        

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
