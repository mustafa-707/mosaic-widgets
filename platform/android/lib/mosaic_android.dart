import 'dart:io';
import 'package:mosaic_core/mosaic_core.dart';
import 'package:path/path.dart' as p;

abstract class AndroidNodeHandler {
  String get type;
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  });
}

/// Sentinel placed as the first line of generated XML files so the CLI
/// `clean` command can identify generated artifacts.
const String xmlSentinel = '<!-- MOSAIC-GENERATED -->';

/// Sentinel placed as the first line of generated Kotlin files.
const String kotlinSentinel = '// MOSAIC-GENERATED — do not edit';

/// Builds a single weighted `<Space>` spacer view for a LinearLayout. On a
/// vertical layout the spacer grows on height (0dp + weight); on a horizontal
/// layout it grows on width. Used to approximate Flutter's
/// spaceBetween/spaceAround/spaceEvenly main-axis alignments, which Android's
/// LinearLayout `gravity` cannot express directly.
String _mosaicSpacerView(bool isVertical, {String weight = '1'}) {
  final width = isVertical ? 'wrap_content' : '0dp';
  final height = isVertical ? '0dp' : 'wrap_content';
  return '<Space android:layout_width="$width" android:layout_height="$height" android:layout_weight="$weight" />';
}

/// Maps an [MStack] alignment name to an Android gravity string.
///
/// Uses RTL-friendly `start`/`end` rather than `left`/`right`. Absent or
/// unknown names fall back to `top|start` (matches the DSL default topLeading).
String _stackAlignmentGravity(String? alignment) {
  switch (alignment) {
    case 'topLeading':     return 'top|start';
    case 'top':            return 'top|center_horizontal';
    case 'topTrailing':    return 'top|end';
    case 'leading':        return 'center_vertical|start';
    case 'center':         return 'center';
    case 'trailing':       return 'center_vertical|end';
    case 'bottomLeading':  return 'bottom|start';
    case 'bottom':         return 'bottom|center_horizontal';
    case 'bottomTrailing': return 'bottom|end';
    default:               return 'top|start';
  }
}

/// Injects `android:layout_gravity="[gravity]"` into [renderedChild] if and
/// only if the child's root element does not already carry a `layout_gravity`
/// attribute. This preserves `MPositioned` children which set their own
/// `layout_gravity` via [PositionedHandler].
///
/// Only the FIRST element open-tag is touched — nested descendants are left
/// intact. Children that are pure XML comments are returned unchanged.
String _applyStackAlignment(String renderedChild, String gravity) {
  // If the child already carries layout_gravity, leave it untouched.
  if (renderedChild.contains('android:layout_gravity=')) return renderedChild;
  // Inject just before the first `>` or `/>` that closes the root open tag.
  final re = RegExp(r'(\s*)(\/?>)');
  var done = false;
  return renderedChild.replaceFirstMapped(re, (m) {
    if (done) return m.group(0)!;
    done = true;
    return '${m.group(1)} android:layout_gravity="$gravity"${m.group(2)}';
  });
}

/// Rewrites the cross-axis dimension of a rendered child element to
/// `match_parent` to implement Flutter's `CrossAxisAlignment.stretch`. For a
/// vertical column the cross axis is width; for a horizontal row it is height.
/// Only the FIRST matching attribute is rewritten — that is the child's own
/// root element, leaving any nested descendants untouched. Children that are
/// pure comments (no element) are returned unchanged.
String _applyCrossAxisStretch(String renderedChild, bool isVertical) {
  final attr = isVertical ? 'android:layout_width' : 'android:layout_height';
  final re = RegExp('$attr="[^"]*"');
  if (!re.hasMatch(renderedChild)) return renderedChild;
  var done = false;
  return renderedChild.replaceFirstMapped(re, (m) {
    if (done) return m.group(0)!;
    done = true;
    return '$attr="match_parent"';
  });
}

/// Interleaves [renderedChildren] with weighted spacer views to approximate the
/// given main-axis [alignment] (one of spaceBetween/spaceAround/spaceEvenly).
/// Returns the children list unchanged for any other alignment. The returned
/// list may be prefixed with an approximation comment for spaceAround, whose
/// exact per-child symmetric spacing is not expressible with integer LinearLayout
/// weights — it is approximated with half-weight end spacers.
List<String> _injectMainAxisSpacers(
  List<String> renderedChildren,
  String? alignment,
  bool isVertical,
) {
  if (renderedChildren.isEmpty) return renderedChildren;
  switch (alignment) {
    case 'spaceBetween':
      final out = <String>[];
      for (var i = 0; i < renderedChildren.length; i++) {
        if (i > 0) out.add(_mosaicSpacerView(isVertical));
        out.add(renderedChildren[i]);
      }
      return out;
    case 'spaceEvenly':
      final out = <String>[_mosaicSpacerView(isVertical)];
      for (final c in renderedChildren) {
        out.add(c);
        out.add(_mosaicSpacerView(isVertical));
      }
      return out;
    case 'spaceAround':
      // Exact spaceAround would need half-weight gaps at the ends and
      // full-weight gaps between. Android LinearLayout supports fractional
      // weights, so approximate with weight 0.5 ends and weight 1 between.
      final out = <String>[
        '<!-- spaceAround approximated -->',
        _mosaicSpacerView(isVertical, weight: '0.5'),
      ];
      for (var i = 0; i < renderedChildren.length; i++) {
        if (i > 0) out.add(_mosaicSpacerView(isVertical));
        out.add(renderedChildren[i]);
      }
      out.add(_mosaicSpacerView(isVertical, weight: '0.5'));
      return out;
    default:
      return renderedChildren;
  }
}

class AndroidGenerator {
  final MosaicConfig config;
  final List<IRDefinition> definitions;

  /// Live activity IR collected by the widget runner. Plumbed through for a
  /// later wave; the Android generator does not emit anything from it yet.
  final List<Map<String, dynamic>> liveActivities;

  final Map<String, AndroidNodeHandler> _handlers = {};

  /// Drawable XML files to write under res/drawable, keyed by resource name
  /// (without extension). Populated by handlers during layout generation and
  /// flushed to disk in [generate]. Keyed map ensures identical drawables are
  /// de-duplicated and stable across runs.
  final Map<String, String> _drawables = {};

  /// Registers a drawable XML body (content of the file) under [name] and
  /// returns the resource reference (e.g. `@drawable/hw_bg_3`). The [name]
  /// should be unique per distinct content; callers derive it from a content
  /// hash so identical drawables collapse to one file.
  String registerDrawable(String name, String xml) {
    _drawables[name] = xml;
    return '@drawable/$name';
  }

  /// Adaptive color resources. Keyed by resource name (`mosaic_<hash>`), value
  /// is a record of the light (`#AARRGGBB`) and dark (`#AARRGGBB`) hex strings.
  /// Flushed to `res/values/mosaic_colors.xml` (light) and
  /// `res/values-night/mosaic_colors.xml` (dark) in [generate]. Dedup by name
  /// (callers derive the name from a content hash of light+dark).
  final Map<String, ({String light, String dark})> _colors = {};

  /// Registers an adaptive color with distinct [light] and [dark] `#AARRGGBB`
  /// values and returns the resource reference (`@color/mosaic_<hash>`).
  /// Identical light/dark pairs collapse to one resource.
  String registerColor(String light, String dark) {
    final name = 'mosaic_${_colorHash('$light|$dark')}';
    _colors[name] = (light: light, dark: dark);
    return '@color/$name';
  }

  /// Deterministic non-negative hash used to name color resources.
  String _colorHash(String s) {
    int h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h.toString();
  }

  /// Runtime color binds to resolve+apply in the provider. Each entry records
  /// the layout view id, the SharedPreferences bind key, and the application
  /// target ('text' → setTextColor, 'background' → setInt setBackgroundColor,
  /// 'progress' → setInt setColorFilter on the tint). Populated by handlers
  /// that encounter a bind-form color; flushed in [_generateKotlinProvider].
  final List<
      ({String viewId, String key, String target, double opacity})> _colorBinds = [];

  /// Registers a runtime color bind for [viewId] resolving prefs [key] applied
  /// via [target] ('text' | 'background' | 'progress'). [opacity] (default 1.0)
  /// is applied to the resolved color's alpha channel in the provider; an
  /// opacity of 1.0 leaves the parsed color untouched.
  void registerColorBind(String viewId, String key, String target,
      {double opacity = 1.0}) {
    _colorBinds.add((viewId: viewId, key: key, target: target, opacity: opacity));
  }

  /// Format directive for bound text keys: maps a bind key to its MText
  /// `format` ('decimal'|'currency'|'percent'|'date'|'relativeTime'). When set,
  /// the provider formats the resolved string via `MosaicData.formatValue`
  /// instead of showing it raw. Per-definition (cleared in [generate]).
  final Map<String, String> _textFormats = {};

  /// Records that bound text [key] should be rendered with [format].
  void registerTextFormat(String key, String format) {
    _textFormats[key] = format;
  }

  /// Static file-image URIs to wire up at update time, keyed by the view id
  /// suffix (used to build `R.id.hw_image_<suffix>`). Populated by
  /// [ImageHandler] for non-bound `HWFileImage` paths.
  final Map<String, String> _staticImageUris = {};

  /// Visibility bind keys that also have a `replacement` subtree. For these the
  /// provider toggles two views inversely: the child id (`hw_visibility_<id>`)
  /// and the replacement id (`hw_visibility_<id>_alt`). Keys NOT in this set
  /// keep the legacy single-view GONE behavior.
  final Set<String> _visibilityWithReplacement = {};

