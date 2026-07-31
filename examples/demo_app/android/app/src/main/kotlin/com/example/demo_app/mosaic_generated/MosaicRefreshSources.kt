// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/// Network sources a refresh button fetches directly, declared under the
/// `refresh` key in mosaic.yaml.
object MosaicRefreshSources {
    private const val TAG = "Mosaic"

    data class Source(
        val url: String,
        val method: String,
        val headers: Map<String, String>,
        /// Stored key -> path into the JSON response.
        val map: Map<String, String>
    )

    val all: Map<String, List<Source>> = mapOf(
        "refresh_crypto" to listOf(
            Source("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true", "GET", mapOf("Accept" to "application/json"), mapOf("btc_price" to "bitcoin.usd", "btc_change" to "bitcoin.usd_24h_change"))
        ),
        "refresh_news" to listOf(
            Source("https://api.spaceflightnewsapi.net/v4/articles/?limit=2", "GET", mapOf("Accept" to "application/json"), mapOf("news_title" to "results[0].title", "news_image" to "results[0].image_url", "news_title_2" to "results[1].title", "news_source" to "results[0].news_site"))
        ),
        "refresh_weather" to listOf(
            Source("https://api.open-meteo.com/v1/forecast?latitude=37.77&longitude=-122.42&current=temperature_2m&daily=temperature_2m_max,temperature_2m_min&forecast_days=1", "GET", mapOf(), mapOf("temp_c" to "current.temperature_2m", "hi_c" to "daily.temperature_2m_max[0]", "lo_c" to "daily.temperature_2m_min[0]")),
            Source("https://api.open-meteo.com/v1/forecast?latitude=37.77&longitude=-122.42&current=temperature_2m&daily=temperature_2m_max,temperature_2m_min&forecast_days=1&temperature_unit=fahrenheit", "GET", mapOf(), mapOf("temp_f" to "current.temperature_2m", "hi_f" to "daily.temperature_2m_max[0]", "lo_f" to "daily.temperature_2m_min[0]"))
        ),
        "refresh_all" to listOf(
            Source("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true", "GET", mapOf(), mapOf("btc_price" to "bitcoin.usd", "btc_change" to "bitcoin.usd_24h_change")),
            Source("https://api.spaceflightnewsapi.net/v4/articles/?limit=2", "GET", mapOf(), mapOf("news_title" to "results[0].title")),
            Source("https://api.open-meteo.com/v1/forecast?latitude=37.77&longitude=-122.42&current=temperature_2m&daily=temperature_2m_max,temperature_2m_min&forecast_days=1", "GET", mapOf(), mapOf("temp_c" to "current.temperature_2m", "hi_c" to "daily.temperature_2m_max[0]", "lo_c" to "daily.temperature_2m_min[0]")),
            Source("https://api.open-meteo.com/v1/forecast?latitude=37.77&longitude=-122.42&current=temperature_2m&daily=temperature_2m_max,temperature_2m_min&forecast_days=1&temperature_unit=fahrenheit", "GET", mapOf(), mapOf("temp_f" to "current.temperature_2m", "hi_f" to "daily.temperature_2m_max[0]", "lo_f" to "daily.temperature_2m_min[0]"))
        )
    )

    /// Resolves a dotted path with optional `[n]` array indices (and an
    /// optional leading `$.`) against parsed JSON, e.g. `articles[0].title`.
    fun resolvePath(root: Any?, path: String): String? {
        var trimmed = path
        if (trimmed.startsWith("\$.")) trimmed = trimmed.substring(2)
        val normalized = trimmed.replace("[", ".").replace("]", "")
        var current: Any? = root
        for (segment in normalized.split(".")) {
            if (segment.isEmpty()) continue
            val index = segment.toIntOrNull()
            current = when {
                index != null && current is JSONArray ->
                    if (index >= 0 && index < current.length()) current.get(index) else return null
                current is JSONObject ->
                    if (current.has(segment)) current.get(segment) else return null
                else -> return null
            }
        }
        return when (current) {
            null, JSONObject.NULL -> null
            else -> current.toString()
        }
    }

