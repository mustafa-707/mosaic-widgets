package com.example.demo_app.hw_generated

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.example.demo_app.R

class CryptoWidgetProvider : AppWidgetProvider() {
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
        val views = RemoteViews(context.packageName, R.layout.hw_cryptowidget)
        
        views.setTextViewText(R.id.hw_text_btc_price, prefs.getString("btc_price", null) ?: "")
        views.setTextViewText(R.id.hw_text_btc_change, prefs.getString("btc_change", null) ?: "")
                val target0 = 1770120005123L
        val offset0 = target0 - System.currentTimeMillis()
        views.setChronometer(R.id.hw_timer_0, android.os.SystemClock.elapsedRealtime() + offset0, null, true)
      
        
                val intent0 = android.content.Intent(context, CryptoWidgetProvider::class.java).apply {
            action = "com.example.hw_flutter.ACTION_CALLBACK"
            putExtra("callbackName", "refresh_all")
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val pendingIntent0 = android.app.PendingIntent.getBroadcast(context, 0, intent0, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.hw_button_main, pendingIntent0)
        

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
