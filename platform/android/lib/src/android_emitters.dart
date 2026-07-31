// Shared Kotlin runtime: the data store, the app bridge, in-widget refresh,
// and native device metrics.
part of '../mosaic_android.dart';

extension AndroidRuntimeEmitters on AndroidGenerator {
  Future<void> _generateMosaicData(String projectRoot) async {
    final packagePath = config.app.androidPackage.replaceAll('.', '/');
    final kotlinDir = Directory(
      p.join(
        projectRoot,
        'android',
        'app',
        'src',
        'main',
        'kotlin',
        packagePath,
        'mosaic_generated',
      ),
    );
    if (!kotlinDir.existsSync()) kotlinDir.createSync(recursive: true);

    final file = File(p.join(kotlinDir.path, 'MosaicData.kt'));
    await file.writeAsString('''$kotlinSentinel
package ${config.app.androidPackage}.mosaic_generated

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
    fun formatValue(raw: String, format: String, currencyCode: String? = null): String {
        return try {
            when (format) {
                "decimal" -> NumberFormat.getInstance().format(raw.toDouble())
                // A declared code keeps the widget honest: without it the value
                // is rendered in the *device's* currency, so a USD price reads
                // as the local currency without ever being converted.
                "currency" -> NumberFormat.getCurrencyInstance().apply {
                    if (currencyCode != null) {
                        try { currency = java.util.Currency.getInstance(currencyCode) }
                        catch (e: Exception) { }
                    }
                }.format(raw.toDouble())
                "percent" -> NumberFormat.getPercentInstance().format(raw.toDouble())
                // Already in percent units, so no scaling — only a sign and a
                // fixed scale. %+.2f uses the locale's decimal separator.
                "signedPercent" ->
                    String.format(java.util.Locale.getDefault(), "%+.2f%%", raw.toDouble())
                "date" -> DateFormat.getDateInstance().format(Date(raw.toLong()))
                "relativeTime" -> DateUtils.getRelativeTimeSpanString(raw.toLong()).toString()
                else -> raw
            }
        } catch (e: Exception) {
            raw
        }
    }

    /// A stored numeric series, for charting.
    ///
    /// Entries may arrive as JSON numbers or as strings, depending on how the
    /// app saved them; anything unparseable is skipped rather than zeroed,
    /// which would put a false trough in the line.
    fun resolveDoubleList(ctx: Context, key: String): List<Double> {
        return try {
            val raw = prefs(ctx).getString(key, null) ?: return emptyList()
            val arr = JSONArray(raw)
            val out = ArrayList<Double>(arr.length())
            for (i in 0 until arr.length()) {
                val v = arr.opt(i)
                when (v) {
                    is Number -> out.add(v.toDouble())
                    is String -> v.toDoubleOrNull()?.let { out.add(it) }
                }
            }
            out
        } catch (e: Exception) {
            emptyList()
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
''');
  }

  Future<void> _generateBridgeHelper(String projectRoot) async {
    final packagePath = config.app.androidPackage.replaceAll('.', '/');
    final kotlinDir = Directory(
      p.join(
        projectRoot,
        'android',
        'app',
        'src',
        'main',
        'kotlin',
        packagePath,
        'mosaic_generated',
      ),
    );
    if (!kotlinDir.existsSync()) kotlinDir.createSync(recursive: true);

    final file = File(p.join(kotlinDir.path, 'HomeWidgetBridgeHelper.kt'));

    final providerClasses =
        definitions.map((d) => '${_safeName(d.name)}Provider').toList();
    final refreshAllLogic = providerClasses
        .map(
          (cls) => '''
        context.sendBroadcast(android.content.Intent(context, $cls::class.java).apply {
            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = android.appwidget.AppWidgetManager.getInstance(context)
                .getAppWidgetIds(android.content.ComponentName(context, $cls::class.java))
            putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        })''',
        )
        .join('\n');

    final refreshSpecificLogic = definitions.map(
      (d) {
        final safeCls = '${_safeName(d.name)}Provider';
        return '''
            "${kotlinEscape(d.name)}" -> {
                context.sendBroadcast(android.content.Intent(context, $safeCls::class.java).apply {
                    action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val ids = android.appwidget.AppWidgetManager.getInstance(context)
                        .getAppWidgetIds(android.content.ComponentName(context, $safeCls::class.java))
                    putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                })
            }''';
      },
    ).join('\n');

    await file.writeAsString('''$kotlinSentinel
package ${config.app.androidPackage}.mosaic_generated

import android.content.Context

object HomeWidgetBridgeHelper {
    fun refreshAll(context: Context) {
        $refreshAllLogic
    }

    fun refresh(context: Context, widgetName: String) {
        when (widgetName) {
            $refreshSpecificLogic
        }
    }
}
''');
  }