    /// Fetches every source declared for [callback], storing each mapped value.
    /// Blocking — call from a background thread. Returns true when at least one
    /// value was written, so one failing endpoint does not discard the others.
    fun run(context: Context, callback: String): Boolean {
        val sources = all[callback] ?: return false
        var wroteAny = false
        var failure: String? = null
        for (source in sources) {
            when (val outcome = fetch(context, source)) {
                "ok" -> wroteAny = true
                else -> failure = outcome
            }
        }
        recordStatus(context, if (wroteAny) "ok" else (failure ?: "no data"))
        return wroteAny
    }

    /// Fetches every source supplying any of [keys], regardless of which
    /// callback declared it. De-duplicated by URL.
    fun runKeys(context: Context, keys: List<String>): Boolean {
        val wanted = keys.toSet()
        val seen = mutableSetOf<String>()
        val pending = mutableListOf<Source>()
        for ((_, sources) in all) {
            for (source in sources) {
                if (source.map.keys.any { it in wanted } && seen.add(source.url)) {
                    pending.add(source)
                }
            }
        }
        if (pending.isEmpty()) return false
        var wroteAny = false
        var failure: String? = null
        for (source in pending) {
            when (val outcome = fetch(context, source)) {
                "ok" -> wroteAny = true
                else -> failure = outcome
            }
        }
        recordStatus(context, if (wroteAny) "ok" else (failure ?: "no data"))
        return wroteAny
    }