  /// Marks a visibility bind [key] as having a replacement subtree so the
  /// provider emits the inverse-toggle logic for both views.
  void registerVisibilityReplacement(String key) {
    _visibilityWithReplacement.add(key);
  }

  /// Timer ids that should count UP rather than down. The provider emits
  /// `setChronometerCountDown(viewId, false)` for these. Count-down is the
  /// default. `RemoteViews.setChronometerCountDown` requires API 24+; on lower
  /// min SDKs the direction is ignored by the platform (the offset still
  /// drives the displayed value).
  final Set<String> _timersCountUp = {};

  /// Marks timer [id] as counting up.
  void registerTimerCountUp(String id) {
    _timersCountUp.add(id);
  }

  /// HWListView collection views discovered while rendering the CURRENT
  /// definition's layout. Each entry records the bound list [key], the
  /// sanitized resource id ([idKey]), the generated per-row item layout
  /// resource name ([itemLayout]) and the ORDERED set of item-template bind
  /// fields ([fields]) that map to `hw_item_<field>` TextViews in that layout.
  /// Populated by [ListViewHandler]; consumed by [_generateKotlinProvider]
  /// (to wire `setRemoteAdapter`) and flushed/cleared per definition.
  final List<
      ({
        String key,
        String idKey,
        String itemLayout,
        List<({String field, String kind})> fields,
      })> _listViews = [];

  /// True while a node tree is being rendered as a list ITEM TEMPLATE rather
  /// than a widget layout. In this mode bound `HWText`/`HWImage` nodes emit a
  /// stable `hw_item_<field>` id (and the field is collected via
  /// [collectItemField]) instead of registering a global SharedPreferences
  /// bind — each row's values are set by the RemoteViewsFactory.
  bool _inItemTemplate = false;
  bool get inItemTemplate => _inItemTemplate;

  /// Ordered item-template bind fields collected during the current
  /// item-template render. Each is `(field, kind)` where kind is 'text' or
  /// 'image'. Order is preserved so the factory maps fields to view ids
  /// deterministically.
  final List<({String field, String kind})> _itemTemplateFields = [];

  /// Records that the current item template binds [field] of [kind]
  /// ('text'|'image') → the view id `hw_item_<idForKey(field)>`. De-duplicated
  /// by field, order preserved.
  void collectItemField(String field, {String kind = 'text'}) {
    if (_itemTemplateFields.any((f) => f.field == field)) return;
    _itemTemplateFields.add((field: field, kind: kind));
  }

  /// Renders [itemTemplate] as a standalone per-row item layout in
  /// item-template mode, registers the discovered list under [key], and
  /// returns the item layout resource name. The generated layout is written by
  /// [generate] from [_pendingItemLayouts].
  String registerListView(String key, IRNode itemTemplate) {
    final idKey = idForKey(key);
    final itemLayout = 'hw_listitem_${_currentSafeName}_$idKey';

    // Render the item template tree in item-template mode so bound fields map
    // to hw_item_<field> view ids instead of global binds. Use throwaway
    // accumulators — item rows are populated by the factory, not the provider.
    final savedInItem = _inItemTemplate;
    final savedFields =
        List<({String field, String kind})>.from(_itemTemplateFields);
    _inItemTemplate = true;
    _itemTemplateFields.clear();
    final throwBinds = <String, String>{};
    final throwVis = <String>[];
    final throwTimers = <String, String>{};
    final throwButtons = <Map<String, dynamic>>[];
    String body;
    List<({String field, String kind})> fields;
    try {
      body = nodeToXml(
        itemTemplate,
        throwBinds,
        throwVis,
        throwTimers,
        throwButtons,
        isRoot: true,
      );
      fields = List<({String field, String kind})>.from(_itemTemplateFields);
    } finally {
      _inItemTemplate = savedInItem;
      _itemTemplateFields
        ..clear()
        ..addAll(savedFields);
    }

    final xml = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="utf-8"?>')
      ..writeln(xmlSentinel)
      ..write(body);
    _pendingItemLayouts[itemLayout] = xml.toString();

    final descriptor = (
      key: key,
      idKey: idKey,
      itemLayout: itemLayout,
      fields: fields,
    );
    _listViews.add(descriptor);
    _allListViews.add(descriptor);
    return idKey;
  }

  /// Per-row item layout XML keyed by resource name, flushed to res/layout in
  /// [generate]. Filled by [registerListView].
  final Map<String, String> _pendingItemLayouts = {};

  /// Sanitized lowercase name of the definition currently being generated.
  /// Used to namespace per-row item layout resource files.
  String _currentSafeName = '';

  /// True once any definition has declared at least one HWListView, gating
  /// generation of the shared `MosaicListService.kt`.
  bool _anyListView = false;

  /// Every list discovered across ALL definitions, keyed by [idKey] (which is
  /// unique because the item layout name embeds the widget name). The shared
  /// RemoteViewsService dispatches on the `hw_list_key` intent extra to select
  /// the matching item layout + fields at runtime.
  final List<
      ({
        String key,
        String idKey,
        String itemLayout,
        List<({String field, String kind})> fields,
      })> _allListViews = [];

  /// Registers a static file image URI for [viewSuffix] and returns the
  /// matching view id suffix so the handler can emit the layout id.
  void registerStaticImageUri(String viewSuffix, String uri) {
    _staticImageUris[viewSuffix] = uri;
  }

  /// Returns a sanitized identifier safe for use as a Kotlin class name or
  /// Android resource name component.
  String _safeName(String n) => sanitizeIdentifier(n);

  /// Sanitizes a bind [key] so it is safe to embed in an Android resource id
  /// (`hw_<kind>_<id>`). Used for BOTH the layout `@+id/...` and the matching
  /// `R.id....` reference in the Kotlin provider so they stay consistent. The
  /// SharedPreferences lookup key passed to `MosaicData.resolve*` must remain
  /// the ORIGINAL key — only the resource id is sanitized.
  static String idForKey(String key) => sanitizeIdentifier(key);

  AndroidGenerator({
    required this.config,
    required this.definitions,
    this.liveActivities = const [],
  }) {
    _registerHandlers();
  }

  void _registerHandlers() {
    _register(ColumnHandler());
    _register(RowHandler());
    _register(TextHandler());
    _register(ContainerHandler());
    _register(PaddingHandler());
    _register(StackHandler());
    _register(SpacerHandler());
    _register(ButtonHandler());
    _register(VisibilityHandler());
    _register(ImageHandler());
    _register(ProgressBarHandler());
    _register(ListViewHandler());
    _register(TimerHandler());
    _register(PositionedHandler());
    _register(CenterHandler());
    _register(DividerHandler());
    _register(IconHandler());
    _register(GaugeHandler());
    _register(BadgeHandler());
  }

  void _register(AndroidNodeHandler handler) {
    _handlers[handler.type] = handler;
  }

  Future<void> generate(String projectRoot) async {
    final lower =
        definitions.map((d) => _safeName(d.name).toLowerCase()).toList();
    if (lower.toSet().length != lower.length) {
      throw StateError('Widget name collision after sanitization: $lower');
    }

    final resDir = Directory(
      p.join(projectRoot, 'android', 'app', 'src', 'main', 'res'),
    );
    final layoutDir = Directory(p.join(resDir.path, 'layout'));
    final xmlDir = Directory(p.join(resDir.path, 'xml'));

    if (!layoutDir.existsSync()) layoutDir.createSync(recursive: true);
    if (!xmlDir.existsSync()) xmlDir.createSync(recursive: true);

    _anyListView = false;
    _allListViews.clear();

    for (final def in definitions) {
      final safe = _safeName(def.name);
      final layoutName = 'hw_${safe.toLowerCase()}';
      final layoutFile = File(p.join(layoutDir.path, '$layoutName.xml'));

      final usedBinds = <String, String>{};
      final visibilityKeys = <String>[];
      final timers = <String, String>{};
      final buttons = <Map<String, dynamic>>[];
      _staticImageUris.clear();
      _visibilityWithReplacement.clear();
      _timersCountUp.clear();
      _colorBinds.clear();
      _textFormats.clear();
      _listViews.clear();
      _pendingItemLayouts.clear();
      _currentSafeName = safe.toLowerCase();

      final layoutXml = _generateLayoutXml(
        def.root,
        usedBinds,
        visibilityKeys,
        timers,
        buttons,
      );
      await layoutFile.writeAsString(layoutXml);

      // Flush any per-row item layouts discovered while rendering HWListViews.
      for (final entry in _pendingItemLayouts.entries) {
        await File(p.join(layoutDir.path, '${entry.key}.xml'))
            .writeAsString(entry.value);
      }

      final infoFile = File(p.join(xmlDir.path, '${layoutName}_info.xml'));
      await infoFile.writeAsString(_generateInfoXml(def));

      await _generateKotlinProvider(
        projectRoot,
        def,
        safe,
        usedBinds,
        visibilityKeys,
        timers,
        buttons,
      );

      // Configurable widgets (definition carries params) get a config Activity
      // that writes the chosen values into the shared "widget_data" store.
      if (def.params.isNotEmpty) {
        await _generateConfigActivity(projectRoot, def, safe);
      }

      // The shared RemoteViewsService is regenerated whenever ANY definition
      // contains at least one list. It is keyed by the list key passed via the
      // launch intent, so a single service serves every list/widget.
      if (_listViews.isNotEmpty) _anyListView = true;
    }

    if (_anyListView) await _generateListService(projectRoot);

    await _generateLiveActivityLayouts(layoutDir);
    await _generateLiveActivityManager(projectRoot);

    await _writeDrawables(resDir);
    await _writeColors(resDir);

    await _generateBridgeHelper(projectRoot);
    await _generateMosaicData(projectRoot);
  }

