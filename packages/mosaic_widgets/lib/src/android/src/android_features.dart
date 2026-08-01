// Kotlin for the optional surfaces: Live Updates, Quick Settings tiles, and
// list adapters.
part of '../android.dart';

extension AndroidFeatureEmitters on AndroidGenerator {
  Future<void> _generateLiveActivityManager(String projectRoot) async {
    if (liveActivities.isEmpty) return;

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

    // Map each live-activity type name to its generated layout resource. A
    // `when` over the type selects the RemoteViews layout at runtime.
    final layoutCases = liveActivities
        .map((la) => (la['name'] as String?) ?? 'live_activity')
        .toSet()
        .map((name) {
      final lit = kotlinEscape(name);
      final layout = 'hw_la_${_safeName(name).toLowerCase()}';
      return '            "$lit" -> R.layout.$layout';
    }).join('\n');

    final file = File(p.join(kotlinDir.path, 'MosaicLiveActivityManager.kt'));
    await file.writeAsString('''$kotlinSentinel
package ${config.app.androidPackage}.mosaic_generated

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import ${config.app.androidPackage}.R

/// Best-effort Android fallback for Mosaic Live Activities.
///
/// Android has NO Dynamic Island and NO lock-screen Live Activity. A live
/// activity is therefore approximated with an ONGOING NOTIFICATION whose
/// content is a custom RemoteViews built from the generated `hw_la_<type>`
/// layout. This is intentionally a degraded experience compared to iOS.
///
/// LIVE UPDATES UPGRADE (Android 16 / API 36, `Build.VERSION_CODES.BAKLAVA`):
/// Android 16 introduces "Live Updates" — short-lived, user-promoted ongoing
/// notifications that surface progress-centric updates (delivery, ride, etc.)
/// prominently on the lock screen and status bar. This is the closest OS analog
/// to an iOS Live Activity. When running on API 36+ the notification is built
/// with the platform `Notification.Builder` + `Notification.ProgressStyle`
/// (a determinate progress segment driven by `data["progress"]` parsed as
/// 0..100, indeterminate when absent) and marked promoted-ongoing so the system
/// treats it as a Live Update. The rich `hw_la_<type>` RemoteViews layout is
/// still attached as the custom content/big-content view. On older OS versions
/// the legacy custom-RemoteViews ongoing `NotificationCompat` notification is
/// posted unchanged.
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
$layoutCases
            else -> 0
        }
    }

    private fun notificationId(id: String): Int = id.hashCode()

    /// Parses an optional 0..100 progress value out of the shared data map
    /// (the activity's `data["progress"]`, persisted into "widget_data").
    /// Returns null when absent/unparseable so callers can fall back to an
    /// indeterminate progress segment.
    private fun parseProgress(context: Context): Int? {
        // Equivalent to reading data["progress"] from the start/update payload.
        val raw = prefs(context).getString("progress", null) ?: return null
        val value = raw.trim().toFloatOrNull() ?: return null
        return value.toInt().coerceIn(0, 100)
    }

    private fun buildNotification(
        context: Context,
        type: String,
        id: String,
        alertTitle: String?,
        alertBody: String?,
    ): Notification {
        // Android 16 (API 36, BAKLAVA) Live Updates: build a promoted ongoing
        // notification with Notification.ProgressStyle. See class doc.
        if (Build.VERSION.SDK_INT >= 36) {
            return buildLiveUpdateNotification(context, type, id, alertTitle, alertBody)
        }
        return buildLegacyNotification(context, type, id, alertTitle, alertBody)
    }

    /// Android 16+ "Live Updates": a promoted ongoing notification driven by
    /// `Notification.ProgressStyle`. `data["progress"]` (0..100) feeds a
    /// determinate progress segment; when absent the segment is indeterminate.
    /// The rich `hw_la_<type>` RemoteViews is still attached as custom content
    /// so the full Mosaic layout shows in the expanded view.
    @androidx.annotation.RequiresApi(36)
    private fun buildLiveUpdateNotification(
        context: Context,
        type: String,
        id: String,
        alertTitle: String?,
        alertBody: String?,
    ): Notification {
        val layout = layoutFor(type)
        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setOnlyAlertOnce(alertTitle == null && alertBody == null)

        // ProgressStyle is the progress-centric Live Update style. Use a single
        // determinate segment when data["progress"] is present, otherwise leave
        // it indeterminate so the system shows an animated/ongoing indicator.
        val progress = parseProgress(context)
        val progressStyle = Notification.ProgressStyle()
        if (progress != null) {
            progressStyle.setProgressIndeterminate(false)
            progressStyle.setProgressSegments(
                listOf(Notification.ProgressStyle.Segment(100))
            )
            progressStyle.setProgress(progress)
        } else {
            progressStyle.setProgressIndeterminate(true)
        }
        builder.setStyle(progressStyle)

        if (layout != 0) {
            val views = RemoteViews(context.packageName, layout)
            builder.setCustomContentView(views)
            builder.setCustomBigContentView(views)
        }
        if (alertTitle != null) builder.setContentTitle(alertTitle)
        if (alertBody != null) builder.setContentText(alertBody)
        builder.setColorized(true)

        val notification = builder.build()
        // Mark as a promoted ongoing notification so the system treats it as a
        // Live Update (status bar chip + lock screen prominence). The
        // FLAG_PROMOTED_ONGOING bit is the API 36 signal for Live Updates.
        notification.flags = notification.flags or Notification.FLAG_PROMOTED_ONGOING
        return notification
    }

    /// Legacy (< API 36) fallback: the original custom-RemoteViews ongoing
    /// notification posted via NotificationCompat. Unchanged behaviour.
    private fun buildLegacyNotification(
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
''');
  }