    private fun fetch(context: Context, source: Source): String {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(source.url).openConnection() as HttpURLConnection).apply {
                requestMethod = source.method
                connectTimeout = 10_000
                readTimeout = 10_000
                useCaches = false
                for ((field, value) in source.headers) setRequestProperty(field, value)
            }
            val code = connection.responseCode
            if (code !in 200..299) return "http $code"
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val json: Any = if (body.trimStart().startsWith("[")) {
                JSONArray(body)
            } else {
                JSONObject(body)
            }
            val prefs = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            var wrote = false
            for ((key, path) in source.map) {
                val value = resolvePath(json, path)
                if (value != null) {
                    editor.putString(key, value)
                    wrote = true
                }
            }
            editor.apply()
            if (wrote) "ok" else "no data"
        } catch (e: Exception) {
            "offline"
        } finally {
            connection?.disconnect()
        }
    }

    /// Downloads [url] into the widget cache if absent and returns the file.
    /// Blocking — call from a background thread.
    ///
    /// Image URLs usually come from an API response rather than from the
    /// developer, so two things outside their control have to be handled:
    /// cleartext `http://` (blocked by default since API 28) and http -> https
    /// redirects (HttpURLConnection silently refuses to follow a redirect that
    /// changes protocol). Both otherwise render as a blank image with no clue
    /// why, so failures are logged and an https retry is attempted.
    fun cacheImage(context: Context, url: String): java.io.File? {
        if (url.isEmpty()) return null
        val dir = java.io.File(context.filesDir, "mosaic_images").apply { mkdirs() }
        // Hash rather than the raw URL: query strings are not path-safe.
        val file = java.io.File(dir, kotlin.math.abs(url.hashCode()).toString() + ".img")
        if (file.exists()) return file

        if (download(url, file)) return file
        // An http URL that failed may be blocked by the cleartext policy or be
        // a cross-protocol redirect; both succeed over https on most hosts.
        if (url.startsWith("http://")) {
            val secure = "https://" + url.removePrefix("http://")
            android.util.Log.i(TAG, "Retrying image over https: $secure")
            if (download(secure, file)) return file
        }
        return null
    }

    /// Fetches [url] into [target], following redirects manually so a
    /// http -> https hop is not dropped. Returns whether the file was written.
    private fun download(url: String, target: java.io.File, depth: Int = 0): Boolean {
        if (depth > 4) {
            android.util.Log.w(TAG, "Too many redirects for image: $url")
            return false
        }
        var connection: HttpURLConnection? = null
        try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 10_000
                readTimeout = 10_000
                // Handled below, so a protocol change is not silently dropped.
                instanceFollowRedirects = false
            }
            val code = connection.responseCode
            if (code in 300..399) {
                val location = connection.getHeaderField("Location")
                if (location.isNullOrEmpty()) {
                    android.util.Log.w(TAG, "Image redirect $code with no Location: $url")
                    return false
                }
                // Resolved against the original so a relative Location works.
                val next = URL(URL(url), location).toString()
                connection.disconnect()
                connection = null
                return download(next, target, depth + 1)
            }
            if (code !in 200..299) {
                android.util.Log.w(TAG, "Image fetch failed HTTP $code: $url")
                return false
            }
            connection.inputStream.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
            return true
        } catch (e: Exception) {
            target.delete()
            // Names the actual cause: a cleartext block surfaces here as a
            // SecurityException/IOException that is otherwise invisible.
            android.util.Log.w(TAG, "Image fetch failed for $url: ${e.javaClass.simpleName}: ${e.message}")
            return false
        } finally {
            connection?.disconnect()
        }
    }

    /// The cached file for [url], or null when it has not been downloaded yet.
    fun cachedImage(context: Context, url: String?): java.io.File? {
        if (url.isNullOrEmpty()) return null
        val file = java.io.File(
            java.io.File(context.filesDir, "mosaic_images"),
            kotlin.math.abs(url.hashCode()).toString() + ".img"
        )
        return if (file.exists()) file else null
    }

    /// Pixel dimensions for a chart bitmap, scaled up from the widget's dp
    /// bounds for sharpness but clamped to a transaction-safe budget.
    ///
    /// RemoteViews travels over a Binder transaction with a hard size limit. A
    /// naive `dp * 3` is fine on a small widget and catastrophic on a large one
    /// — a 5x5 tile works out at ~5.8 MB as ARGB_8888, which makes the launcher
    /// silently drop the whole update, blanking every bound value in the widget.
    ///
    /// The aspect ratio is preserved, so clamping costs sharpness on very large
    /// widgets and nothing else.
    fun chartBitmapSize(widthDp: Int, heightDp: Int): Pair<Int, Int> {
        val scale = 3
        var w = widthDp.coerceAtLeast(40) * scale
        var h = heightDp.coerceAtLeast(20) * scale
        // ~240 KB at 4 bytes/px, leaving room for several bitmaps in one update.
        val maxPx = 60_000
        val px = w.toLong() * h.toLong()
        if (px > maxPx) {
            val factor = kotlin.math.sqrt(maxPx.toDouble() / px.toDouble())
            w = (w * factor).toInt().coerceAtLeast(1)
            h = (h * factor).toInt().coerceAtLeast(1)
        }
        return Pair(w, h)
    }

    /// Decodes [file] downsampled to fit within [maxPx] on its longest side.
    ///
    /// RemoteViews are delivered over a Binder transaction with a hard size
    /// limit, and a full-resolution photo blows straight through it: a 4 MB JPEG
    /// decodes to tens of MB as ARGB_8888. When that happens the launcher drops
    /// the **entire** update, so the widget renders only its static layout —
    /// every bound value disappears at once, with nothing logged to explain it.
    ///
    /// A widget thumbnail is at most a couple of hundred pixels, so sampling
    /// down costs nothing visible and keeps the payload well inside the budget.
    fun decodeSampled(path: String, maxPx: Int = 320): android.graphics.Bitmap? {
        return try {
            val bounds = android.graphics.BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            android.graphics.BitmapFactory.decodeFile(path, bounds)
            val longest = maxOf(bounds.outWidth, bounds.outHeight)
            var sample = 1
            // inSampleSize must be a power of two; anything else is rounded
            // down by the decoder anyway.
            while (longest / sample > maxPx) sample *= 2
            android.graphics.BitmapFactory.decodeFile(
                path,
                android.graphics.BitmapFactory.Options().apply { inSampleSize = sample },
            )
        } catch (e: Exception) {
            android.util.Log.w(TAG, "Could not decode image $path: ${e.message}")
            null
        }
    }

    /// Publishes whether a refresh is in flight, under `mosaic_refreshing`.
    /// Bind it with MVisibility to swap a refresh icon for an
    /// MActivityIndicator while the request runs.
    fun setRefreshing(context: Context, value: Boolean) {
        context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("mosaic_refreshing", value)
            .apply()
    }

    /// Records the outcome under `mosaic_refresh_status`. Bind that key in a
    /// widget while diagnosing: a refresh that fetched unchanged data is
    /// otherwise indistinguishable from one that never ran.
    private fun recordStatus(context: Context, text: String) {
        val stamp = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.US)
            .format(java.util.Date())
        context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
            .edit()
            .putString("mosaic_refresh_status", "$stamp $text")
            .apply()
    }
}