  /// Generates one custom notification layout per live activity from its
  /// `lockScreen` node tree, written to `res/layout/hw_la_<name>.xml`.
  ///
  /// Android has no Dynamic Island or lock-screen Live Activity; a live
  /// activity is mapped to an ongoing notification whose content is a
  /// RemoteViews built from this layout. The `lockScreen` tree is rendered with
  /// the SAME node handlers used for app-widget layouts, so binds resolve at
  /// runtime through the shared `MosaicData` "widget_data" store. The
  /// `dynamicIsland` payload is intentionally ignored on Android.
  Future<void> _generateLiveActivityLayouts(Directory layoutDir) async {
    if (liveActivities.isEmpty) return;
    if (!layoutDir.existsSync()) layoutDir.createSync(recursive: true);

    for (final la in liveActivities) {
      final name = (la['name'] as String?) ?? 'live_activity';
      final lockScreen = la['lockScreen'];
      if (lockScreen == null) continue;

      final layoutName = 'hw_la_${_safeName(name).toLowerCase()}';
      final layoutFile = File(p.join(layoutDir.path, '$layoutName.xml'));

      // Reset per-layout accumulators (same lifecycle as widget layouts). The
      // ongoing-notification RemoteViews is built by the manager (Unit 2); only
      // the layout XML is needed here, so the collected metadata is local.
      final usedBinds = <String, String>{};
      final visibilityKeys = <String>[];
      final timers = <String, String>{};
      final buttons = <Map<String, dynamic>>[];
      _staticImageUris.clear();
      _visibilityWithReplacement.clear();
      _timersCountUp.clear();
      _colorBinds.clear();
      _textFormats.clear();

      final node = IRNode.fromJson((lockScreen as Map).cast<String, dynamic>());
      final layoutXml = _generateLayoutXml(
        node,
        usedBinds,
        visibilityKeys,
        timers,
        buttons,
      );
      await layoutFile.writeAsString(layoutXml);
    }
  }

