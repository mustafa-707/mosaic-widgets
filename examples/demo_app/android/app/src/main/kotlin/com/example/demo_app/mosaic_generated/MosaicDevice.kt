// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.content.Context

/// Device metrics read in the widget process, so they are correct even when the
/// app has not run for days. Values land in the same `widget_data` store every
/// other binding reads, so no node type needs to know about them.
object MosaicDevice {
    /// Refreshes the metrics this project's widgets reference. Called at the top
    /// of every widget update — cheap, and always current.
    fun populate(context: Context) {
        
        val prefs = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        val batteryManager =
            context.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
        editor.putString(
            "mosaic_battery_level",
            batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY).toString()
        )
        editor.putBoolean("mosaic_battery_charging", batteryManager.isCharging)
        val stat = android.os.StatFs(android.os.Environment.getDataDirectory().path)
        val freeBytes = stat.availableBlocksLong * stat.blockSizeLong
        val totalBytes = stat.blockCountLong * stat.blockSizeLong
        editor.putString(
            "mosaic_storage_free_gb",
            String.format(java.util.Locale.US, "%.1f", freeBytes / 1_000_000_000.0)
        )
        if (totalBytes > 0) {
            val usedPercent = ((totalBytes - freeBytes) * 100.0 / totalBytes)
            editor.putString(
                "mosaic_storage_used_percent",
                String.format(java.util.Locale.US, "%.0f", usedPercent)
            )
        }
        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val memInfo = android.app.ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memInfo)
        editor.putString(
            "mosaic_memory_free_mb",
            (memInfo.availMem / 1_048_576L).toString()
        )
        editor.putString(
            "mosaic_memory_total_mb",
            (memInfo.totalMem / 1_048_576L).toString()
        )
        if (memInfo.totalMem > 0) {
            val usedPercent =
                ((memInfo.totalMem - memInfo.availMem) * 100.0 / memInfo.totalMem)
            editor.putString(
                "mosaic_memory_used_percent",
                String.format(java.util.Locale.US, "%.0f", usedPercent)
            )
        }

        editor.apply()
    }
}
