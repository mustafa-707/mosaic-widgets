// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.example.demo_app.R

class TasksProvider : AppWidgetProvider() {
    private val mosaicCallbackAction = "com.example.demo_app.MOSAIC_CALLBACK"
    private val mosaicToggleAction = "com.example.demo_app.MOSAIC_TOGGLE"

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
        if (intent.action == mosaicToggleAction) {
            // MToggleAction: flip the stored bool and redraw. Entirely on-device,
            // so it works with the app closed.
            val key = intent.getStringExtra("toggleKey")
            if (key != null) {
                // Same store MosaicData.resolveBool reads, so the flip is visible
                // to bindings immediately.
                val prefs = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
                prefs.edit().putBoolean(key, !MosaicData.resolveBool(context, key)).apply()
                HomeWidgetBridgeHelper.refreshAll(context)
            }
            return
        }
        if (intent.action == mosaicCallbackAction) {
            val callbackName = intent.getStringExtra("callbackName") ?: return
            // A declared refresh source is fetched here, in the widget process,
            // so the button works with the app closed. goAsync() keeps the
            // broadcast alive for the request; network on the main thread would
            // throw NetworkOnMainThreadException.
            val pending = goAsync()
            // Publish a refreshing flag and redraw FIRST, so an
            // MActivityIndicator bound to `mosaic_refreshing` appears while the
            // request is in flight, then clear it and redraw with the result.
            MosaicRefreshSources.setRefreshing(context, true)
            HomeWidgetBridgeHelper.refreshAll(context)
            Thread {
                try {
                    MosaicRefreshSources.run(context, callbackName)
                } finally {
                    MosaicRefreshSources.setRefreshing(context, false)
                    HomeWidgetBridgeHelper.refreshAll(context)
                    pending.finish()
                }
            }.start()
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val intent = android.content.Intent(context, TasksProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val pendingIntent = android.app.PendingIntent.getBroadcast(context, 0, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        alarmManager.setRepeating(android.app.AlarmManager.RTC, System.currentTimeMillis(), 1800000, pendingIntent)
        
    }

    /// Inflates [layoutRes] and applies every update this widget declares.
    ///
    /// Actions naming a view the layout does not contain are skipped by
    /// RemoteViews itself, so one set of calls serves every size variant.
    private fun buildViews(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, layoutRes: Int): RemoteViews {
        val prefs = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, layoutRes)

        views.setTextViewText(R.id.hw_text_tasks_count, MosaicData.resolveString(context, "tasks_count", "--"))
        
        
        
        
                views.setBoolean(R.id.hw_clip__240_null_null, "setClipToOutline", true)
        views.setBoolean(R.id.hw_clip__100_null_null, "setClipToOutline", true)
        views.setBoolean(R.id.hw_clip__60_null_null, "setClipToOutline", true)
        
        
        
        
                val listIntent_tasks = android.content.Intent(context, MosaicListService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            putExtra("hw_list_key", "tasks")
            data = android.net.Uri.parse("mosaic://list/" + appWidgetId + "/tasks")
        }
        views.setRemoteAdapter(R.id.hw_list_tasks, listIntent_tasks)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.hw_list_tasks)
        

        return views
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        // Refresh native device metrics first, so bindings below read current
        // values rather than whatever the app last stored.
        MosaicDevice.populate(context)
        val views = buildViews(context, appWidgetManager, appWidgetId, R.layout.hw_tasks)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