  /// Generates `MosaicLiveActivityManager.kt`, the runtime helper that maps a
  /// Mosaic live activity to an ONGOING NOTIFICATION (Android's best-effort
  /// fallback — it is NOT a true Live Activity and has no Dynamic Island).
  ///
  /// `start`/`update` write the supplied data into the shared "widget_data"
  /// SharedPreferences store (the same store `MosaicData` reads), build a
  /// RemoteViews from the matching `hw_la_<type>` layout, and post/refresh an
  /// ongoing notification on the "mosaic_live_activities" channel. `end`
  /// cancels it. `enabled` reports whether notifications are permitted and
  /// `active` returns the best-effort set of posted ids.
  ///
  /// POST_NOTIFICATIONS (API 33+) is assumed already granted by the host app.
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
        })
        .join('\n');

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
''');
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
              'Triple("${kotlinEscape(f.field)}", R.id.hw_item_${idForKey(f.field)}, "${f.kind}")')
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

  Future<void> _writeDrawables(Directory resDir) async {
    if (_drawables.isEmpty) return;
    final drawableDir = Directory(p.join(resDir.path, 'drawable'));
    if (!drawableDir.existsSync()) drawableDir.createSync(recursive: true);
    for (final entry in _drawables.entries) {
      final file = File(p.join(drawableDir.path, '${entry.key}.xml'));
      await file.writeAsString(entry.value);
    }
  }

  /// Writes the adaptive color resources to `res/values/mosaic_colors.xml`
  /// (light) and `res/values-night/mosaic_colors.xml` (dark). Both files lead
  /// with the XML declaration (AAPT requirement) then the generated sentinel.
  Future<void> _writeColors(Directory resDir) async {
    if (_colors.isEmpty) return;
    final entries = _colors.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    String buildFile(bool night) {
      final body = entries
          .map((e) =>
              '    <color name="${e.key}">${night ? e.value.dark : e.value.light}</color>')
          .join('\n');
      return '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<resources>
$body
</resources>''';
    }

    final valuesDir = Directory(p.join(resDir.path, 'values'));
    final nightDir = Directory(p.join(resDir.path, 'values-night'));
    if (!valuesDir.existsSync()) valuesDir.createSync(recursive: true);
    if (!nightDir.existsSync()) nightDir.createSync(recursive: true);

    await File(p.join(valuesDir.path, 'mosaic_colors.xml'))
        .writeAsString(buildFile(false));
    await File(p.join(nightDir.path, 'mosaic_colors.xml'))
        .writeAsString(buildFile(true));
  }

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

    final providerClasses = definitions
        .map((d) => '${_safeName(d.name)}Provider')
        .toList();
    final refreshAllLogic = providerClasses
        .map(
          (cls) =>
              '''
        context.sendBroadcast(android.content.Intent(context, $cls::class.java).apply {
            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = android.appwidget.AppWidgetManager.getInstance(context)
                .getAppWidgetIds(android.content.ComponentName(context, $cls::class.java))
            putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        })''',
        )
        .join('\n');

    final refreshSpecificLogic = definitions
        .map(
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
        )
        .join('\n');

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

  String _generateLayoutXml(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
  ) {
    final buffer = StringBuffer();
    // The XML declaration MUST be the very first bytes of the file or AAPT
    // rejects it ("processing instruction target matching xml is not allowed").
    buffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
    buffer.writeln(xmlSentinel);
    // Root element should always be match_parent to fill the widget cell
    buffer.write(
      nodeToXml(node, usedBinds, visibilityKeys, timers, buttons, isRoot: true),
    );
    return buffer.toString();
  }

  /// True when [colorData] is the runtime bind form `{'bind': '<key>', ...}`
  /// (non-null 'bind'). Such colors carry no static 'hex' — the real color is
  /// resolved and applied by the provider at update time, and the static path
  /// must emit a neutral placeholder.
  bool isColorBind(Map colorData) => colorData['bind'] != null;

  /// Applies [opacity] to a `#RRGGBB`/`#AARRGGBB` hex. Returns the bare
  /// `#RRGGBB` unchanged when [opacity] is 1.0 (matching the legacy inline
  /// path); otherwise returns `#AARRGGBB` with the computed alpha.
  String _applyOpacity(String hex, double opacity) {
    if (!hex.startsWith('#')) hex = '#$hex';
    // Strip any existing alpha to the 6-digit RGB.
    String rgb = hex.substring(1);
    if (rgb.length == 8) rgb = rgb.substring(2);
    if (opacity >= 1.0) return '#$rgb';
    final alpha = (opacity * 255).toInt().clamp(0, 255);
    final alphaHex = alpha.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#$alphaHex$rgb';
  }

  /// Resolves a color wire map to an Android color token usable in res XML:
  /// either an inline `#AARRGGBB` (static, no dark variant) or a
  /// `@color/mosaic_<hash>` reference (adaptive: dark variant present).
  ///
  /// Tolerates ALL canonical forms:
  /// - static/adaptive: `{'hex': '<light>', 'dark': '<dark|null>', 'opacity': d}`
  /// - bind: `{'bind': '<key>', 'opacity': d}` (no 'hex') → returns a neutral
  ///   transparent placeholder; the provider sets the real color at runtime.
  String parseColor(Map<String, dynamic> colorData) {
    // Bind form has no static color: emit a transparent placeholder. The
    // provider's bind loop overrides this with the resolved color at update.
    if (isColorBind(colorData)) return '#00000000';

    final double opacity = (colorData['opacity'] ?? 1.0).toDouble();
    final String hex = (colorData['hex'] as String?) ?? '#FFFFFF';
    final light = _applyOpacity(hex, opacity);

    final dark = colorData['dark'] as String?;
    if (dark != null) {
      // Adaptive: allocate a day/night color resource and reference it.
      return registerColor(light, _applyOpacity(dark, opacity));
    }
    return light;
  }

  String nodeToXml(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
    bool isRoot = false,
  }) {
    final handler = _handlers[node.type];
    if (handler != null) {
      String xml = handler.handle(
        node,
        usedBinds,
        visibilityKeys,
        timers,
        buttons,
        this,
        isInsideLinearLayout: isInsideLinearLayout,
        isVertical: isVertical,
      );

      if (isRoot) {
        return '''
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">
    $xml
</FrameLayout>''';
      }
      return xml;
    }
    throw UnsupportedError('No Android handler for node type "${node.type}".');
  }

  String _generateInfoXml(IRDefinition def) {
    // Use a more generous sizing formula to avoid "half-cell" issues
    final minWidth = (def.width * 72) - 1;
    final minHeight = (def.height * 72) - 1;
    String mode = def.resizeMode;
    if (mode == 'both') mode = 'horizontal|vertical';
    final resizeMode = mode != 'none' ? ' android:resizeMode="$mode"' : '';
    final preview = def.previewImage != null
        ? ' android:previewImage="@drawable/${def.previewImage}"'
        : '';

    // Configurable widgets bind a configuration Activity launched by the OS
    // after the widget is dropped on the home screen.
    final configure = def.params.isNotEmpty
        ? ' android:configure="${config.app.androidPackage}.mosaic_generated.${_safeName(def.name)}ConfigActivity"'
        : '';

    final period = def.updateInterval == null
        ? 0
        : (def.updateInterval! < 1800000 ? 1800000 : def.updateInterval!);
    return '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="${minWidth}dp"
    android:minHeight="${minHeight}dp"
    android:updatePeriodMillis="$period"
    android:initialLayout="@layout/hw_${_safeName(def.name).toLowerCase()}"
    $resizeMode
    $preview$configure>
</appwidget-provider>''';
  }

  Future<void> _generateKotlinProvider(
    String projectRoot,
    IRDefinition def,
    String safe,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
  ) async {
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

    final className = '${safe}Provider';
    final file = File(p.join(kotlinDir.path, '$className.kt'));

    final bindLogic = usedBinds.entries
        .map((entry) {
          final key = entry.key;
          final id = idForKey(key);
          final lit = kotlinEscape(key);
          final type = entry.value;
          switch (type) {
            case 'progress':
              return 'views.setProgressBar(R.id.hw_progress_$id, 100, MosaicData.resolveDouble(context, "$lit").toInt(), false)';
            case 'image':
              return 'views.setImageViewUri(R.id.hw_image_$id, android.net.Uri.parse(MosaicData.resolveString(context, "$lit", "")))';
            case 'text':
            default:
              final format = _textFormats[key];
              if (format != null) {
                // Formatted bound text: resolve the raw string then format it
                // with the device default Locale via MosaicData.formatValue.
                return 'views.setTextViewText(R.id.hw_text_$id, MosaicData.formatValue(MosaicData.resolveString(context, "$lit"), "$format"))';
              }
              return 'views.setTextViewText(R.id.hw_text_$id, MosaicData.resolveString(context, "$lit"))';
          }
        })
        .join('\n        ');

    final timerLogic = timers.entries
        .map((entry) {
          final id = entry.key;
          final targetEpoch = entry.value;
          // Count direction: count-down by default; count-up when registered.
          // setChronometerCountDown requires API 24+; ignored on lower SDKs.
          final countDown = !_timersCountUp.contains(id);
          // Count-down: base = elapsedRealtime + offset (future target, ticks
          // toward 0). Count-up: base = elapsedRealtime - offset (past target,
          // ticks up from 0 / elapsed since target).
          final baseSign = countDown ? '+' : '-';
          return '''
        val target$id = ${targetEpoch}L
        val offset$id = target$id - System.currentTimeMillis()
        views.setChronometer(R.id.hw_timer_$id, android.os.SystemClock.elapsedRealtime() $baseSign offset$id, null, true)
        views.setChronometerCountDown(R.id.hw_timer_$id, $countDown)
      ''';
        })
        .join('\n        ');

    final visibilityLogic = visibilityKeys
        .map(
          (key) {
            final id = idForKey(key);
            final lit = kotlinEscape(key);
            final base =
                'views.setViewVisibility(R.id.hw_visibility_$id, if (MosaicData.resolveBool(context, "$lit")) android.view.View.VISIBLE else android.view.View.GONE)';
            if (!_visibilityWithReplacement.contains(key)) return base;
            // Replacement present: toggle the child and the replacement (_alt)
            // inversely so exactly one is shown.
            final alt =
                'views.setViewVisibility(R.id.hw_visibility_${id}_alt, if (MosaicData.resolveBool(context, "$lit")) android.view.View.GONE else android.view.View.VISIBLE)';
            return '$base\n        $alt';
          },
        )
        .join('\n        ');

    final staticImageLogic = _staticImageUris.entries
        .map(
          (e) =>
              'views.setImageViewUri(R.id.hw_image_${e.key}, android.net.Uri.parse("${kotlinEscape(e.value)}"))',
        )
        .join('\n        ');

    // Runtime color binds: resolve a hex string from prefs, parse to an int
    // color and apply via the appropriate RemoteViews call. Parse failures are
    // swallowed (try/catch) so a bad value just leaves the placeholder.
    final colorBindLogic = _colorBinds
        .asMap()
        .entries
        .map((e) {
          final i = e.key;
          final cb = e.value;
          final lit = kotlinEscape(cb.key);
          // Bind-form colors may carry an opacity (<1.0); apply it to the
          // parsed color's alpha channel. Opacity 1.0 leaves the color as-is.
          final String colorVar;
          final String opacityLine;
          if (cb.opacity < 1.0) {
            final alpha = (cb.opacity * 255).toInt().clamp(0, 255);
            opacityLine =
                '\n            val c$i = (cRaw$i and 0x00FFFFFF.toInt()) or ($alpha shl 24)';
            colorVar = 'c$i';
          } else {
            opacityLine = '';
            colorVar = 'cRaw$i';
          }
          final apply = switch (cb.target) {
            'background' =>
              'views.setInt(R.id.${cb.viewId}, "setBackgroundColor", $colorVar)',
            'progress' =>
              'views.setInt(R.id.${cb.viewId}, "setColorFilter", $colorVar)',
            _ => 'views.setTextColor(R.id.${cb.viewId}, $colorVar)',
          };
          return '''
        try {
            val cRaw$i = android.graphics.Color.parseColor(MosaicData.resolveString(context, "$lit"))$opacityLine
            $apply
        } catch (e: Exception) { }''';
        })
        .join('\n        ');

    // RemoteViews collection wiring: for each HWListView in this definition,
    // build an Intent at the shared MosaicListService carrying the list key,
    // attach it as the ListView's remote adapter, and notify the data set so
    // the factory re-reads MosaicData.resolveList. A unique data Uri per
    // (widget, list) prevents Android from collapsing distinct intents.
    final listAdapterLogic = _listViews
        .map((lv) {
          final lit = kotlinEscape(lv.key);
          return '''
        val listIntent_${lv.idKey} = android.content.Intent(context, MosaicListService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            putExtra("hw_list_key", "$lit")
            data = android.net.Uri.parse("mosaic://list/" + appWidgetId + "/$lit")
        }
        views.setRemoteAdapter(R.id.hw_list_${lv.idKey}, listIntent_${lv.idKey})
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.hw_list_${lv.idKey})''';
        })
        .join('\n        ');

    final buttonLogic = buttons
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final action = entry.value;
          final viewId = index == 0 ? "hw_button_main" : "hw_button_$index";

          if (action['__type'] == 'HWLaunchUrlAction') {
            final url = kotlinEscape(action['url'] as String);
            return '''
        val intent$index = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse("$url"))
        val pendingIntent$index = android.app.PendingIntent.getActivity(context, appWidgetId * 100 + $index, intent$index, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.$viewId, pendingIntent$index)
        ''';
          } else if (action['__type'] == 'HWActionCallback') {
            final callbackName = kotlinEscape(action['callbackName'] as String);
            return '''
        val intent$index = android.content.Intent(context, $className::class.java).apply {
            action = mosaicCallbackAction
            putExtra("callbackName", "$callbackName")
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val pendingIntent$index = android.app.PendingIntent.getBroadcast(context, appWidgetId * 100 + $index, intent$index, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.$viewId, pendingIntent$index)
        ''';
          } else {
            return '''
        val intent$index = android.content.Intent(context, $className::class.java).apply {
            action = mosaicCallbackAction
            putExtra("callbackName", "refresh_all")
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val pendingIntent$index = android.app.PendingIntent.getBroadcast(context, appWidgetId * 100 + $index, intent$index, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.$viewId, pendingIntent$index)
        ''';
          }
        })
        .join('\n        ');

    await file.writeAsString('''$kotlinSentinel
package ${config.app.androidPackage}.mosaic_generated

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import ${config.app.androidPackage}.R

class $className : AppWidgetProvider() {
    private val mosaicCallbackAction = "${config.app.androidPackage}.MOSAIC_CALLBACK"

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
        if (intent.action == mosaicCallbackAction) {
            val callbackName = intent.getStringExtra("callbackName")
            if (callbackName == "refresh_all") {
                HomeWidgetBridgeHelper.refreshAll(context)
            }
            // Future: Notify Flutter background engine here
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        ${def.updateInterval != null ? '''
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val intent = android.content.Intent(context, $className::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val pendingIntent = android.app.PendingIntent.getBroadcast(context, 0, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        alarmManager.setRepeating(android.app.AlarmManager.RTC, System.currentTimeMillis(), ${def.updateInterval}, pendingIntent)
        ''' : ''}
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, R.layout.hw_${safe.toLowerCase()})
        
        $bindLogic
        $timerLogic
        $visibilityLogic
        $staticImageLogic
        $colorBindLogic
        $listAdapterLogic
        $buttonLogic

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
''');
  }

  /// Generates `<Name>ConfigActivity.kt` for a definition that carries
  /// [IRDefinition.params]. The activity is the standard App Widget
  /// configuration Activity (declared in the manifest with the
  /// `APPWIDGET_CONFIGURE` action and referenced from the info XML via
  /// `android:configure`).
  ///
  /// It builds a simple vertical [LinearLayout] in code (no XML layout — keeps
  /// AAPT processing trivial) with one input control per param:
  ///   text   -> EditText
  ///   number -> EditText with InputType numeric flags
  ///   toggle -> Switch
  ///   choice -> Spinner over the declared choices
  /// Each control is pre-filled from any previously-saved value in
  /// "widget_data" falling back to the param's defaultValue. On "Save" each
  /// value is written back into "widget_data" under the param `key` as a
  /// String (so the existing [MosaicData] bind resolution renders it), the
  /// activity result is set to RESULT_OK carrying EXTRA_APPWIDGET_ID, the
  /// widget is updated by re-running the provider's update path, and the
  /// activity finishes. The default result is RESULT_CANCELED per contract.
  Future<void> _generateConfigActivity(
    String projectRoot,
    IRDefinition def,
    String safe,
  ) async {
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

    final className = '${safe}ConfigActivity';
    final providerClass = '${safe}Provider';
    final file = File(p.join(kotlinDir.path, '$className.kt'));

    // Build the per-param control-construction, pre-fill and save logic. Each
    // param gets a stable Kotlin field name `field<i>` and a label TextView.
    final buildBuf = StringBuffer();
    final saveBuf = StringBuffer();

    for (var i = 0; i < def.params.length; i++) {
      final param = def.params[i];
      final key = (param['key'] as String?) ?? 'param$i';
      final label = (param['label'] as String?) ?? key;
      final type = (param['type'] as String?) ?? 'text';
      final defaultValue = param['defaultValue'];
      final defaultLit = kotlinEscape(defaultValue?.toString() ?? '');
      final keyLit = kotlinEscape(key);
      final labelLit = kotlinEscape(label);
      final fieldName = 'field$i';

      // Common: a label above the control.
      buildBuf.writeln('''
        layout.addView(TextView(this).apply { text = "$labelLit" })
        val saved$i = prefs.getString("$keyLit", "$defaultLit") ?: "$defaultLit"''');

      switch (type) {
        case 'toggle':
          buildBuf.writeln('''
        val $fieldName = Switch(this).apply {
            isChecked = saved$i.trim().lowercase() in setOf("true", "1", "yes")
        }
        layout.addView($fieldName)''');
          saveBuf.writeln(
            '        editor.putString("$keyLit", if ($fieldName.isChecked) "true" else "false")',
          );
          break;
        case 'choice':
          final choices =
              (param['choices'] as List?)?.cast<dynamic>() ?? const [];
          final choiceLits =
              choices.map((c) => '"${kotlinEscape(c.toString())}"').join(', ');
          buildBuf.writeln('''
        val choices$i = listOf<String>($choiceLits)
        val $fieldName = Spinner(this).apply {
            adapter = ArrayAdapter(
                this@$className,
                android.R.layout.simple_spinner_dropdown_item,
                choices$i,
            )
            val idx$i = choices$i.indexOf(saved$i)
            if (idx$i >= 0) setSelection(idx$i)
        }
        layout.addView($fieldName)''');
          saveBuf.writeln(
            '        editor.putString("$keyLit", $fieldName.selectedItem?.toString() ?: "")',
          );
          break;
        case 'number':
          buildBuf.writeln('''
        val $fieldName = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL or InputType.TYPE_NUMBER_FLAG_SIGNED
            setText(saved$i)
        }
        layout.addView($fieldName)''');
          saveBuf.writeln(
            '        editor.putString("$keyLit", $fieldName.text.toString())',
          );
          break;
        case 'text':
        default:
          buildBuf.writeln('''
        val $fieldName = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_TEXT
            setText(saved$i)
        }
        layout.addView($fieldName)''');
          saveBuf.writeln(
            '        editor.putString("$keyLit", $fieldName.text.toString())',
          );
          break;
      }
    }

    await file.writeAsString('''$kotlinSentinel
package ${config.app.androidPackage}.mosaic_generated

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.Switch
import android.widget.TextView
import ${config.app.androidPackage}.R

/// Configuration Activity for the "${def.name}" widget. Launched by the OS via
/// the APPWIDGET_CONFIGURE action after the widget is placed. Persists the
/// chosen param values into the shared "widget_data" SharedPreferences store
/// (the same store [MosaicData] reads) and triggers a widget update.
class $className : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    private fun prefs(): android.content.SharedPreferences =
        getSharedPreferences("widget_data", Context.MODE_PRIVATE)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Per the config-activity contract the default result is CANCELED so
        // that backing out leaves no widget placed.
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val prefs = prefs()

        // Build the UI programmatically (no XML layout) to keep AAPT simple.
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }

