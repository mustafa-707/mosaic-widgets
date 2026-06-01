// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.demo_app.R

/// Best-effort Android fallback for Mosaic Live Activities.
///
/// Android has NO Dynamic Island and NO lock-screen Live Activity. A live
/// activity is therefore approximated with an ONGOING NOTIFICATION whose
/// content is a custom RemoteViews built from the generated `hw_la_<type>`
/// layout. This is intentionally a degraded experience compared to iOS.
///
/// Data flows through the shared "widget_data" SharedPreferences store so the
/// same `MosaicData` accessor that powers app widgets resolves live-activity
/// binds. POST_NOTIFICATIONS (API 33+) is assumed to already be granted by the
/// host application.
object MosaicLiveActivityManager {
    private const val CHANNEL_ID = "mosaic_live_activities"
    private const val CHANNEL_NAME = "Live Activities"

    /// Best-effort record of currently-posted live-activity ids. Notification
    /// ids are derived from this set; cleared by [end].
    private val activeIds = LinkedHashSet<String>()

    /// Maps each posted live-activity id to the activity TYPE it was started
    /// with. [update]/[end] resolve the type from here so the custom
    /// `hw_la_<type>` RemoteViews layout is preserved across updates instead of
    /// falling back to the system default.
    private val idTypes = mutableMapOf<String, String>()

    private fun prefs(context: Context) =
        context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)

    private fun writeData(context: Context, data: Map<String, String>) {
        val editor = prefs(context).edit()
        for ((k, v) in data) editor.putString(k, v)
        editor.apply()
    }

    private fun ensureChannel(context: Context, highImportance: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val importance = if (highImportance) {
            NotificationManager.IMPORTANCE_HIGH
        } else {
            NotificationManager.IMPORTANCE_LOW
        }
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance)
            )
        }
    }

    /// Resolves the generated RemoteViews layout for a live-activity [type].
    private fun layoutFor(type: String): Int {
        return when (type) {
            "OrderTracker" -> R.layout.hw_la_ordertracker
            else -> 0
        }
    }

    private fun notificationId(id: String): Int = id.hashCode()

    private fun buildNotification(
        context: Context,
        type: String,
        id: String,
        alertTitle: String?,
        alertBody: String?,
    ): Notification {
        val layout = layoutFor(type)
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setOnlyAlertOnce(alertTitle == null && alertBody == null)
        if (layout != 0) {
            val views = RemoteViews(context.packageName, layout)
            builder.setStyle(NotificationCompat.DecoratedCustomViewStyle())
            builder.setCustomContentView(views)
            builder.setCustomBigContentView(views)
        }
        if (alertTitle != null) builder.setContentTitle(alertTitle)
        if (alertBody != null) builder.setContentText(alertBody)
        if (alertTitle != null || alertBody != null) {
            builder.setPriority(NotificationCompat.PRIORITY_HIGH)
        } else {
            builder.setPriority(NotificationCompat.PRIORITY_LOW)
        }
        return builder.build()
    }

    /// Starts a live activity of [type] with initial [data]. Persists the data
    /// into "widget_data", posts the ongoing notification and returns its id.
    fun start(context: Context, type: String, data: Map<String, String>): String {
        writeData(context, data)
        ensureChannel(context, highImportance = false)
        val id = type
        activeIds.add(id)
        idTypes[id] = type
        val notification = buildNotification(context, type, id, null, null)
        NotificationManagerCompat.from(context).notify(notificationId(id), notification)
        return id
    }

    /// Updates the live activity [id] with new [data], rebuilding the
    /// RemoteViews and re-posting. When [alertTitle]/[alertBody] are supplied
    /// the notification is upgraded to a high-importance heads-up one-shot.
    fun update(
        context: Context,
        id: String,
        data: Map<String, String>,
        alertTitle: String? = null,
        alertBody: String? = null,
    ) {
        writeData(context, data)
        val alerting = alertTitle != null || alertBody != null
        ensureChannel(context, highImportance = alerting)
        activeIds.add(id)
        val type = idTypes[id] ?: id
        val notification = buildNotification(context, type, id, alertTitle, alertBody)
        NotificationManagerCompat.from(context).notify(notificationId(id), notification)
    }

    /// Ends the live activity [id] by cancelling its notification.
    fun end(context: Context, id: String) {
        activeIds.remove(id)
        idTypes.remove(id)
        NotificationManagerCompat.from(context).cancel(notificationId(id))
    }

    /// Whether notifications are enabled for the host app.
    fun enabled(context: Context): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled()

    /// Best-effort list of currently-posted live-activity ids.
    fun active(context: Context): List<String> = activeIds.toList()
}