  Future<void> _generateRefreshSources(String projectRoot) async {
    final packagePath = config.app.androidPackage.replaceAll('.', '/');
    final kotlinDir = Directory(
      p.join(projectRoot, 'android', 'app', 'src', 'main', 'kotlin',
          packagePath, 'mosaic_generated'),
    );
    if (!kotlinDir.existsSync()) kotlinDir.createSync(recursive: true);

    final entries = config.refresh.entries.map((e) {
      final sources = e.value.map((source) {
        final headers = source.headers.entries
            .map((h) =>
                '"${kotlinEscape(h.key)}" to "${kotlinEscape(h.value)}"')
            .join(', ');
        final map = source.map.entries
            .map((m) =>
                '"${kotlinEscape(m.key)}" to "${kotlinEscape(m.value)}"')
            .join(', ');
        return '            Source("${kotlinEscape(source.url)}", '
            '"${kotlinEscape(source.method)}", '
            'mapOf($headers), mapOf($map))';
      }).join(',\n');
      return '        "${kotlinEscape(e.key)}" to listOf(\n$sources\n        )';
    }).join(',\n');

    final table = entries.isEmpty
        ? '    val all: Map<String, List<Source>> = emptyMap()'
        : '    val all: Map<String, List<Source>> = mapOf(\n$entries\n    )';

    final file = File(p.join(kotlinDir.path, 'MosaicRefreshSources.kt'));
    await file.writeAsString('''$kotlinSentinel
package ${config.app.androidPackage}.mosaic_generated

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

$table

    /// Resolves a dotted path with optional `[n]` array indices (and an
    /// optional leading `\$.`) against parsed JSON, e.g. `articles[0].title`.
    fun resolvePath(root: Any?, path: String): String? {
        var trimmed = path
        if (trimmed.startsWith("\\\$.")) trimmed = trimmed.substring(2)
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
            if (code !in 200..299) return "http \$code"
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
            android.util.Log.i(TAG, "Retrying image over https: \$secure")
            if (download(secure, file)) return file
        }
        return null
    }

    /// Fetches [url] into [target], following redirects manually so a
    /// http -> https hop is not dropped. Returns whether the file was written.
    private fun download(url: String, target: java.io.File, depth: Int = 0): Boolean {
        if (depth > 4) {
            android.util.Log.w(TAG, "Too many redirects for image: \$url")
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
                    android.util.Log.w(TAG, "Image redirect \$code with no Location: \$url")
                    return false
                }
                // Resolved against the original so a relative Location works.
                val next = URL(URL(url), location).toString()
                connection.disconnect()
                connection = null
                return download(next, target, depth + 1)
            }
            if (code !in 200..299) {
                android.util.Log.w(TAG, "Image fetch failed HTTP \$code: \$url")
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
            android.util.Log.w(TAG, "Image fetch failed for \$url: \${e.javaClass.simpleName}: \${e.message}")
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
            android.util.Log.w(TAG, "Could not decode image \$path: \${e.message}")
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
            .putString("mosaic_refresh_status", "\$stamp \$text")
            .apply()
    }
}
''');
  }