$buildBuf
        val saveButton = Button(this).apply { text = "Save" }
        saveButton.setOnClickListener {
            val editor = prefs.edit()
$saveBuf
            editor.apply()

            // Update the widget by re-running the provider's update path.
            val appWidgetManager = AppWidgetManager.getInstance(this)
            val provider = $providerClass()
            provider.onUpdate(this, appWidgetManager, intArrayOf(appWidgetId))

            // Also broadcast an update so any other instances refresh.
            sendBroadcast(Intent(this, $providerClass::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_IDS,
                    appWidgetManager.getAppWidgetIds(
                        ComponentName(this@$className, $providerClass::class.java),
                    ),
                )
            })

            val resultValue = Intent().apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            setResult(RESULT_OK, resultValue)
            finish()
        }
        layout.addView(saveButton)

        val scroll = ScrollView(this).apply { addView(layout) }
        setContentView(scroll)
    }
}
''');
  }
}

class ColumnHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWColumn';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final children = ((node.data['children'] as List?) ?? const [])
        .map((e) => IRNode.fromJson(e as Map<String, dynamic>))
        .toList();
    final mainAxis = node.data['mainAxisAlignment'] as String?;
    final crossAxis = node.data['crossAxisAlignment'] as String?;
    final gravity = _mapGravity(
      mainAxis,
      crossAxis,
    );
    var rendered = children
        .map((c) => context.nodeToXml(c, usedBinds, visibilityKeys, timers,
            buttons,
            isInsideLinearLayout: true, isVertical: true))
        .toList();
    if (crossAxis == 'stretch') {
      rendered = rendered.map((c) => _applyCrossAxisStretch(c, true)).toList();
    }
    final withSpacers = _injectMainAxisSpacers(rendered, mainAxis, true);
    return '''
<LinearLayout
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:gravity="$gravity">
    ${withSpacers.join('\n')}
</LinearLayout>''';
  }

  String _mapGravity(String? main, String? cross) {
    String g = '';
    if (main == 'center') {
      g += 'center_vertical';
    } else if (main == 'end')
      g += 'bottom';
    else
      g += 'top';

    g += '|';

    if (cross == 'center') {
      g += 'center_horizontal';
    } else if (cross == 'end')
      g += 'end';
    else
      g += 'start';

    return g;
  }
}

class RowHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWRow';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final children = ((node.data['children'] as List?) ?? const [])
        .map((e) => IRNode.fromJson(e as Map<String, dynamic>))
        .toList();
    final mainAxis = node.data['mainAxisAlignment'] as String?;
    final crossAxis = node.data['crossAxisAlignment'] as String?;
    final gravity = _mapGravity(
      mainAxis,
      crossAxis,
    );
    var rendered = children
        .map((c) => context.nodeToXml(c, usedBinds, visibilityKeys, timers,
            buttons,
            isInsideLinearLayout: true, isVertical: false))
        .toList();
    if (crossAxis == 'stretch') {
      rendered = rendered.map((c) => _applyCrossAxisStretch(c, false)).toList();
    }
    final withSpacers = _injectMainAxisSpacers(rendered, mainAxis, false);
    return '''
<LinearLayout
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="horizontal"
    android:gravity="$gravity">
    ${withSpacers.join('\n')}