  /// Generates one `<Name>TileService.kt` per Mosaic [controls] entry — the
  /// Android Quick Settings tile, which is the closest OS analog to an iOS
  /// Control.
  ///
  /// IMPORTANT: Quick Settings tiles are USER-ADDED. Unlike app widgets (which
  /// can be dropped on the home screen) Android does NOT auto-place a tile — the
  /// user must add it from the Quick Settings edit screen. `TileService`
  /// requires API 24+ (Nougat); the manifest declaration is gated by the host
  /// app's minSdk.
  ///
  /// Each tile reflects/persists state through the SAME shared "widget_data"
  /// SharedPreferences store the app widgets use, and fires its action by
  /// broadcasting `<pkg>.MOSAIC_CALLBACK` with the `callbackName` extra —
  /// mirroring the app-widget callback path so Flutter's backgroundCallback
  /// receives it identically.
  ///
  ///   toggle -> onStartListening reflects the stored bool as the tile state;
  ///             onClick flips the stored bool, updates the tile and fires the
  ///             action.
  ///   button -> a static tile; onClick fires the action (callback broadcast or
  ///             startActivityAndCollapse for a launch-url action).
  Future<void> _generateControlTiles(String projectRoot) async {
    if (controls.isEmpty) return;

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

    for (final control in controls) {
      final name = (control['name'] as String?) ?? 'Control';
      final safe = _safeName(name);
      final className = '${safe}TileService';
      final kind = (control['kind'] as String?) ?? 'button';
      final label = (control['label'] as String?) ?? name;
      final androidIcon = control['androidIcon'] as String?;
      final valueKey = control['valueKey'] as String?;
      final action = (control['action'] as Map?)?.cast<String, dynamic>();

      final file = File(p.join(kotlinDir.path, '$className.kt'));
      await file.writeAsString(_renderTileService(
        className: className,
        kind: kind,
        label: label,
        androidIcon: androidIcon,
        valueKey: valueKey,
        action: action,
      ));
    }
  }

  /// Renders the Kotlin source for a single Quick Settings [TileService].
  String _renderTileService({
    required String className,
    required String kind,
    required String label,
    String? androidIcon,
    String? valueKey,
    Map<String, dynamic>? action,
  }) {
    final labelLit = kotlinEscape(label);
    final isToggle = kind == 'toggle' && valueKey != null;
    final pkg = config.app.androidPackage;

    final iconLine = androidIcon != null
        ? '        qsTile?.icon = Icon.createWithResource(this, R.drawable.${kotlinEscape(androidIcon)})\n'
        : '';

    // onStartListening: label + icon + (toggle) state from the stored bool.
    final stateLine = isToggle
        ? '''
        val on = getSharedPreferences("widget_data", Context.MODE_PRIVATE)
            .getBoolean("${kotlinEscape(valueKey)}", false)
        qsTile?.state = if (on) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE'''
        : '        qsTile?.state = Tile.STATE_INACTIVE';

    // onClick action body. Toggle flips the persisted bool first, then fires
    // the action; button just fires the action.
    final fireAction = _tileActionBody(action, className);
    final clickBody = isToggle
        ? '''
        val prefs = getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        val next = !prefs.getBoolean("${kotlinEscape(valueKey)}", false)
        prefs.edit().putBoolean("${kotlinEscape(valueKey)}", next).apply()
        qsTile?.state = if (next) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        qsTile?.updateTile()
$fireAction'''
        : fireAction;

    return '''$kotlinSentinel
package $pkg.mosaic_generated

import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.Uri
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import $pkg.R

/// Quick Settings tile for the Mosaic control. This is Android's closest analog
/// to an iOS Control. Quick Settings tiles are USER-ADDED — Android does not
/// auto-place them — and require API 24+ (declared in AndroidManifest with the
/// QS_TILE intent-filter + BIND_QUICK_SETTINGS_TILE permission).
///
/// State and actions flow through the shared "widget_data" SharedPreferences
/// store and the `$pkg.MOSAIC_CALLBACK` broadcast, mirroring the app-widget
/// callback path so Flutter's backgroundCallback receives it identically.
class $className : TileService() {
    private val mosaicCallbackAction = "$pkg.MOSAIC_CALLBACK"

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.label = "$labelLit"
$iconLine$stateLine
        qsTile?.updateTile()
    }

    override fun onClick() {
        super.onClick()
$clickBody
    }
}
''';
  }