  /// Generates `MosaicPlugin.kt` — the host-app side of the bridge.
  ///
  /// The iOS counterpart replaced ~200 lines of hand-copied AppDelegate code;
  /// Android integrators were still hand-writing the same method channel,
  /// callback receiver and deep-link plumbing in MainActivity. This is that
  /// code, generated, so the integration is two overrides.
  ///
  /// Live Activity branches are emitted only when the project declares live
  /// activities, because `MosaicLiveActivityManager` is generated only then.
  Future<void> _generateHostPlugin(String projectRoot) async {
    final packagePath = config.app.androidPackage.replaceAll('.', '/');
    final kotlinDir = Directory(
      p.join(projectRoot, 'android', 'app', 'src', 'main', 'kotlin',
          packagePath, 'mosaic_generated'),
    );
    if (!kotlinDir.existsSync()) kotlinDir.createSync(recursive: true);

    final pkg = config.app.androidPackage;
    final hasActivities = liveActivities.isNotEmpty;

    final activityCases = hasActivities
        ? '''
                "startActivity" -> {
                    val type = call.argument<String>("activityType")
                    if (type == null) {
                        result.error("INVALID_ARGUMENTS", "activityType is required", null)
                    } else {
                        result.success(
                            MosaicLiveActivityManager.start(context, type, stringMap(call, "state"))
                        )
                    }
                }
                "updateActivity" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("INVALID_ARGUMENTS", "id is required", null)
                    } else {
                        val alert = call.argument<Map<String, Any?>>("alert")
                        MosaicLiveActivityManager.update(
                            context, id, stringMap(call, "state"),
                            alert?.get("title")?.toString(),
                            alert?.get("body")?.toString()
                        )
                        result.success(null)
                    }
                }
                "endActivity" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("INVALID_ARGUMENTS", "id is required", null)
                    } else {
                        MosaicLiveActivityManager.end(context, id)
                        result.success(null)
                    }
                }
                "activitiesEnabled" -> result.success(MosaicLiveActivityManager.enabled(context))
                "activeActivities" -> result.success(MosaicLiveActivityManager.active(context))
'''
        : '''
                // This project declares no live_activities, so
                // MosaicLiveActivityManager is not generated.
                "startActivity", "updateActivity", "endActivity" ->
                    result.error("UNAVAILABLE", "No live_activities declared in mosaic.yaml", null)
                "activitiesEnabled" -> result.success(false)
                "activeActivities" -> result.success(emptyList<String>())
''';

    // Maps the widget name developers use in Dart to its generated provider,
    // so `requestPinWidget('News')` needs no knowledge of Kotlin class names.
    final pinEntries = definitions
        .map((d) => '            "${d.name}" to '
            '$pkg.mosaic_generated.${_safeName(d.name)}Provider::class.java')
        .join(',\n');

    final file = File(p.join(kotlinDir.path, 'MosaicPlugin.kt'));
    await file.writeAsString('''$kotlinSentinel
package $pkg.mosaic_generated

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Host-app side of the Mosaic bridge.
///
/// Wire it up with two overrides:
///
///     class MainActivity : FlutterActivity() {
///         private val mosaic = MosaicPlugin()
///
///         override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
///             super.configureFlutterEngine(flutterEngine)
///             mosaic.register(this, flutterEngine)
///         }
///
///         override fun onNewIntent(intent: Intent) {
///             super.onNewIntent(intent)
///             setIntent(intent)
///             mosaic.handleIntent(intent)
///         }
///     }
class MosaicPlugin {
    private var channel: MethodChannel? = null

    fun register(activity: FlutterActivity, engine: FlutterEngine) {
        val context = activity.applicationContext
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "mosaic_bridge")
        this.channel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "saveString", "saveBool" -> {
                    val key = call.argument<String>("key")
                    when (val value = call.argument<Any>("value")) {
                        null -> result.error("INVALID_ARGUMENTS", "key and value are required", null)
                        else -> {
                            if (key == null) {
                                result.error("INVALID_ARGUMENTS", "key is required", null)
                            } else {
                                val prefs = context.getSharedPreferences(
                                    "widget_data", Context.MODE_PRIVATE)
                                val editor = prefs.edit()
                                if (value is Boolean) {
                                    editor.putBoolean(key, value)
                                } else {
                                    editor.putString(key, value.toString())
                                }
                                editor.apply()
                                result.success(null)
                            }
                        }
                    }
                }
                "refreshAll" -> {
                    HomeWidgetBridgeHelper.refreshAll(context)
                    result.success(null)
                }
                "refresh" -> {
                    val widgetName = call.argument<String>("widgetName")
                    if (widgetName == null) {
                        result.error("INVALID_ARGUMENTS", "widgetName is required", null)
                    } else {
                        HomeWidgetBridgeHelper.refresh(context, widgetName)
                        result.success(null)
                    }
                }
                // Android has no WidgetKit-style widget push. Answering empty
                // keeps MosaicBridge.widgetPushTokens() honest here.
                "widgetPushTokens" -> result.success(emptyMap<String, String>())
                // Asks the launcher to show its "add widget" dialog. Only some
                // launchers implement it, hence the capability check.
                "canRequestPinWidget" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        AppWidgetManager.getInstance(context).isRequestPinAppWidgetSupported
                )
                "requestPinWidget" -> {
                    val widgetName = call.argument<String>("widgetName")
                    val provider = widgetName?.let { PIN_PROVIDERS[it] }
                    when {
                        widgetName == null ->
                            result.error("INVALID_ARGUMENTS", "widgetName is required", null)
                        provider == null ->
                            result.error(
                                "UNKNOWN_WIDGET",
                                "No widget named \\"\$widgetName\\". Known: \${PIN_PROVIDERS.keys.joinToString(", ")}",
                                null
                            )
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ->
                            result.success(false)
                        else -> {
                            val manager = AppWidgetManager.getInstance(context)
                            if (!manager.isRequestPinAppWidgetSupported) {
                                // A launcher that does not support pinning is a
                                // normal outcome, not an error — the caller
                                // shows manual instructions instead.
                                result.success(false)
                            } else {
                                result.success(
                                    manager.requestPinAppWidget(
                                        ComponentName(context, provider), null, null
                                    )
                                )
                            }
                        }
                    }
                }
$activityCases
                else -> result.notImplemented()
            }
        }

        registerCallbackReceiver(activity)
        // The launch intent is already set when the engine is configured, so a
        // cold start from a widget tap would otherwise lose its deep link.
        handleIntent(activity.intent)
    }

    /// Forwards a widget deep link to Dart. Call from `onNewIntent` so taps
    /// reach a warm app too.
    fun handleIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val url = intent.dataString ?: return
        channel?.invokeMethod("onDeepLink", mapOf("url" to url))
    }

    private fun registerCallbackReceiver(activity: FlutterActivity) {
        if (receiverRegistered) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                val name = intent.getStringExtra("callbackName") ?: return
                channel?.invokeMethod("backgroundCallback", mapOf("callbackName" to name))
            }
        }
        val filter = IntentFilter("$pkg.MOSAIC_CALLBACK")
        // Registered on the application context and guarded, so an activity
        // recreation neither double-registers nor leaks a receiver.
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            activity.applicationContext.registerReceiver(
                receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            activity.applicationContext.registerReceiver(receiver, filter)
        }
        receiverRegistered = true
    }

    /// Widget state arrives as strings, so coerce whatever Dart sent.
    private fun stringMap(call: MethodCall, name: String): Map<String, String> =
        (call.argument<Map<String, Any?>>(name) ?: emptyMap())
            .mapValues { it.value?.toString() ?: "" }

    private companion object {
        var receiverRegistered = false

        /// Widget name (as written in mosaic.yaml) to its generated provider.
        val PIN_PROVIDERS: Map<String, Class<*>> = mapOf(
$pinEntries
        )
    }
}
''');
  }