</LinearLayout>''';
  }

  String _mapGravity(String? main, String? cross) {
    String g = '';
    if (main == 'center') {
      g += 'center_horizontal';
    } else if (main == 'end')
      g += 'end';
    else
      g += 'start';

    g += '|';

    if (cross == 'center') {
      g += 'center_vertical';
    } else if (cross == 'end')
      g += 'bottom';
    else
      g += 'top';

    return g;
  }
}

class TextHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWText';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final text = node.data['text'];
    final isBind = text is Map && text['__type'] == 'HWBind';
    String idAttr = '';
    String textValue = '';
    if (isBind && context.inItemTemplate) {
      // Inside a list item template the bound field is set PER ROW by the
      // RemoteViewsFactory, not by the provider, so use a stable per-field id
      // and collect the field rather than registering a global bind.
      final key = text['key'] as String;
      context.collectItemField(key);
      idAttr = 'android:id="@+id/hw_item_${AndroidGenerator.idForKey(key)}"';
    } else if (isBind) {
      final key = text['key'] as String;
      usedBinds[key] = 'text';
      idAttr = 'android:id="@+id/hw_text_${AndroidGenerator.idForKey(key)}"';
      // Bound text may carry a format directive applied at render time.
      final format = node.data['format'] as String?;
      if (format != null) context.registerTextFormat(key, format);
    } else {
      textValue = text.toString();
    }
    final colorData = node.data['style']?['color'] ?? {'hex': '#FFFFFF'};
    final color = context.parseColor(
      (colorData as Map).cast<String, dynamic>(),
    );
    final size = node.data['style']?['size'] ?? 14;
    final style = node.data['style']?['bold'] == true ? 'bold' : 'normal';
    // Standalone opacity applies to the whole view regardless of color alpha.
    final opacity = node.data['style']?['opacity'];
    final alphaAttr =
        opacity != null ? ' android:alpha="$opacity"' : '';

    // maxLines: clamp the line count and ellipsize the overflow with "...".
    final maxLines = node.data['maxLines'];
    final maxLinesAttr = maxLines != null
        ? ' android:maxLines="$maxLines" android:ellipsize="end"'
        : '';

    // align: map the logical MTextAlign to BOTH gravity (pre-API-17 / layout
    // positioning) and textAlignment (RTL-aware, API 17+). start->viewStart,
    // center->center, end->viewEnd.
    final align = node.data['align'] as String?;
    String alignAttr = '';
    if (align != null) {
      final gravity = switch (align) {
        'center' => 'center',
        'end' => 'end',
        _ => 'start',
      };
      final textAlignment = switch (align) {
        'center' => 'center',
        'end' => 'viewEnd',
        _ => 'viewStart',
      };
      alignAttr =
          ' android:gravity="$gravity" android:textAlignment="$textAlignment"';
    }

    // Bind-form text color: the TextView needs a stable id so the provider can
    // resolve+apply the color at update. Reuse the text bind id when present;
    // otherwise allocate a color-bind id.
    if (context.isColorBind(colorData)) {
      final colorKey = colorData['bind'] as String;
      String viewId;
      if (isBind) {
        viewId = 'hw_text_${AndroidGenerator.idForKey(text['key'] as String)}';
      } else {
        viewId = 'hw_textcolor_${AndroidGenerator.idForKey(colorKey)}';
        idAttr = 'android:id="@+id/$viewId"';
      }
      context.registerColorBind(viewId, colorKey, 'text',
          opacity: (colorData['opacity'] ?? 1.0).toDouble());
    }

    return '<TextView $idAttr android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="${xmlEscape(textValue)}" android:textColor="$color" android:textSize="${size}sp" android:textStyle="$style"$alphaAttr$maxLinesAttr$alignAttr />';
  }
}

class ContainerHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWContainer';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final childJson = node.data['child'];
    if (childJson == null) return '<!-- missing child -->';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final backgroundMap = node.data['background'] as Map?;
    final isBgBind =
        backgroundMap != null && context.isColorBind(backgroundMap);
    // A non-bind background is "present" only if it carries a static color.
    final background = (backgroundMap != null && !isBgBind)
        ? backgroundMap['hex']
        : null;
    final gradient = node.data['gradient'];
    final border = node.data['border'];
    final radius = (node.data['radius'] ?? 0).toDouble();
    // Per-corner radii take precedence over the scalar radius when present.
    final cornersData = node.data['corners'] as Map?;
    final widthVal = node.data['width'];
    final heightVal = node.data['height'];

    // Shadow is unsupported by RemoteViews/AppWidgets (no real view drop
    // shadow). Document the no-op so it is not silently dropped; the layout is
    // otherwise unaffected.
    final shadowComment = node.data['shadow'] != null
        ? '<!-- shadow not supported by RemoteViews; ignored on Android -->\n'
        : '';

    // Bind-form background: the FrameLayout needs an id so the provider can
    // resolve+apply the background color at update time.
    String idAttr = '';
    if (isBgBind) {
      final colorKey = backgroundMap['bind'] as String;
      final viewId = 'hw_bgcolor_${AndroidGenerator.idForKey(colorKey)}';
      idAttr = ' android:id="@+id/$viewId"';
      context.registerColorBind(viewId, colorKey, 'background',
          opacity: (backgroundMap['opacity'] ?? 1.0).toDouble());
    }

    String bgAttr = '';
    if (gradient != null && gradient['__type'] == 'HWLinearGradient') {
      // Real gradient: write a <shape><gradient> drawable and reference it.
      final colors = (gradient['colors'] as List).cast<Map>();
      if (colors.isNotEmpty) {
        final hasStops = (gradient['stops'] as List?)?.isNotEmpty ?? false;
        final angle = (gradient['angle'] ?? 0).toDouble();
        final xml = _gradientDrawableXml(
          context,
          colors,
          radius,
          border,
          angle: angle,
          corners: cornersData,
          hasStops: hasStops,
        );
        final name = 'hw_gradient_${_stableHash(xml)}';
        final ref = context.registerDrawable(name, xml);
        bgAttr = ' android:background="$ref"';
      }
    } else if (border != null ||
        cornersData != null ||
        (background != null && radius > 0)) {
      // Border, per-corner radii and/or rounded background: combine into a
      // single shape drawable.
      final xml = _shapeDrawableXml(
        context,
        background != null ? node.data['background'] as Map : null,
        border,
        radius,
        corners: cornersData,
      );
      final name = 'hw_bg_${_stableHash(xml)}';
      final ref = context.registerDrawable(name, xml);
      bgAttr = ' android:background="$ref"';
    } else if (background != null) {
      final color = context.parseColor(node.data['background']);
      bgAttr = ' android:background="$color"';
    }

    final width = widthVal != null ? '${widthVal}dp' : 'wrap_content';
    final height = heightVal != null ? '${heightVal}dp' : 'wrap_content';

    final margin = node.data['margin'];
    String marginAttr = '';
    if (margin != null) {
      // Use start/end (RTL-aware) for horizontal margins so layouts mirror in
      // RTL locales. The IR keys stay logical left/right.
      if (margin['left'] != null)
        marginAttr += ' android:layout_marginStart="${margin['left']}dp"';
      if (margin['top'] != null)
        marginAttr += ' android:layout_marginTop="${margin['top']}dp"';
      if (margin['right'] != null)
        marginAttr += ' android:layout_marginEnd="${margin['right']}dp"';
      if (margin['bottom'] != null)
        marginAttr += ' android:layout_marginBottom="${margin['bottom']}dp"';
    }

    return '''$shadowComment<FrameLayout$idAttr
    android:layout_width="$width" android:layout_height="$height"
    $bgAttr
    $marginAttr>
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: isInsideLinearLayout, isVertical: isVertical)}
</FrameLayout>''';
  }

  /// Deterministic non-negative hash of the drawable content, used to name
  /// drawable files so identical drawables collapse and distinct ones differ.
  String _stableHash(String s) {
    int h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h.toString();
  }

  /// Builds a `<shape><gradient>` drawable. Uses startColor/endColor for the
  /// common 2-color case and adds centerColor for 3-stop gradients. Optionally
  /// includes corner radius, a stroke (border) and is angle 0.
  String _gradientDrawableXml(
    AndroidGenerator context,
    List<Map> colors,
    double radius,
    Object? border, {
    double angle = 0,
    Map? corners,
    bool hasStops = false,
  }) {
    final parsed = colors
        .map((c) => context.parseColor(c.cast<String, dynamic>()))
        .toList();
    // Android <gradient android:angle> accepts ONLY multiples of 45 (0=L->R,
    // 90=top->bottom, ...). Quantize the DSL degrees to the nearest 45.
    final quantized = _quantizeAngle45(angle);
    String gradientTag;
    if (parsed.length >= 3) {
      gradientTag =
          '    <gradient android:type="linear" android:angle="$quantized"\n        android:startColor="${parsed.first}"\n        android:centerColor="${parsed[parsed.length ~/ 2]}"\n        android:endColor="${parsed.last}" />';
    } else {
      final end = parsed.length >= 2 ? parsed[1] : parsed.first;
      gradientTag =
          '    <gradient android:type="linear" android:angle="$quantized"\n        android:startColor="${parsed.first}"\n        android:endColor="$end" />';
    }
    final cornersTag = _cornersTag(corners, radius);
    final stroke = _strokeTag(context, border);
    // Android <shape><gradient> only expresses start/center/end positions, so
    // arbitrary N-stop gradients are approximated. Surface the limitation as a
    // comment (after the XML declaration so AAPT still accepts the file)
    // instead of dropping the stops silently.
    final stopsComment = hasStops
        ? '\n<!-- gradient stops approximated: Android shape gradients support up to 3 positions -->'
        : '';
    return '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel$stopsComment
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
$gradientTag$cornersTag$stroke
</shape>''';
  }

  /// Quantizes an angle in degrees to the nearest multiple of 45 in [0, 315].
  /// Android `<gradient android:angle>` only accepts multiples of 45.
  int _quantizeAngle45(double angle) {
    var rounded = (angle / 45).round() * 45;
    rounded = rounded % 360;
    if (rounded < 0) rounded += 360;
    return rounded;
  }

  /// Builds a `<corners>` tag. Per-corner [corners] (topLeft/topRight/
  /// bottomLeft/bottomRight) take precedence over the scalar [radius]. Returns
  /// an empty string when neither rounds anything.
  String _cornersTag(Map? corners, double radius) {
    if (corners != null) {
      final tl = (corners['topLeft'] ?? 0).toDouble();
      final tr = (corners['topRight'] ?? 0).toDouble();
      final bl = (corners['bottomLeft'] ?? 0).toDouble();
      final br = (corners['bottomRight'] ?? 0).toDouble();
      return '\n    <corners android:topLeftRadius="${tl}dp" android:topRightRadius="${tr}dp" android:bottomLeftRadius="${bl}dp" android:bottomRightRadius="${br}dp" />';
    }
    if (radius > 0) {
      return '\n    <corners android:radius="${radius}dp" />';
    }
    return '';
  }

  /// Builds a `<shape>` drawable combining a solid fill (background), a stroke
  /// (border) and corner radius. Any may be omitted.
  String _shapeDrawableXml(
    AndroidGenerator context,
    Map? background,
    Object? border,
    double radius, {
    Map? corners,
  }) {
    final solid = background != null
        ? '\n    <solid android:color="${context.parseColor(background.cast<String, dynamic>())}" />'
        : '';
    final cornersTag = _cornersTag(corners, radius);
    final stroke = _strokeTag(context, border);
    return '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">$solid$stroke$cornersTag
</shape>''';
  }

  String _strokeTag(AndroidGenerator context, Object? border) {
    if (border == null) return '';
    final b = border as Map;
    final width = (b['width'] ?? 1.0).toDouble();
    final color = context.parseColor((b['color'] as Map).cast<String, dynamic>());
    return '\n    <stroke android:width="${width}dp" android:color="$color" />';
  }
}

class PaddingHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWPadding';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final childJson = node.data['child'];
    if (childJson == null) return '<!-- missing child -->';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final insets = node.data['insets'];
    final pLeft = insets['left'] ?? 0;
    final pRight = insets['right'] ?? 0;
    final pTop = insets['top'] ?? 0;
    final pBottom = insets['bottom'] ?? 0;

    // Use padding directly on a FrameLayout wrapper.
    final isSpacer = child.type == 'HWSpacer';
    final weightAttr = (isInsideLinearLayout && isSpacer)
        ? ' android:layout_weight="1"'
        : '';
    final width = (isInsideLinearLayout && isSpacer && isVertical)
        ? 'match_parent'
        : (isInsideLinearLayout && isSpacer && !isVertical
              ? '0dp'
              : 'match_parent');
    final height = (isInsideLinearLayout && isSpacer && isVertical)
        ? '0dp'
        : (isInsideLinearLayout && isSpacer && !isVertical
              ? 'match_parent'
              : 'match_parent');

    return '''
<FrameLayout
    android:layout_width="$width" android:layout_height="$height"$weightAttr
    android:paddingStart="${pLeft}dp" android:paddingEnd="${pRight}dp"
    android:paddingTop="${pTop}dp" android:paddingBottom="${pBottom}dp">
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: isInsideLinearLayout, isVertical: isVertical)}
</FrameLayout>''';
  }
}

class StackHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWStack';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final children = ((node.data['children'] as List?) ?? const [])
        .map((e) => IRNode.fromJson(e as Map<String, dynamic>))
        .toList();
    final gravity = _stackAlignmentGravity(node.data['alignment'] as String?);
    final renderedChildren = children
        .map((c) => context.nodeToXml(c, usedBinds, visibilityKeys, timers, buttons,
            isInsideLinearLayout: isInsideLinearLayout, isVertical: isVertical))
        .map((xml) => _applyStackAlignment(xml, gravity))
        .toList();
    return '''
