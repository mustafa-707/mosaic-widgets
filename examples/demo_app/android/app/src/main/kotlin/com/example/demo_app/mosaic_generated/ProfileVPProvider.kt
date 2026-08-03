// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.example.demo_app.R

class ProfileVPProvider : AppWidgetProvider() {
    private val mosaicCallbackAction = "com.example.demo_app.MOSAIC_CALLBACK"
    private val mosaicToggleAction = "com.example.demo_app.MOSAIC_TOGGLE"
    private val mosaicRefreshAction = "com.example.demo_app.MOSAIC_REFRESH"

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
        if (intent.action == mosaicRefreshAction) {
            // MRefreshAction: refetch every declared source that supplies a key
            // this widget binds, then redraw. Runs in the widget process, so it
            // works with the app closed — the same guarantee the iOS
            // MosaicRefreshIntent gives.
            val pending = goAsync()
            MosaicRefreshSources.setRefreshing(context, true)
            HomeWidgetBridgeHelper.refreshAll(context)
            Thread {
                try {
                    MosaicRefreshSources.runKeys(context, listOf("mosaic_battery_level", "mosaic_storage_free_gb", "system_status"))
                } finally {
                    MosaicRefreshSources.setRefreshing(context, false)
                    HomeWidgetBridgeHelper.refreshAll(context)
                    pending.finish()
                }
            }.start()
            return
        }
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

        views.setTextViewText(R.id.hw_text_system_status, MosaicData.resolveString(context, "system_status", "--"))
        views.setTextViewText(R.id.hw_text_mosaic_battery_level, MosaicData.resolveString(context, "mosaic_battery_level", "--"))
        views.setProgressBar(R.id.hw_progress_mosaic_battery_level, 100, MosaicData.resolveDouble(context, "mosaic_battery_level").toInt(), false)
        views.setTextViewText(R.id.hw_text_mosaic_storage_free_gb, MosaicData.resolveString(context, "mosaic_storage_free_gb", "--"))
        views.setTextViewText(R.id.hw_text_mosaic_battery_level_2, MosaicData.resolveString(context, "mosaic_battery_level", "--"))
        views.setProgressBar(R.id.hw_progress_mosaic_battery_level_2, 100, MosaicData.resolveDouble(context, "mosaic_battery_level").toInt(), false)
        
        
        
        
                views.setBoolean(R.id.hw_clip__280_null_null, "setClipToOutline", true)
        views.setBoolean(R.id.hw_clip__400_800_800, "setClipToOutline", true)
        views.setBoolean(R.id.hw_clip__120_240_240, "setClipToOutline", true)
        views.setBoolean(R.id.hw_clip__80_null_null, "setClipToOutline", true)
        views.setBoolean(R.id.hw_clip__80_null_null_2, "setClipToOutline", true)
        views.setBoolean(R.id.hw_clip__280_null_null_2, "setClipToOutline", true)
        
        
        
                run {
            val series = MosaicData.resolveDoubleList(context, "storage_week")
            val top = series.maxOrNull() ?: 0.0
            // Bars are scaled from zero, so a series with nothing positive has
            // no magnitude to draw.
            if (series.isNotEmpty() && top > 0.0) {
                val opts = appWidgetManager.getAppWidgetOptions(appWidgetId)
                val (wPx, hPx) = MosaicRefreshSources.chartBitmapSize(
                    opts?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 160,
                    opts?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 60,
                )
                val bmp = android.graphics.Bitmap.createBitmap(
                    wPx, hPx, android.graphics.Bitmap.Config.ARGB_8888)
                val canvas = android.graphics.Canvas(bmp)
                val paint = android.graphics.Paint().apply {
                    isAntiAlias = true
                    color = android.graphics.Color.parseColor("#22C55E")
                    style = android.graphics.Paint.Style.FILL
                }
                val gap = 3.0f * 3f
                val radius = 2.0f * 3f
                val slot = wPx.toFloat() / series.size
                val barW = (slot - gap).coerceAtLeast(1f)
                for (i in series.indices) {
                    val v = series[i].coerceAtLeast(0.0)
                    // At least a hairline, so a zero bucket still reads as a
                    // bucket rather than a gap in the axis.
                    val barH = ((hPx * (v / top)).toFloat()).coerceAtLeast(1f)
                    val left = slot * i + gap / 2f
                    canvas.drawRoundRect(
                        left, hPx - barH, left + barW, hPx.toFloat(),
                        radius, radius, paint)
                }
                views.setImageViewBitmap(R.id.hw_bars_storage_week, bmp)
            }
        }
        
                val intent0 = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse("hwdemo://profile/details"))
        val pendingIntent0 = android.app.PendingIntent.getActivity(context, appWidgetId * 100 + 0, intent0, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.hw_button_main, pendingIntent0)
        
                val intent1 = android.content.Intent(context, ProfileVPProvider::class.java).apply {
            action = mosaicRefreshAction
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val pendingIntent1 = android.app.PendingIntent.getBroadcast(context, appWidgetId * 100 + 1, intent1, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.hw_button_1, pendingIntent1)
        

        return views
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        // Refresh native device metrics first, so bindings below read current
        // values rather than whatever the app last stored.
        MosaicDevice.populate(context)
        val views = if (android.os.Build.VERSION.SDK_INT >= 31) {
            RemoteViews(mapOf(
                android.util.SizeF(1f, 1f) to buildViews(context, appWidgetManager, appWidgetId, R.layout.hw_profilevp_compact),
                android.util.SizeF(110f, 110f) to buildViews(context, appWidgetManager, appWidgetId, R.layout.hw_profilevp)
            ))
        } else {
            buildViews(context, appWidgetManager, appWidgetId, R.layout.hw_profilevp)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
