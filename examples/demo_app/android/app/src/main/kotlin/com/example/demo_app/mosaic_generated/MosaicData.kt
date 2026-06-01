// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.content.Context
import android.text.format.DateUtils
import java.text.DateFormat
import java.text.NumberFormat
import java.util.Date
import org.json.JSONArray

/// Runtime accessor for bound widget data persisted in SharedPreferences.
/// Values are written by the Flutter side into the "widget_data" store and
/// resolved here on every widget update.
object MosaicData {
    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences("widget_data", Context.MODE_PRIVATE)

    fun resolveString(ctx: Context, key: String, fallback: String = "--"): String {
        return try {
            prefs(ctx).getString(key, null) ?: fallback
        } catch (e: Exception) {
            fallback
        }
    }

    fun resolveDouble(ctx: Context, key: String, fallback: Double = 0.0): Double {
        return try {
            val raw = prefs(ctx).all[key] ?: return fallback
            when (raw) {
                is Number -> raw.toDouble()
                is String -> raw.toDoubleOrNull() ?: fallback
                is Boolean -> if (raw) 1.0 else 0.0
                else -> fallback
            }
        } catch (e: Exception) {
            fallback
        }
    }

    fun resolveBool(ctx: Context, key: String, fallback: Boolean = false): Boolean {
        return try {
            val raw = prefs(ctx).all[key] ?: return fallback
            when (raw) {
                is Boolean -> raw
                is Number -> raw.toDouble() != 0.0
                is String -> when (raw.trim().lowercase()) {
                    "true", "1", "yes" -> true
                    "false", "0", "no", "" -> false
                    else -> fallback
                }
                else -> fallback
            }
        } catch (e: Exception) {
            fallback
        }
    }

    /// Formats a raw stored string for display with the device default Locale.
    /// Numeric formats (decimal/currency/percent) parse [raw] as a Double;
    /// time formats parse it as epoch MILLISECONDS (Long). On any parse failure
    /// the raw string is returned unchanged.
    ///   decimal      -> NumberFormat.getInstance()
    ///   currency     -> NumberFormat.getCurrencyInstance()
    ///   percent      -> NumberFormat.getPercentInstance()
    ///   date         -> DateFormat.getDateInstance() on Date(epochMillis)
    ///   relativeTime -> DateUtils.getRelativeTimeSpanString(epochMillis)
    fun formatValue(raw: String, format: String): String {
        return try {
            when (format) {
                "decimal" -> NumberFormat.getInstance().format(raw.toDouble())
                "currency" -> NumberFormat.getCurrencyInstance().format(raw.toDouble())
                "percent" -> NumberFormat.getPercentInstance().format(raw.toDouble())
                "date" -> DateFormat.getDateInstance().format(Date(raw.toLong()))
                "relativeTime" -> DateUtils.getRelativeTimeSpanString(raw.toLong()).toString()
                else -> raw
            }
        } catch (e: Exception) {
            raw
        }
    }

    fun resolveList(ctx: Context, key: String): List<Map<String, String>> {
        return try {
            val raw = prefs(ctx).getString(key, null) ?: return emptyList()
            val arr = JSONArray(raw)
            val out = ArrayList<Map<String, String>>(arr.length())
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                val map = HashMap<String, String>()
                val keys = obj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    map[k] = obj.opt(k)?.toString() ?: ""
                }
                out.add(map)
            }
            out
        } catch (e: Exception) {
            emptyList()
        }
    }
}