<FrameLayout
    android:layout_width="match_parent"
    android:layout_height="match_parent">
    ${renderedChildren.join('\n')}
</FrameLayout>''';
  }
}

class SpacerHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWSpacer';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    if (!isInsideLinearLayout) {
      return '<FrameLayout android:layout_width="0dp" android:layout_height="0dp" />';
    }
    final width = isVertical ? "match_parent" : "0dp";
    final height = isVertical ? "0dp" : "match_parent";
    return '<FrameLayout android:layout_width="$width" android:layout_height="$height" android:layout_weight="1" />';
  }
}

class ButtonHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWButton';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final childJson = node.data['child'];
    if (childJson == null) return '<!-- missing child -->';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final action = node.data['action'];
    final index = buttons.length;
    buttons.add(action);
    final id = index == 0 ? "hw_button_main" : "hw_button_$index";
    final isSpacer = child.type == 'HWSpacer';
    final weightAttr = (isInsideLinearLayout && isSpacer)
        ? ' android:layout_weight="1"'
        : '';
    final width = (isInsideLinearLayout && isSpacer && isVertical)
        ? 'match_parent'
        : (isInsideLinearLayout && isSpacer && !isVertical
              ? '0dp'
              : 'match_parent');
    final height = (isInsideLinearLayout && isSpacer && isVertical)
        ? '0dp'
        : (isInsideLinearLayout && isSpacer && !isVertical
              ? 'match_parent'
              : 'wrap_content');

    return '''
<FrameLayout
    android:id="@+id/$id"
    android:layout_width="$width" android:layout_height="$height"$weightAttr
    android:clickable="true" android:focusable="true">
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: isInsideLinearLayout, isVertical: isVertical)}
</FrameLayout>''';
  }
}

class VisibilityHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWVisibility';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final childJson = node.data['child'];
    if (childJson == null) return '<!-- missing child -->';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final bindMap = node.data['bind'] as Map<String, dynamic>?;
    if (bindMap == null) return '<!-- missing bind -->';
    final key = bindMap['key'] as String;
    visibilityKeys.add(key);
    final visId = AndroidGenerator.idForKey(key);
    final isSpacer = child.type == 'HWSpacer';
    final weightAttr = (isInsideLinearLayout && isSpacer)
        ? ' android:layout_weight="1"'
        : '';
    final width = (isInsideLinearLayout && isSpacer && isVertical)
        ? 'match_parent'
        : (isInsideLinearLayout && isSpacer && !isVertical
              ? '0dp'
              : 'match_parent');
    final height = (isInsideLinearLayout && isSpacer && isVertical)
        ? '0dp'
        : (isInsideLinearLayout && isSpacer && !isVertical
              ? 'match_parent'
              : 'wrap_content');

    final replacementJson = node.data['replacement'];
    if (replacementJson == null) {
      // No replacement: keep legacy single-view GONE behavior. The slot
      // dimensions/weight live directly on the toggled view.
      return '''
<FrameLayout
    android:id="@+id/hw_visibility_$visId"
    android:layout_width="$width" android:layout_height="$height"$weightAttr>
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: isInsideLinearLayout, isVertical: isVertical)}
</FrameLayout>''';
    }

    // Replacement present: wrap BOTH toggled views inside a SINGLE container so
    // the handler returns exactly ONE layout element occupying one slot. The
    // slot dimensions/weight live on the wrapper (so main-axis spacers align and
    // cross-axis stretch rewrites the wrapper's dimension once); the two inner
    // views are wrap_content and toggled inversely by the provider via their
    // ids, which remain discoverable for setViewVisibility.
    context.registerVisibilityReplacement(key);
    final replacement =
        IRNode.fromJson(replacementJson as Map<String, dynamic>);
    return '''
<FrameLayout
    android:layout_width="$width" android:layout_height="$height"$weightAttr>
    <FrameLayout
        android:id="@+id/hw_visibility_$visId"
        android:layout_width="wrap_content" android:layout_height="wrap_content">
        ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: false)}
    </FrameLayout>
    <FrameLayout
        android:id="@+id/hw_visibility_${visId}_alt"
        android:layout_width="wrap_content" android:layout_height="wrap_content">
        ${context.nodeToXml(replacement, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: false)}
    </FrameLayout>
</FrameLayout>''';
  }
}

class ImageHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWImage';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final source = node.data['source'];
    final type = source['__type'];
    String idAttr = '';
    String srcAttr = '';
    if (type == 'HWAssetImage') {
      // Asset: reference a bundled drawable by sanitized basename (no ext).
      final path = (source['path'] as String?) ?? '';
      final base = p.basenameWithoutExtension(path);
      final res = sanitizeIdentifier(base).toLowerCase();
      if (res.isNotEmpty) {
        srcAttr = ' android:src="@drawable/$res"';
      }
    } else if (type == 'HWFileImage') {
      final path = source['path'];
      if (path is Map && path['__type'] == 'HWBind') {
        final key = path['key'] as String;
        if (context.inItemTemplate) {
          // Per-row image: set by the factory via hw_item_<field>.
          context.collectItemField(key, kind: 'image');
          idAttr =
              'android:id="@+id/hw_item_${AndroidGenerator.idForKey(key)}"';
        } else {
          // Dynamic file image: resolved at update time via the provider.
          usedBinds[key] = 'image';
          idAttr =
              'android:id="@+id/hw_image_${AndroidGenerator.idForKey(key)}"';
        }
      } else if (path is String && path.isNotEmpty) {
        // Static file image: wire a fixed Uri in the provider.
        final suffix = sanitizeIdentifier(path).toLowerCase();
        idAttr = 'android:id="@+id/hw_image_$suffix"';
        context.registerStaticImageUri(suffix, path);
      }
    }
    final scaleType = _mapFit(node.data['fit'] as String?);
    return '<ImageView $idAttr$srcAttr android:layout_width="match_parent" android:layout_height="wrap_content" android:scaleType="$scaleType" />';
  }

  /// Maps a Flutter MBoxFit value to the closest Android ImageView scaleType.
  /// Defaults to centerCrop (BoxFit.cover) when unset or unrecognized.
  String _mapFit(String? fit) {
    switch (fit) {
      case 'contain':
        return 'fitCenter';
      case 'fill':
        return 'fitXY';
      case 'fitWidth':
        return 'fitStart';
      case 'fitHeight':
        return 'fitEnd';
      case 'none':
        return 'center';
      case 'scaleDown':
        return 'centerInside';
      case 'cover':
      default:
        return 'centerCrop';
    }
  }
}

class ProgressBarHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWProgressBar';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final value = node.data['value'];
    final isBind = value is Map && value['__type'] == 'HWBind';
    String idAttr = '';
    String progressAttr = '';
    if (isBind) {
      final key = value['key'] as String;
      usedBinds[key] = 'progress';
      idAttr = 'android:id="@+id/hw_progress_${AndroidGenerator.idForKey(key)}"';
    } else if (value != null) {
      // Static value: emit it directly into the layout (set at runtime for binds).
      final progress = (value as num).toInt();
      progressAttr = ' android:progress="$progress"';
    }
    final max = (node.data['max'] ?? 100).toInt();
    // android:progressTint requires API 21+ (the configured min_sdk).
    final colorData = node.data['color'];
    String tintAttr = '';
    if (colorData is Map) {
      final colorMap = colorData.cast<String, dynamic>();
      if (context.isColorBind(colorMap)) {
        // Bind-form tint: the ProgressBar needs a stable id so the provider can
        // resolve+apply the color at update time via setColorFilter. Reuse the
        // value bind id when present; otherwise allocate a color-bind id.
        final colorKey = colorMap['bind'] as String;
        String viewId;
        if (isBind) {
          viewId =
              'hw_progress_${AndroidGenerator.idForKey(value['key'] as String)}';
        } else {
          viewId = 'hw_progresscolor_${AndroidGenerator.idForKey(colorKey)}';
          idAttr = 'android:id="@+id/$viewId"';
        }
        context.registerColorBind(viewId, colorKey, 'progress',
            opacity: (colorMap['opacity'] ?? 1.0).toDouble());
      } else {
        final color = context.parseColor(colorMap);
        tintAttr = ' android:progressTint="$color"';
      }
    }
    return '<ProgressBar $idAttr style="?android:attr/progressBarStyleHorizontal" android:layout_width="match_parent" android:layout_height="wrap_content" android:max="$max"$progressAttr$tintAttr />';
  }
}

class ListViewHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWListView';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    // Real Android collection view: emit a ListView whose adapter is wired in
    // the provider via setRemoteAdapter to the shared MosaicListService. The
    // item template is rendered into a per-row item layout, and each bound
    // field maps to a hw_item_<field> view set per row by the factory.
    final bindMap = node.data['bind'] as Map?;
    if (bindMap == null) return '<!-- missing bind -->';
    final key = bindMap['key'] as String;
    final itemJson = node.data['itemTemplate'];
    if (itemJson == null) return '<!-- missing itemTemplate -->';
    final itemTemplate = IRNode.fromJson(
      (itemJson as Map).cast<String, dynamic>(),
    );

    final idKey = context.registerListView(key, itemTemplate);

    final width = isInsideLinearLayout && !isVertical ? '0dp' : 'match_parent';
    final weightAttr =
        isInsideLinearLayout && !isVertical ? ' android:layout_weight="1"' : '';
    return '<ListView android:id="@+id/hw_list_$idKey" android:layout_width="$width" android:layout_height="match_parent"$weightAttr />';
  }
}

class TimerHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWTimer';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final target = node.data['target'];
    final id = timers.length.toString();
    timers[id] = target.toString();
    if (node.data['countUp'] == true) {
      context.registerTimerCountUp(id);
    }

    final color = context.parseColor(
      node.data['style']?['color'] ?? {'hex': '#FFFFFF'},
    );
    final size = node.data['style']?['size'] ?? 14;
    final style = node.data['style']?['bold'] == true ? 'bold' : 'normal';
    // Standalone opacity applies to the whole view (mirror TextHandler).
    final opacity = node.data['style']?['opacity'];
    final alphaAttr = opacity != null ? ' android:alpha="$opacity"' : '';

    return '<Chronometer android:id="@+id/hw_timer_$id" android:layout_width="wrap_content" android:layout_height="wrap_content" android:textColor="$color" android:textSize="${size}sp" android:textStyle="$style"$alphaAttr />';
  }
}

class PositionedHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWPositioned';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final childJson = node.data['child'];
    if (childJson == null) return '<!-- missing child -->';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final top = node.data['top'];
    final left = node.data['left'];
    final right = node.data['right'];
    final bottom = node.data['bottom'];

    String gravity = 'top|start';
    String margins = '';
    if (top != null) margins += ' android:layout_marginTop="${top}dp"';
    // RTL-aware: logical left/right map to start/end so positioning mirrors.
    if (left != null) margins += ' android:layout_marginStart="${left}dp"';
    if (right != null) {
      margins += ' android:layout_marginEnd="${right}dp"';
      gravity = gravity.replaceFirst('start', 'end');
    }
    if (bottom != null) {
      margins += ' android:layout_marginBottom="${bottom}dp"';
      gravity = gravity.replaceFirst('top', 'bottom');
    }

    return '''
