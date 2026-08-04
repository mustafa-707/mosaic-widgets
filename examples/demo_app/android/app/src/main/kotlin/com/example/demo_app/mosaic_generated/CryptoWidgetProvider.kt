// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.example.demo_app.R

class CryptoWidgetProvider : AppWidgetProvider() {
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

        views.setTextViewText(R.id.hw_text_btc_price, MosaicData.formatValue(MosaicData.resolveString(context, "btc_price", "64000"), "currency", "USD"))
        views.setTextViewText(R.id.hw_text_btc_change, MosaicData.formatValue(MosaicData.resolveString(context, "btc_change", "--"), "signedPercent"))
                val target0 = 1785835566623L
        val offset0 = target0 - System.currentTimeMillis()
        views.setChronometer(R.id.hw_timer_0, android.os.SystemClock.elapsedRealtime() + offset0, null, true)
        views.setChronometerCountDown(R.id.hw_timer_0, false)
      
        
        
                try {
            val cRaw0 = android.graphics.Color.parseColor(MosaicData.resolveString(context, "accent"))
            val c0 = (cRaw0 and 0x00FFFFFF.toInt()) or (71 shl 24)
            if (android.os.Build.VERSION.SDK_INT >= 31) {
                views.setColorStateList(R.id.hw_bgcolor_accent, "setBackgroundTintList",
                    android.content.res.ColorStateList.valueOf(c0))
            } else {
                views.setInt(R.id.hw_bgcolor_accent, "setBackgroundColor", c0)
            }
        } catch (e: Exception) { }
                views.setBoolean(R.id.hw_clip__240_null_null, "setClipToOutline", true)
        views.setBoolean(R.id.hw_bgcolor_accent, "setClipToOutline", true)
        views.setBoolean(R.id.hw_clip__80_320_320, "setClipToOutline", true)
        views.setBoolean(R.id.hw_clip__100_null_null, "setClipToOutline", true)
        
        
                run {
            val series = MosaicData.resolveDoubleList(context, "btc_series")
            // A line needs two ends; fewer points render nothing rather than a
            // misleading dot.
            if (series.size > 1) {
                val opts = appWidgetManager.getAppWidgetOptions(appWidgetId)
                val (wPx, hPx) = MosaicRefreshSources.chartBitmapSize(
                    opts?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 160,
                    opts?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 60,
                )
                val bmp = android.graphics.Bitmap.createBitmap(
                    wPx, hPx, android.graphics.Bitmap.Config.ARGB_8888)
                val canvas = android.graphics.Canvas(bmp)
                val lo = series.min()
                val hi = series.max()
                // A flat series would divide by zero; draw it down the middle.
                val span = if (hi - lo == 0.0) 1.0 else (hi - lo)
                val pad = 2.0f * 3f
                val paint = android.graphics.Paint().apply {
                    isAntiAlias = true
                    color = android.graphics.Color.parseColor("#7DD3FC")
                    style = android.graphics.Paint.Style.STROKE
                    strokeWidth = 2.0f * 3f
                    strokeCap = android.graphics.Paint.Cap.ROUND
                    strokeJoin = android.graphics.Paint.Join.ROUND
                }
                fun xAt(i: Int) = wPx * i.toFloat() / (series.size - 1)
                fun yAt(v: Double) =
                    (hPx - pad) - ((hPx - pad * 2) * ((v - lo) / span)).toFloat()

                val path = android.graphics.Path()
                path.moveTo(xAt(0), yAt(series[0]))
                for (i in 1 until series.size) path.lineTo(xAt(i), yAt(series[i]))
                val fillPath = android.graphics.Path(path)
                fillPath.lineTo(xAt(series.size - 1), hPx.toFloat())
                fillPath.lineTo(0f, hPx.toFloat())
                fillPath.close()
                canvas.drawPath(fillPath, android.graphics.Paint().apply {
                    isAntiAlias = true
                    color = android.graphics.Color.parseColor("#7DD3FC")
                    alpha = 46
                    style = android.graphics.Paint.Style.FILL
                })
                canvas.drawPath(path, paint)
                views.setImageViewBitmap(R.id.hw_spark_btc_series, bmp)
            }
        }
        
        
                val intent0 = android.content.Intent(context, CryptoWidgetProvider::class.java).apply {
            action = mosaicCallbackAction
            putExtra("callbackName", "refresh_crypto")
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
        val views = buildViews(context, appWidgetManager, appWidgetId, R.layout.hw_cryptowidget)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
