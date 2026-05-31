// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.example.demo_app.R

class NewsWidgetProvider : AppWidgetProvider() {
    private val mosaicCallbackAction = "com.example.demo_app.MOSAIC_CALLBACK"

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
        if (intent.action == mosaicCallbackAction) {
            val callbackName = intent.getStringExtra("callbackName")
            if (callbackName == "refresh_all") {
                HomeWidgetBridgeHelper.refreshAll(context)
            }
            // Future: Notify Flutter background engine here
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val intent = android.content.Intent(context, NewsWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val pendingIntent = android.app.PendingIntent.getBroadcast(context, 0, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        alarmManager.setRepeating(android.app.AlarmManager.RTC, System.currentTimeMillis(), 900000, pendingIntent)
        
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, R.layout.hw_newswidget)
        
        views.setTextViewText(R.id.hw_text_news_title, MosaicData.resolveString(context, "news_title"))
                val target0 = 1780241181111L
        val offset0 = target0 - System.currentTimeMillis()
        views.setChronometer(R.id.hw_timer_0, android.os.SystemClock.elapsedRealtime() + offset0, null, true)
      
        
        
                val intent0 = android.content.Intent(context, NewsWidgetProvider::class.java).apply {
            action = mosaicCallbackAction
            putExtra("callbackName", "refresh_news")
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val pendingIntent0 = android.app.PendingIntent.getBroadcast(context, appWidgetId * 100 + 0, intent0, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.hw_button_main, pendingIntent0)
        

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
