// The AppWidgetProvider and configuration Activity generated per widget.
part of '../mosaic_android.dart';

extension AndroidProviderEmitters on AndroidGenerator {
  Future<void> _generateKotlinProvider(
    String projectRoot,
    IRDefinition def,
    String safe,
    Map<String, Set<String>> usedBinds,
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

    // One key can drive several views at once — a battery level shown both as
    // text and as a progress bar is the common case — so each kind it was bound
    // as needs its own statement. Keying a single kind per bind silently
    // dropped all but the last.
    // Driven by the concrete view ids the handlers allocated, not re-derived
    // from the key: the same value can legitimately appear in several views,
    // and one statement per key updated only the first of them.
    final imageBinds = usedBinds.entries
        .where((e) => e.value.contains('image'))
        .map((e) => (
              viewId: 'hw_image_${AndroidGenerator.idForKey(e.key)}',
              key: e.key,
              kind: 'image',
            ));

    final bindLogic = [..._boundViews, ...imageBinds].map((view) {
      final lit = kotlinEscape(view.key);
      switch (view.kind) {
        case 'progress':
          return 'views.setProgressBar(R.id.${view.viewId}, 100, MosaicData.resolveDouble(context, "$lit").toInt(), false)';
        case 'image':
          return 'views.setImageViewUri(R.id.${view.viewId}, android.net.Uri.parse(MosaicData.resolveString(context, "$lit", "")))';
        case 'text':
        default:
          final format = _textFormats[view.key];
          if (format != null) {
            // Formatted bound text: resolve the raw string then format it with
            // the device default Locale via MosaicData.formatValue.
            final code = _textCurrencies[view.key];
            final codeArg = code == null ? '' : ', "${kotlinEscape(code)}"';
            return 'views.setTextViewText(R.id.${view.viewId}, MosaicData.formatValue(MosaicData.resolveString(context, "$lit"), "$format"$codeArg))';
          }
          return 'views.setTextViewText(R.id.${view.viewId}, MosaicData.resolveString(context, "$lit"))';
      }
    }).join('\n        ');

    final timerLogic = timers.entries.map((entry) {
      final id = entry.key;
      final targetEpoch = entry.value;
      // Count direction: count-down by default; count-up when registered.
      // setChronometerCountDown requires API 24+; ignored on lower SDKs.
      final countDown = !_timersCountUp.contains(id);
      // The base is the target expressed on the elapsedRealtime clock, which is
      // the same arithmetic either way — only the direction flag differs.
      // Count-down renders base - now: a future target gives a shrinking
      // positive. Count-up renders now - base: a past target (offset negative,
      // so the base lands in the past) gives a growing positive. Negating the
      // offset for count-up put the base in the future and rendered a negative
      // timer that grew more negative.
      return '''
        val target$id = ${targetEpoch}L
        val offset$id = target$id - System.currentTimeMillis()
        views.setChronometer(R.id.hw_timer_$id, android.os.SystemClock.elapsedRealtime() + offset$id, null, true)
        views.setChronometerCountDown(R.id.hw_timer_$id, $countDown)
      ''';
    }).join('\n        ');

    final seenVisibility = <String, int>{};
    final visibilityLogic = visibilityKeys.map(
      (key) {
        // Mirrors the handler's per-occurrence ids so each MVisibility using
        // this key is toggled, not just the first.
        final n = seenVisibility[key] = (seenVisibility[key] ?? 0) + 1;
        final id = n == 1
            ? AndroidGenerator.idForKey(key)
            : '${AndroidGenerator.idForKey(key)}_$n';
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
    ).join('\n        ');

    final staticImageLogic = _staticImageUris.entries
        .map(
          (e) =>
              'views.setImageViewUri(R.id.hw_image_${e.key}, android.net.Uri.parse("${kotlinEscape(e.value)}"))',
        )
        .join('\n        ');

    // Runtime color binds: resolve a hex string from prefs, parse to an int
    // color and apply via the appropriate RemoteViews call. Parse failures are
    // swallowed (try/catch) so a bad value just leaves the placeholder.
    // Bound accessibility labels.
    final a11yLogic = _contentDescriptions
        .map((e) =>
            '        views.setContentDescription(R.id.${e.viewId}, '
            'MosaicData.resolveString(context, "${kotlinEscape(e.key)}"))')
        .join('\n');

    // Outline clipping for rounded/circular images. RemoteViews exposes no clip
    // API, so drive the setter reflectively — the shape comes from the view's
    // background drawable.
    final clipLogic = _clippedViews
        .map((viewId) =>
            '        views.setBoolean(R.id.$viewId, "setClipToOutline", true)')
        .join('\n');

    // Network images: show whatever is already cached, then download anything
    // missing on a background thread and ask for another update. Downloading
    // inline would block the main thread and stall the widget update.
    final networkImageLogic = _networkImages.map((img) {
      final urlExpr = img.isBind
          ? 'MosaicData.resolveString(context, "${kotlinEscape(img.key)}")'
          : '"${kotlinEscape(img.key)}"';
      return '''
        val netUrl_${img.viewId} = $urlExpr
        val netFile_${img.viewId} = MosaicRefreshSources.cachedImage(context, netUrl_${img.viewId})
        if (netFile_${img.viewId} != null) {
            MosaicRefreshSources.decodeSampled(netFile_${img.viewId}.absolutePath)
                ?.let { views.setImageViewBitmap(R.id.${img.viewId}, it) }
        } else if (!netUrl_${img.viewId}.isNullOrEmpty()) {
            Thread {
                if (MosaicRefreshSources.cacheImage(context, netUrl_${img.viewId}!!) != null) {
                    HomeWidgetBridgeHelper.refreshAll(context)
                }
            }.start()
        }''';
    }).join('\n');

    // Sparklines: rasterised here because RemoteViews cannot draw vectors. The
    // bitmap is sized from the widget's current dp bounds so it stays sharp
    // when the user resizes.
    final sparklineLogic = _sparklines.map((s) {
      final lit = kotlinEscape(s.key);
      final fillBlock = s.fill
          ? '''
                val fillPath = android.graphics.Path(path)
                fillPath.lineTo(xAt(series.size - 1), hPx.toFloat())
                fillPath.lineTo(0f, hPx.toFloat())
                fillPath.close()
                canvas.drawPath(fillPath, android.graphics.Paint().apply {
                    isAntiAlias = true
                    color = android.graphics.Color.parseColor("${s.color}")
                    alpha = 46
                    style = android.graphics.Paint.Style.FILL
                })
'''
          : '';
      return '''
        run {
            val series = MosaicData.resolveDoubleList(context, "$lit")
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
                val pad = ${s.stroke}f * 3f
                val paint = android.graphics.Paint().apply {
                    isAntiAlias = true
                    color = android.graphics.Color.parseColor("${s.color}")
                    style = android.graphics.Paint.Style.STROKE
                    strokeWidth = ${s.stroke}f * 3f
                    strokeCap = android.graphics.Paint.Cap.ROUND
                    strokeJoin = android.graphics.Paint.Join.ROUND
                }
                fun xAt(i: Int) = wPx * i.toFloat() / (series.size - 1)
                fun yAt(v: Double) =
                    (hPx - pad) - ((hPx - pad * 2) * ((v - lo) / span)).toFloat()

                val path = android.graphics.Path()
                path.moveTo(xAt(0), yAt(series[0]))
                for (i in 1 until series.size) path.lineTo(xAt(i), yAt(series[i]))
$fillBlock                canvas.drawPath(path, paint)
                views.setImageViewBitmap(R.id.${s.viewId}, bmp)
            }
        }''';
    }).join('\n');

    // Bar charts: same rasterise-to-bitmap reason as sparklines.
    final barChartLogic = _barCharts.map((b) {
      final lit = kotlinEscape(b.key);
      return '''
        run {
            val series = MosaicData.resolveDoubleList(context, "$lit")
            val top = series.maxOrNull() ?: 0.0
            // Bars are scaled from zero, so a series with nothing positive has
            // no magnitude to draw.
            if (series.isNotEmpty() && top > 0.0) {
                val opts = appWidgetManager.getAppWidgetOptions(appWidgetId)
                val (wPx, hPx) = MosaicRefreshSources.chartBitmapSize(
                    opts?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 160,
                    opts?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 60,
                )
                val bmp = android.graphics.Bitmap.createBitmap(
                    wPx, hPx, android.graphics.Bitmap.Config.ARGB_8888)
                val canvas = android.graphics.Canvas(bmp)
                val paint = android.graphics.Paint().apply {
                    isAntiAlias = true
                    color = android.graphics.Color.parseColor("${b.color}")
                    style = android.graphics.Paint.Style.FILL
                }
                val gap = ${b.spacing}f * 3f
                val radius = ${b.radius}f * 3f
                val slot = wPx.toFloat() / series.size
                val barW = (slot - gap).coerceAtLeast(1f)
                for (i in series.indices) {
                    val v = series[i].coerceAtLeast(0.0)
                    // At least a hairline, so a zero bucket still reads as a
                    // bucket rather than a gap in the axis.
                    val barH = ((hPx * (v / top)).toFloat()).coerceAtLeast(1f)
                    val left = slot * i + gap / 2f
                    canvas.drawRoundRect(
                        left, hPx - barH, left + barW, hPx.toFloat(),
                        radius, radius, paint)
                }
                views.setImageViewBitmap(R.id.${b.viewId}, bmp)
            }
        }''';
    }).join('\n');

    final colorBindLogic = _colorBinds.asMap().entries.map((e) {
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
        // setBackgroundColor installs a flat ColorDrawable, discarding whatever
        // rounded shape the layout declared. Tinting keeps the shape and only
        // changes its colour, so a bound background can still have corners.
        // setColorStateList is API 31+; below that the flat fill is the only
        // option RemoteViews offers, so corners are lost there.
        'backgroundTint' => '''if (android.os.Build.VERSION.SDK_INT >= 31) {
                views.setColorStateList(R.id.${cb.viewId}, "setBackgroundTintList",
                    android.content.res.ColorStateList.valueOf($colorVar))
            } else {
                views.setInt(R.id.${cb.viewId}, "setBackgroundColor", $colorVar)
            }''',
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
    }).join('\n        ');

    // RemoteViews collection wiring: for each HWListView in this definition,
    // build an Intent at the shared MosaicListService carrying the list key,
    // attach it as the ListView's remote adapter, and notify the data set so
    // the factory re-reads MosaicData.resolveList. A unique data Uri per
    // (widget, list) prevents Android from collapsing distinct intents.
    final listAdapterLogic = _listViews.map((lv) {
      final lit = kotlinEscape(lv.key);
      return '''
        val listIntent_${lv.idKey} = android.content.Intent(context, MosaicListService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            putExtra("hw_list_key", "$lit")
            data = android.net.Uri.parse("mosaic://list/" + appWidgetId + "/$lit")
        }
        views.setRemoteAdapter(R.id.hw_list_${lv.idKey}, listIntent_${lv.idKey})
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.hw_list_${lv.idKey})''';
    }).join('\n        ');

    // An unused private val is a Kotlin warning in code the developer cannot
    // edit, so the refresh plumbing is emitted only when a button asks for it.
    final hasRefresh =
        buttons.any((b) => b['__type'] == 'HWRefreshAction');
    final refreshKeys =
        (usedBinds.keys.toList()..sort()).map((k) => '"$k"').join(', ');
    final refreshConst = hasRefresh
        ? '\n    private val mosaicRefreshAction = "${config.app.androidPackage}.MOSAIC_REFRESH"'
        : '';
    final refreshReceive = hasRefresh
        ? '''
        if (intent.action == mosaicRefreshAction) {
            // MRefreshAction: refetch every declared source that supplies a key
            // this widget binds, then redraw. Runs in the widget process, so it
            // works with the app closed — the same guarantee the iOS
            // MosaicRefreshIntent gives.
            val pending = goAsync()
            MosaicRefreshSources.setRefreshing(context, true)
            HomeWidgetBridgeHelper.refreshAll(context)
            Thread {
                try {
                    MosaicRefreshSources.runKeys(context, listOf($refreshKeys))
                } finally {
                    MosaicRefreshSources.setRefreshing(context, false)
                    HomeWidgetBridgeHelper.refreshAll(context)
                    pending.finish()
                }
            }.start()
            return
        }
'''
        : '';

    final buttonLogic = buttons.asMap().entries.map((entry) {
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
      } else if (action['__type'] == 'HWRefreshAction') {
        // iOS reloads the timeline in-process. The Android analogue is to
        // refetch this widget's declared sources and redraw. It used to fall
        // into the catch-all below and fire a callback literally named
        // "refresh_all" — a magic string no developer ever wrote, which did
        // nothing unless they happened to declare that exact name, and which
        // collided with a real MActionCallback('refresh_all').
        return '''
        val intent$index = android.content.Intent(context, $className::class.java).apply {
            action = mosaicRefreshAction
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val pendingIntent$index = android.app.PendingIntent.getBroadcast(context, appWidgetId * 100 + $index, intent$index, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.$viewId, pendingIntent$index)
        ''';
      } else if (action['__type'] == 'HWToggleAction') {
        final key = kotlinEscape(action['key'] as String);
        return '''
        val intent$index = android.content.Intent(context, $className::class.java).apply {
            action = mosaicToggleAction
            putExtra("toggleKey", "$key")
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
    }).join('\n        ');

    // Per-size trees. API 31+ takes a map of minimum size -> RemoteViews and
    // the launcher picks the largest entry that fits; below 31 there is no way
    // to switch, so the full tree is used at every size.
    //
    // The breakpoint is the widget's own declared minimum, using the platform's
    // cell formula (70dp per cell, minus 30dp of inter-cell padding). The full
    // tree therefore appears at the size the developer designed it for, and the
    // compact one only when the user has resized below that.
    final layoutRes = 'R.layout.hw_${safe.toLowerCase()}';
    final minW = (70 * def.width - 30).clamp(1, 1 << 20);
    final minH = (70 * def.height - 30).clamp(1, 1 << 20);
    final rootViewsExpr = def.compactRoot == null
        ? 'buildViews(context, appWidgetManager, appWidgetId, $layoutRes)'
        : '''if (android.os.Build.VERSION.SDK_INT >= 31) {
            RemoteViews(mapOf(
                android.util.SizeF(1f, 1f) to buildViews(context, appWidgetManager, appWidgetId, ${layoutRes}_compact),
                android.util.SizeF(${minW}f, ${minH}f) to buildViews(context, appWidgetManager, appWidgetId, $layoutRes)
            ))
        } else {
            buildViews(context, appWidgetManager, appWidgetId, $layoutRes)
        }''';

    await file.writeAsString('''$kotlinSentinel
package ${config.app.androidPackage}.mosaic_generated

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import ${config.app.androidPackage}.R

class $className : AppWidgetProvider() {
    private val mosaicCallbackAction = "${config.app.androidPackage}.MOSAIC_CALLBACK"
    private val mosaicToggleAction = "${config.app.androidPackage}.MOSAIC_TOGGLE"$refreshConst

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
$refreshReceive        if (intent.action == mosaicToggleAction) {
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
        ${def.updateInterval != null ? '''
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val intent = android.content.Intent(context, $className::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val pendingIntent = android.app.PendingIntent.getBroadcast(context, 0, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        alarmManager.setRepeating(android.app.AlarmManager.RTC, System.currentTimeMillis(), ${def.updateInterval}, pendingIntent)
        ''' : ''}
    }

    /// Inflates [layoutRes] and applies every update this widget declares.
    ///
    /// Actions naming a view the layout does not contain are skipped by
    /// RemoteViews itself, so one set of calls serves every size variant.
    private fun buildViews(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, layoutRes: Int): RemoteViews {
        val prefs = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, layoutRes)

        $bindLogic
        $timerLogic
        $visibilityLogic
        $staticImageLogic
        $colorBindLogic
        $clipLogic
        $a11yLogic
        $networkImageLogic
        $sparklineLogic
        $barChartLogic
        $listAdapterLogic
        $buttonLogic

        return views
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        // Refresh native device metrics first, so bindings below read current
        // values rather than whatever the app last stored.
        MosaicDevice.populate(context)
        val views = $rootViewsExpr

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
        val $fieldName = SwitchCompat(this).apply {
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
import androidx.appcompat.widget.SwitchCompat
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
