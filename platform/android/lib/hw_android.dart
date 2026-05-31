import 'dart:io';
import 'package:hw_core/hw_core.dart';
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

class AndroidGenerator {
  final HWConfig config;
  final List<IRDefinition> definitions;
  final Map<String, AndroidNodeHandler> _handlers = {};

  /// Returns a sanitized identifier safe for use as a Kotlin class name or
  /// Android resource name component.
  String _safeName(String n) => sanitizeIdentifier(n);

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

    await _generateBridgeHelper(projectRoot);
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
        'hw_generated',
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

    await file.writeAsString('''
package ${config.app.androidPackage}.hw_generated

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
    buffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
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

    return '''<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="${minWidth}dp"
    android:minHeight="${minHeight}dp"
    android:updatePeriodMillis="86400000"
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
        'hw_generated',
      ),
    );
    if (!kotlinDir.existsSync()) kotlinDir.createSync(recursive: true);

    final className = '${safe}Provider';
    final file = File(p.join(kotlinDir.path, '$className.kt'));

    final bindLogic = usedBinds.entries
        .map((entry) {
          final key = entry.key;
          final type = entry.value;
          if (type == 'progress') {
            return 'views.setProgressBar(R.id.hw_progress_$key, 100, (prefs.getString("$key", "0")?.toDoubleOrNull() ?: 0.0).toInt(), false)';
          } else {
            return 'views.setTextViewText(R.id.hw_text_$key, prefs.getString("$key", null) ?: "")';
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
              'views.setViewVisibility(R.id.hw_visibility_$key, if (prefs.getBoolean("$key", true)) android.view.View.VISIBLE else android.view.View.GONE)',
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
        val pendingIntent$index = android.app.PendingIntent.getActivity(context, $index, intent$index, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.$viewId, pendingIntent$index)
        ''';
          } else if (action['__type'] == 'HWActionCallback') {
            final callbackName = kotlinEscape(action['callbackName'] as String);
            return '''
        val intent$index = android.content.Intent(context, $className::class.java).apply {
            action = "com.example.hw_flutter.ACTION_CALLBACK"
            putExtra("callbackName", "$callbackName")
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val pendingIntent$index = android.app.PendingIntent.getBroadcast(context, $index, intent$index, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.$viewId, pendingIntent$index)
        ''';
          } else {
            return '''
        val intent$index = android.content.Intent(context, $className::class.java).apply {
            action = "com.example.hw_flutter.ACTION_CALLBACK"
            putExtra("callbackName", "refresh_all")
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val pendingIntent$index = android.app.PendingIntent.getBroadcast(context, $index, intent$index, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.$viewId, pendingIntent$index)
        ''';
          }
        })
        .join('\n        ');

    await file.writeAsString('''
package ${config.app.androidPackage}.hw_generated

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import ${config.app.androidPackage}.R

class $className : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
        if (intent.action == "com.example.hw_flutter.ACTION_CALLBACK") {
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
    final gravity = _mapGravity(
      node.data['mainAxisAlignment'],
      node.data['crossAxisAlignment'],
    );
    return '''
<LinearLayout
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:gravity="$gravity">
    ${children.map((c) => context.nodeToXml(c, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: true, isVertical: true)).join('\n')}
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
    final gravity = _mapGravity(
      node.data['mainAxisAlignment'],
      node.data['crossAxisAlignment'],
    );
    return '''
<LinearLayout
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="horizontal"
    android:gravity="$gravity">
    ${children.map((c) => context.nodeToXml(c, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: true, isVertical: false)).join('\n')}
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
      idAttr = 'android:id="@+id/hw_text_$key"';
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
    final widthVal = node.data['width'];
    final heightVal = node.data['height'];

    String bgAttr = '';
    if (background != null) {
      final color = context.parseColor(node.data['background']);
      bgAttr = ' android:background="$color"';
    } else if (gradient != null && gradient['__type'] == 'HWLinearGradient') {
      final colors = gradient['colors'] as List;
      if (colors.isNotEmpty) {
        final firstColor = context.parseColor(colors[0]);
        bgAttr = ' android:background="$firstColor"';
      }
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
    android:id="@+id/hw_visibility_$key"
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
    if (type == 'HWFileImage') {
      final path = source['path'];
      if (path is Map && path['__type'] == 'HWBind') {
        final key = path['key'] as String;
        usedBinds[key] = 'image';
        idAttr = 'android:id="@+id/hw_image_$key"';
      }
    }
    return '<ImageView $idAttr android:layout_width="match_parent" android:layout_height="wrap_content" android:scaleType="centerCrop" />';
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
    if (isBind) {
      final key = value['key'] as String;
      usedBinds[key] = 'progress';
      idAttr = 'android:id="@+id/hw_progress_$key"';
    }
    final max = (node.data['max'] ?? 100).toInt();
    return '<ProgressBar $idAttr style="?android:attr/progressBarStyleHorizontal" android:layout_width="match_parent" android:layout_height="wrap_content" android:max="$max" />';
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
    // Basic implementation: RemoteViews doesn't support full ListView easily without RemoteViewsService.
    return '<View android:layout_width="0dp" android:layout_height="0dp" />';
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