  /// Builds the onClick action body for a tile: a `MOSAIC_CALLBACK` broadcast
  /// for an `HWActionCallback`, or `startActivityAndCollapse` with an
  /// ACTION_VIEW intent for an `HWLaunchUrlAction`. Mirrors the app-widget
  /// callback path so the same Flutter backgroundCallback handles it.
  String _tileActionBody(Map<String, dynamic>? action, String className) {
    if (action == null) return '        // no action';
    final type = action['__type'];
    if (type == 'HWLaunchUrlAction') {
      final url = kotlinEscape((action['url'] as String?) ?? '');
      return '''
        val launchIntent = Intent(Intent.ACTION_VIEW, Uri.parse("$url")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivityAndCollapse(launchIntent)''';
    }
    // HWActionCallback (default): broadcast the Mosaic callback so Flutter's
    // backgroundCallback receives it exactly as it does for widget buttons.
    final callbackName =
        kotlinEscape((action['callbackName'] as String?) ?? 'refresh_all');
    return '''
        val callbackIntent = Intent(mosaicCallbackAction).apply {
            setPackage(packageName)
            putExtra("callbackName", "$callbackName")
        }
        sendBroadcast(callbackIntent)''';
  }

  /// Generates `MosaicListService.kt` — a single [RemoteViewsService] whose
  /// factory serves EVERY HWListView in the app. The launching widget passes
  /// the bound list key via the `hw_list_key` intent extra; the factory selects
  /// the matching per-row item layout and the field→view-id mapping from a
  /// generated table, reads the JSON rows via `MosaicData.resolveList`, and for
  /// each row inflates the item layout and sets each `hw_item_<field>` TextView
  /// from the row map.
  Future<void> _generateListService(String projectRoot) async {
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

    // when(key) -> R.layout.<itemLayout>
    final layoutCases = _allListViews
        .map((lv) =>
            '            "${kotlinEscape(lv.key)}" -> R.layout.${lv.itemLayout}')
        .join('\n');

    // when(key) -> list of Triple(field, viewId, kind) so the factory knows
    // whether to set text or an image Uri per row.
    final fieldCases = _allListViews.map((lv) {
      final triples = lv.fields
          .map((f) =>
              'Triple("${kotlinEscape(f.field)}", R.id.hw_item_${AndroidGenerator.idForKey(f.field)}, "${f.kind}")')
          .join(', ');
      return '            "${kotlinEscape(lv.key)}" -> listOf($triples)';
    }).join('\n');

    final file = File(p.join(kotlinDir.path, 'MosaicListService.kt'));
    await file.writeAsString('''$kotlinSentinel
package ${config.app.androidPackage}.mosaic_generated

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import ${config.app.androidPackage}.R

/// Shared RemoteViewsService backing every Mosaic HWListView. The widget
/// provider attaches this service as the ListView's remote adapter and passes
/// the bound list key in the "hw_list_key" extra. One service instance serves
/// all lists; the factory dispatches on the key to pick the per-row item
/// layout and the field -> view-id mapping.
class MosaicListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val key = intent.getStringExtra("hw_list_key") ?: ""
        return MosaicListFactory(applicationContext, key)
    }

    companion object {
        /// Resolves the generated per-row item layout for a list [key].
        fun itemLayoutFor(key: String): Int {
            return when (key) {
$layoutCases
                else -> 0
            }
        }

        /// Resolves the ordered (field, viewId, kind) triples the item layout
        /// binds for list [key]. Each field is set per row from the row map;
        /// kind is "text" (setTextViewText) or "image" (setImageViewUri).
        fun fieldsFor(key: String): List<Triple<String, Int, String>> {
            return when (key) {
$fieldCases
                else -> emptyList()
            }
        }
    }
}

class MosaicListFactory(
    private val context: Context,
    private val key: String,
) : RemoteViewsService.RemoteViewsFactory {
    private var rows: List<Map<String, String>> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        rows = MosaicData.resolveList(context, key)
    }

    override fun onDestroy() {
        rows = emptyList()
    }

    override fun getCount(): Int = rows.size

    override fun getViewAt(position: Int): RemoteViews {
        val layout = MosaicListService.itemLayoutFor(key)
        val views = RemoteViews(context.packageName, layout)
        if (position in rows.indices) {
            val row = rows[position]
            for ((field, viewId, kind) in MosaicListService.fieldsFor(key)) {
                val value = row[field] ?: ""
                if (kind == "image") {
                    views.setImageViewUri(viewId, android.net.Uri.parse(value))
                } else {
                    views.setTextViewText(viewId, value)
                }
            }
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
''');
  }
}