  /// Generates `MosaicDevice.kt` — native device metrics written into the same
  /// store the bindings read.
  ///
  /// Only the metrics some widget references are collected: reading battery
  /// touches BatteryManager and storage stats hit the filesystem, so gathering
  /// unused values is pure cost on every redraw.
  Future<void> _generateDeviceMetrics(String projectRoot) async {
    final metrics = <MosaicDeviceMetric>{};
    for (final def in definitions) {
      metrics.addAll(deviceMetricsIn(def.root.toJson()));
    }

    final packagePath = config.app.androidPackage.replaceAll('.', '/');
    final kotlinDir = Directory(
      p.join(projectRoot, 'android', 'app', 'src', 'main', 'kotlin',
          packagePath, 'mosaic_generated'),
    );
    if (!kotlinDir.existsSync()) kotlinDir.createSync(recursive: true);

    final needsBattery =
        metrics.contains(MosaicDeviceMetric.batteryLevel) ||
            metrics.contains(MosaicDeviceMetric.batteryCharging);
    final needsStorage =
        metrics.contains(MosaicDeviceMetric.storageFreeGb) ||
            metrics.contains(MosaicDeviceMetric.storageUsedPercent);

    final battery = needsBattery
        ? '''
        val batteryManager =
            context.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
        editor.putString(
            "${MosaicDeviceMetric.batteryLevel.key}",
            batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY).toString()
        )
        editor.putBoolean("${MosaicDeviceMetric.batteryCharging.key}", batteryManager.isCharging)
'''
        : '';

    final storage = needsStorage
        ? '''
        val stat = android.os.StatFs(android.os.Environment.getDataDirectory().path)
        val freeBytes = stat.availableBlocksLong * stat.blockSizeLong
        val totalBytes = stat.blockCountLong * stat.blockSizeLong
        editor.putString(
            "${MosaicDeviceMetric.storageFreeGb.key}",
            String.format(java.util.Locale.US, "%.1f", freeBytes / 1_000_000_000.0)
        )
        if (totalBytes > 0) {
            val usedPercent = ((totalBytes - freeBytes) * 100.0 / totalBytes)
            editor.putString(
                "${MosaicDeviceMetric.storageUsedPercent.key}",
                String.format(java.util.Locale.US, "%.0f", usedPercent)
            )
        }
'''
        : '';

    final needsMemory =
        metrics.contains(MosaicDeviceMetric.memoryFreeMb) ||
            metrics.contains(MosaicDeviceMetric.memoryTotalMb) ||
            metrics.contains(MosaicDeviceMetric.memoryUsedPercent);

    // ActivityManager.MemoryInfo is the same source the system settings screen
    // reports, so the number a user sees here matches what their phone tells
    // them elsewhere.
    final memory = needsMemory
        ? '''
        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val memInfo = android.app.ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memInfo)
        editor.putString(
            "${MosaicDeviceMetric.memoryFreeMb.key}",
            (memInfo.availMem / 1_048_576L).toString()
        )
        editor.putString(
            "${MosaicDeviceMetric.memoryTotalMb.key}",
            (memInfo.totalMem / 1_048_576L).toString()
        )
        if (memInfo.totalMem > 0) {
            val usedPercent =
                ((memInfo.totalMem - memInfo.availMem) * 100.0 / memInfo.totalMem)
            editor.putString(
                "${MosaicDeviceMetric.memoryUsedPercent.key}",
                String.format(java.util.Locale.US, "%.0f", usedPercent)
            )
        }
'''
        : '';

    final file = File(p.join(kotlinDir.path, 'MosaicDevice.kt'));
    await file.writeAsString('''$kotlinSentinel
package ${config.app.androidPackage}.mosaic_generated

import android.content.Context

/// Device metrics read in the widget process, so they are correct even when the
/// app has not run for days. Values land in the same `widget_data` store every
/// other binding reads, so no node type needs to know about them.
object MosaicDevice {
    /// Refreshes the metrics this project's widgets reference. Called at the top
    /// of every widget update — cheap, and always current.
    fun populate(context: Context) {
        ${battery.isEmpty && storage.isEmpty && memory.isEmpty ? '// No widget references a device metric.' : ''}
        val prefs = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        val editor = prefs.edit()
$battery$storage$memory
        editor.apply()
    }
}
''');
  }
}
