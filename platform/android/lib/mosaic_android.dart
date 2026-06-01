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

  /// Static file-image URIs to wire up at update time, keyed by the view id
  /// suffix (used to build `R.id.hw_image_<suffix>`). Populated by
  /// [ImageHandler] for non-bound `HWFileImage` paths.
  final Map<String, String> _staticImageUris = {};

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

  AndroidGenerator({required this.config, required this.definitions}) {
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

    for (final def in definitions) {
      final safe = _safeName(def.name);
      final layoutName = 'hw_${safe.toLowerCase()}';
      final layoutFile = File(p.join(layoutDir.path, '$layoutName.xml'));

      final usedBinds = <String, String>{};
      final visibilityKeys = <String>[];
      final timers = <String, String>{};
      final buttons = <Map<String, dynamic>>[];
      _staticImageUris.clear();

      final layoutXml = _generateLayoutXml(
        def.root,
        usedBinds,
        visibilityKeys,
        timers,
        buttons,
      );
      await layoutFile.writeAsString(layoutXml);

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
    }

    await _writeDrawables(resDir);

    await _generateBridgeHelper(projectRoot);
    await _generateMosaicData(projectRoot);
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

  String parseColor(Map<String, dynamic> colorData) {
    String hex = (colorData['hex'] as String?) ?? '#FFFFFF';
    if (!hex.startsWith('#')) hex = '#$hex';
    double opacity = (colorData['opacity'] ?? 1.0).toDouble();
    if (opacity < 1.0) {
      int alpha = (opacity * 255).toInt().clamp(0, 255);
      String alphaHex = alpha.toRadixString(16).padLeft(2, '0').toUpperCase();
      return '#$alphaHex${hex.substring(1)}';
    }
    return hex;
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
    $preview>
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
              return 'views.setTextViewText(R.id.hw_text_$id, MosaicData.resolveString(context, "$lit"))';
          }
        })
        .join('\n        ');

    final timerLogic = timers.entries
        .map((entry) {
          final id = entry.key;
          final targetEpoch = entry.value;
          return '''
        val target$id = ${targetEpoch}L
        val offset$id = target$id - System.currentTimeMillis()
        views.setChronometer(R.id.hw_timer_$id, android.os.SystemClock.elapsedRealtime() + offset$id, null, true)
      ''';
        })
        .join('\n        ');

    final visibilityLogic = visibilityKeys
        .map(
          (key) =>
              'views.setViewVisibility(R.id.hw_visibility_${idForKey(key)}, if (MosaicData.resolveBool(context, "${kotlinEscape(key)}")) android.view.View.VISIBLE else android.view.View.GONE)',
        )
        .join('\n        ');

    final staticImageLogic = _staticImageUris.entries
        .map(
          (e) =>
              'views.setImageViewUri(R.id.hw_image_${e.key}, android.net.Uri.parse("${kotlinEscape(e.value)}"))',
        )
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
        $buttonLogic

        appWidgetManager.updateAppWidget(appWidgetId, views)
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
    if (isBind) {
      final key = text['key'] as String;
      usedBinds[key] = 'text';
      idAttr = 'android:id="@+id/hw_text_${AndroidGenerator.idForKey(key)}"';
    } else {
      textValue = text.toString();
    }
    final color = context.parseColor(
      node.data['style']?['color'] ?? {'hex': '#FFFFFF'},
    );
    final size = node.data['style']?['size'] ?? 14;
    final style = node.data['style']?['bold'] == true ? 'bold' : 'normal';

    return '<TextView $idAttr android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="${xmlEscape(textValue)}" android:textColor="$color" android:textSize="${size}sp" android:textStyle="$style" />';
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
    final background = node.data['background']?['hex'];
    final gradient = node.data['gradient'];
    final border = node.data['border'];
    final radius = (node.data['radius'] ?? 0).toDouble();
    final widthVal = node.data['width'];
    final heightVal = node.data['height'];

    String bgAttr = '';
    if (gradient != null && gradient['__type'] == 'HWLinearGradient') {
      // Real gradient: write a <shape><gradient> drawable and reference it.
      final colors = (gradient['colors'] as List).cast<Map>();
      if (colors.isNotEmpty) {
        final xml = _gradientDrawableXml(
          context,
          colors,
          radius,
          border,
        );
        final name = 'hw_gradient_${_stableHash(xml)}';
        final ref = context.registerDrawable(name, xml);
        bgAttr = ' android:background="$ref"';
      }
    } else if (border != null || (background != null && radius > 0)) {
      // Border and/or rounded background: combine into a single shape drawable.
      final xml = _shapeDrawableXml(
        context,
        background != null ? node.data['background'] as Map : null,
        border,
        radius,
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
      if (margin['left'] != null)
        marginAttr += ' android:layout_marginLeft="${margin['left']}dp"';
      if (margin['top'] != null)
        marginAttr += ' android:layout_marginTop="${margin['top']}dp"';
      if (margin['right'] != null)
        marginAttr += ' android:layout_marginRight="${margin['right']}dp"';
      if (margin['bottom'] != null)
        marginAttr += ' android:layout_marginBottom="${margin['bottom']}dp"';
    }

    return '''
<FrameLayout
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
    Object? border,
  ) {
    final parsed = colors
        .map((c) => context.parseColor(c.cast<String, dynamic>()))
        .toList();
    String gradientTag;
    if (parsed.length >= 3) {
      gradientTag =
          '    <gradient android:type="linear" android:angle="0"\n        android:startColor="${parsed.first}"\n        android:centerColor="${parsed[parsed.length ~/ 2]}"\n        android:endColor="${parsed.last}" />';
    } else {
      final end = parsed.length >= 2 ? parsed[1] : parsed.first;
      gradientTag =
          '    <gradient android:type="linear" android:angle="0"\n        android:startColor="${parsed.first}"\n        android:endColor="$end" />';
    }
    final corners = radius > 0
        ? '\n    <corners android:radius="${radius}dp" />'
        : '';
    final stroke = _strokeTag(context, border);
    return '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
$gradientTag$corners$stroke
</shape>''';
  }

  /// Builds a `<shape>` drawable combining a solid fill (background), a stroke
  /// (border) and corner radius. Any may be omitted.
  String _shapeDrawableXml(
    AndroidGenerator context,
    Map? background,
    Object? border,
    double radius,
  ) {
    final solid = background != null
        ? '\n    <solid android:color="${context.parseColor(background.cast<String, dynamic>())}" />'
        : '';
    final corners = radius > 0
        ? '\n    <corners android:radius="${radius}dp" />'
        : '';
    final stroke = _strokeTag(context, border);
    return '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">$solid$stroke$corners
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
    android:paddingLeft="${pLeft}dp" android:paddingRight="${pRight}dp"
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
    return '''
<FrameLayout
    android:layout_width="match_parent"
    android:layout_height="match_parent">
    ${children.map((c) => context.nodeToXml(c, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: isInsideLinearLayout, isVertical: isVertical)).join('\n')}
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

    return '''
<FrameLayout
    android:id="@+id/hw_visibility_$visId"
    android:layout_width="$width" android:layout_height="$height"$weightAttr>
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: isInsideLinearLayout, isVertical: isVertical)}
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
        // Dynamic file image: resolved at update time via the provider.
        final key = path['key'] as String;
        usedBinds[key] = 'image';
        idAttr = 'android:id="@+id/hw_image_${AndroidGenerator.idForKey(key)}"';
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
    return '<ProgressBar $idAttr style="?android:attr/progressBarStyleHorizontal" android:layout_width="match_parent" android:layout_height="wrap_content" android:max="$max"$progressAttr />';
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
    // A correct collection view requires a RemoteViewsService + factory wired
    // through setRemoteAdapter AND the service registered in AndroidManifest.
    // This generator does not manage the manifest, so a partial implementation
    // would silently render nothing at runtime. Fail loudly at gen time instead
    // of emitting an invisible 0x0 stub.
    throw UnsupportedError(
      'HWListView Android support is not yet implemented — remove it or use a Column for now.',
    );
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

    final color = context.parseColor(
      node.data['style']?['color'] ?? {'hex': '#FFFFFF'},
    );
    final size = node.data['style']?['size'] ?? 14;
    final style = node.data['style']?['bold'] == true ? 'bold' : 'normal';

    return '<Chronometer android:id="@+id/hw_timer_$id" android:layout_width="wrap_content" android:layout_height="wrap_content" android:textColor="$color" android:textSize="${size}sp" android:textStyle="$style" />';
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
    if (left != null) margins += ' android:layout_marginLeft="${left}dp"';
    if (right != null) {
      margins += ' android:layout_marginRight="${right}dp"';
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
