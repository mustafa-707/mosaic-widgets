// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.example.demo_app.R

class MemoryProvider : AppWidgetProvider() {
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
        
    }

    /// Inflates [layoutRes] and applies every update this widget declares.
    ///
    /// Actions naming a view the layout does not contain are skipped by
    /// RemoteViews itself, so one set of calls serves every size variant.
    private fun buildViews(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, layoutRes: Int): RemoteViews {
        val prefs = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, layoutRes)

        views.setTextViewText(R.id.hw_text_mosaic_memory_used_percent, MosaicData.formatValue(MosaicData.resolveString(context, "mosaic_memory_used_percent", "--"), "decimal"))
        views.setTextViewText(R.id.hw_text_mosaic_memory_free_mb, MosaicData.formatValue(MosaicData.resolveString(context, "mosaic_memory_free_mb", "--"), "decimal"))
        views.setProgressBar(R.id.hw_progress_mosaic_memory_used_percent, 100, MosaicData.resolveDouble(context, "mosaic_memory_used_percent").toInt(), false)
        views.setTextViewText(R.id.hw_text_mosaic_memory_total_mb, MosaicData.formatValue(MosaicData.resolveString(context, "mosaic_memory_total_mb", "--"), "decimal"))
        
        views.setViewVisibility(R.id.hw_visibility_mosaic_refreshing, if (MosaicData.resolveBool(context, "mosaic_refreshing")) android.view.View.VISIBLE else android.view.View.GONE)
        views.setViewVisibility(R.id.hw_visibility_mosaic_refreshing_alt, if (MosaicData.resolveBool(context, "mosaic_refreshing")) android.view.View.GONE else android.view.View.VISIBLE)
        views.setViewVisibility(R.id.hw_visibility_mosaic_refreshing_2, if (MosaicData.resolveBool(context, "mosaic_refreshing")) android.view.View.VISIBLE else android.view.View.GONE)
        views.setViewVisibility(R.id.hw_visibility_mosaic_refreshing_2_alt, if (MosaicData.resolveBool(context, "mosaic_refreshing")) android.view.View.GONE else android.view.View.VISIBLE)
        
        
                views.setBoolean(R.id.hw_clip__240_null_null, "setClipToOutline", true)
        views.setBoolean(R.id.hw_clip__80_null_null, "setClipToOutline", true)
        views.setBoolean(R.id.hw_clip__80_null_null_2, "setClipToOutline", true)
        
        
        
        
        
                val intent0 = android.content.Intent(context, MemoryProvider::class.java).apply {
            action = mosaicCallbackAction
            putExtra("callbackName", "clear_ram")
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val pendingIntent0 = android.app.PendingIntent.getBroadcast(context, appWidgetId * 100 + 0, intent0, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.hw_button_main, pendingIntent0)
        

        return views
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        // Refresh native device metrics first, so bindings below read current
        // values rather than whatever the app last stored.
        MosaicDevice.populate(context)
        val views = buildViews(context, appWidgetManager, appWidgetId, R.layout.hw_memory)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