<FrameLayout
    android:layout_width="wrap_content" android:layout_height="wrap_content"
    android:layout_gravity="$gravity"
    $margins>
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons)}
</FrameLayout>''';
  }
}

/// Renders an `HWDivider` as a plain `<View>` with a solid background color.
/// A horizontal divider fills the available width and is [thickness]dp tall; a
/// vertical divider is [thickness]dp wide and fills the available height.
/// `indent` is applied as symmetric RTL-aware start/end margins.
class DividerHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWDivider';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final thickness = (node.data['thickness'] ?? 1).toDouble();
    final isVerticalDivider = node.data['vertical'] == true;
    final indent = (node.data['indent'] ?? 0).toDouble();
    final colorData = node.data['color'];
    final color = colorData is Map
        ? context.parseColor(colorData.cast<String, dynamic>())
        : '#FFFFFF';

    final width = isVerticalDivider ? '${thickness}dp' : 'match_parent';
    final height = isVerticalDivider ? 'match_parent' : '${thickness}dp';

    String marginAttr = '';
    if (indent > 0) {
      marginAttr =
          ' android:layout_marginStart="${indent}dp" android:layout_marginEnd="${indent}dp"';
    }

    return '<View android:layout_width="$width" android:layout_height="$height" android:background="$color"$marginAttr />';
  }
}

/// Renders an `HWIcon` as an `<ImageView>` referencing the Android drawable
/// resource named by `androidDrawable`, tinted with `color` and sized to
/// `size`dp. When `androidDrawable` is null (an iOS-only SF Symbol was given)
/// the icon cannot be resolved on Android: emit a documented comment and a
/// blank sized `<View>` placeholder rather than crashing or emitting a dangling
/// `@drawable/null` reference.
class IconHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWIcon';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final size = (node.data['size'] ?? 24).toDouble();
    final drawable = node.data['androidDrawable'] as String?;
    if (drawable == null || drawable.isEmpty) {
      return '<!-- icon has no androidDrawable -->\n'
          '<View android:layout_width="${size}dp" android:layout_height="${size}dp" />';
    }
    final res = sanitizeIdentifier(drawable).toLowerCase();
    final colorData = node.data['color'];
    String tintAttr = '';
    if (colorData is Map) {
      final color = context.parseColor(colorData.cast<String, dynamic>());
      tintAttr = ' android:tint="$color"';
    }
    return '<ImageView android:src="@drawable/$res"$tintAttr android:layout_width="${size}dp" android:layout_height="${size}dp" />';
  }
}

/// Renders an `HWGauge` (a circular ring/arc indicator on iOS) as a horizontal
/// determinate `<ProgressBar>`. RemoteViews/AppWidgets cannot draw arbitrary
/// arcs, so this is a DOCUMENTED best-effort approximation surfaced via a
/// comment. `fillColor` maps to `progressTint`, `trackColor` to
/// `backgroundTint`. A bound `value` reuses the exact same `progress` runtime
/// bind path as `HWProgressBar` (id `hw_progress_<key>` + `setProgressBar`).
class GaugeHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWGauge';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final value = node.data['value'];
    final isBind = value is Map && value['__type'] == 'HWBind';
    String idAttr = '';
    String progressAttr = '';
    if (isBind) {
      final key = value['key'] as String;
      usedBinds[key] = 'progress';
      idAttr =
          ' android:id="@+id/hw_progress_${AndroidGenerator.idForKey(key)}"';
    } else if (value != null) {
      progressAttr = ' android:progress="${(value as num).toInt()}"';
    }
    final max = (node.data['max'] ?? 100).toInt();

    String tintAttr = '';
    final fill = node.data['fillColor'];
    if (fill is Map) {
      tintAttr +=
          ' android:progressTint="${context.parseColor(fill.cast<String, dynamic>())}"';
    }
    final track = node.data['trackColor'];
    if (track is Map) {
      tintAttr +=
          ' android:backgroundTint="${context.parseColor(track.cast<String, dynamic>())}"';
    }

    // lineWidth styles the arc stroke on iOS; a linear ProgressBar has no arc,
    // so the value is dropped. Surface the drop with a comment when present.
    final lineWidthComment = node.data['lineWidth'] != null
        ? '<!-- gauge lineWidth ignored: approximated as linear ProgressBar on Android -->\n'
        : '';

    return '<!-- gauge approximated as linear progress on Android (RemoteViews has no arc) -->\n'
        '$lineWidthComment'
        '<ProgressBar$idAttr style="?android:attr/progressBarStyleHorizontal" android:layout_width="match_parent" android:layout_height="wrap_content" android:max="$max"$progressAttr$tintAttr />';
  }
}

/// Renders an `HWBadge` as a `<FrameLayout>` holding the child plus a small
/// `<TextView>` (the count) pinned to the `top|end` corner. The count text view
/// gets a generated rounded shape drawable as its background (registered via
/// [AndroidGenerator.registerDrawable]). A bound `count` reuses the standard
/// text bind path (id `hw_text_<key>` + `setTextViewText`).
class BadgeHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWBadge';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final childJson = node.data['child'];
    if (childJson == null) return '<!-- missing child -->';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);

    final count = node.data['count'];
    final isBind = count is Map && count['__type'] == 'HWBind';
    String countIdAttr = '';
    String countText = '';
    if (isBind) {
      final key = count['key'] as String;
      usedBinds[key] = 'text';
      countIdAttr =
          ' android:id="@+id/hw_text_${AndroidGenerator.idForKey(key)}"';
    } else {
      countText = count == null ? '' : count.toString();
    }

    // Rounded background for the badge bubble. A pill is achieved with a large
    // corner radius; the color comes from the optional `color` field.
    final colorData = node.data['color'];
    final bgColor = colorData is Map
        ? context.parseColor(colorData.cast<String, dynamic>())
        : '#FF0000';
    final shapeXml = '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="$bgColor" />
    <corners android:radius="100dp" />
</shape>''';
    final badgeName = 'hw_badge_${_badgeHash(shapeXml)}';
    final bgRef = context.registerDrawable(badgeName, shapeXml);

    return '''
<FrameLayout
    android:layout_width="wrap_content" android:layout_height="wrap_content">
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: false)}
    <TextView$countIdAttr
        android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:layout_gravity="top|end"
        android:background="$bgRef"
        android:paddingStart="4dp" android:paddingEnd="4dp"
        android:text="${xmlEscape(countText)}"
        android:textColor="#FFFFFF" android:textSize="10sp" />
</FrameLayout>''';
  }

  String _badgeHash(String s) {
    int h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h.toString();
  }
}

class CenterHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWCenter';
  @override
  String handle(
    IRNode node,
    Map<String, String> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final childJson = node.data['child'];
    if (childJson == null) return '<!-- missing child -->';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    return '''
<FrameLayout
    android:layout_width="match_parent" android:layout_height="match_parent">
    <FrameLayout
        android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:layout_gravity="center">
        ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: false)}
    </FrameLayout>
</FrameLayout>''';
  }
}
