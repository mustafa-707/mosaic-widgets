// Android generator for Mosaic.
//
// Split across parts to keep each file navigable:
//   src/android_layout.dart   — sentinels, layout-param helpers, the handler
//                               interface, and small XML utilities
//   src/android_handlers.dart — one AndroidNodeHandler per DSL node type
//
// Parts share one library, so private members remain visible across all three.
library;

import 'dart:io';
import 'package:mosaic_core/mosaic_core.dart';
import 'package:path/path.dart' as p;

part 'src/android_layout.dart';
part 'src/android_handlers.dart';
part 'src/android_widgets.dart';
part 'src/android_emitters.dart';
part 'src/android_features.dart';
part 'src/android_providers.dart';


class AndroidGenerator {
  final MosaicConfig config;
  final List<IRDefinition> definitions;

  /// Live activity IR collected by the widget runner. Plumbed through for a
  /// later wave; the Android generator does not emit anything from it yet.
  final List<Map<String, dynamic>> liveActivities;

  /// Control IR collected by the widget runner. Plumbed through for a
  /// later wave; the Android generator does not emit anything from it yet.
  final List<Map<String, dynamic>> controls;

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

  /// Material You palette entries referenced by this build, keyed by resource
  /// name. Values carry both the framework resource to use on API 31+ and the
  /// literal fallback for older devices.
  final Map<
      String,
      ({
        String sysLight,
        String sysDark,
        String fallbackLight,
        String fallbackDark
      })> _systemColors = {};

  /// Allocates a colour resource backed by the user's Material You palette.
  ///
  /// Emitted as four resources rather than one: `values/` and `values-night/`
  /// hold the literal fallback, and `values-v31/` and `values-night-v31/`
  /// override with `@android:color/system_*`. Referencing the framework colour
  /// unconditionally fails resource linking on API 30 and below, where those
  /// names do not exist — the qualifier is what makes the fallback real rather
  /// than aspirational.
  String registerSystemColor(
    String sysLight,
    String sysDark,
    String fallbackLight,
    String fallbackDark,
  ) {
    final name = 'mosaic_sys_${_colorHash('$sysLight|$fallbackLight|$fallbackDark')}';
    _systemColors[name] = (
      sysLight: sysLight,
      sysDark: sysDark,
      fallbackLight: fallbackLight,
      fallbackDark: fallbackDark,
    );
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
  final List<({String viewId, String key, String target, double opacity})>
      _colorBinds = [];

  /// Registers a runtime color bind for [viewId] resolving prefs [key] applied
  /// via [target] ('text' | 'background' | 'progress'). [opacity] (default 1.0)
  /// is applied to the resolved color's alpha channel in the provider; an
  /// opacity of 1.0 leaves the parsed color untouched.
  void registerColorBind(String viewId, String key, String target,
      {double opacity = 1.0}) {
    _colorBinds
        .add((viewId: viewId, key: key, target: target, opacity: opacity));
  }

  /// Format directive for bound text keys: maps a bind key to its MText
  /// `format` ('decimal'|'currency'|'percent'|'date'|'relativeTime'). When set,
  /// the provider formats the resolved string via `MosaicData.formatValue`
  /// instead of showing it raw. Per-definition (cleared in [generate]).
  final Map<String, String> _textFormats = {};

  /// Records that bound text [key] should be rendered with [format].
  void registerTextFormat(String key, String format, {String? currencyCode}) {
    _textFormats[key] = format;
    if (currencyCode != null) _textCurrencies[key] = currencyCode;
  }

  /// ISO 4217 codes declared alongside a currency format, keyed by bind key.
  /// Absent means "use the device's currency", which is only right when the
  /// amount really is in the user's own currency.
  final Map<String, String> _textCurrencies = {};

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
    final throwBinds = <String, Set<String>>{};
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

  /// Network images in the CURRENT definition: view id → (key, isBind). The
  /// provider loads each from the disk cache at update time.
  final List<({String viewId, String key, bool isBind})> _networkImages = [];

  /// Records a network image for the provider to populate.
  void registerNetworkImage(String viewId, String key, {required bool isBind}) {
    if (_networkImages.any((e) => e.viewId == viewId)) return;
    _networkImages.add((viewId: viewId, key: key, isBind: isBind));
  }

  /// Bound views to update at render: the concrete view id, its stored key and
  /// what kind of view it is.
  ///
  /// Keyed by id rather than by key, so the same value rendered in two places
  /// updates both.
  final List<({String viewId, String key, String kind})> _boundViews = [];

  /// Records a bound view for the provider to update.
  void registerBoundView(String viewId, String key, String kind) {
    if (_boundViews.any((e) => e.viewId == viewId)) return;
    _boundViews.add((viewId: viewId, key: key, kind: kind));
  }

  /// Occurrence counter behind [uniqueViewId], reset per widget.
  final Map<String, int> _viewIdOccurrences = {};

  /// A view id for [key] under [prefix], unique within the current widget.
  ///
  /// The same key legitimately appears more than once — a value in a header and
  /// a footer, an avatar in two places, a unit toggle driving two rows. Deriving
  /// the id from the key alone gave those the SAME id, and RemoteViews acts on
  /// the first match only: every later occurrence silently never updated.
  String uniqueViewId(String prefix, String key) {
    final base = '${prefix}_${idForKey(key)}';
    final n = _viewIdOccurrences[base] = (_viewIdOccurrences[base] ?? 0) + 1;
    return n == 1 ? base : '${base}_$n';
  }

  /// Sparklines to rasterise at update time: RemoteViews cannot draw vectors,
  /// so the provider renders each series to a bitmap and sets it on an
  /// ImageView.
  final List<({String viewId, String key, String color, double stroke, bool fill})>
      _sparklines = [];

  /// Records a sparkline for the provider to rasterise.
  void registerSparkline(String viewId, String key,
      {required String color, required double stroke, required bool fill}) {
    if (_sparklines.any((e) => e.viewId == viewId)) return;
    _sparklines
        .add((viewId: viewId, key: key, color: color, stroke: stroke, fill: fill));
  }

  /// Bar charts to rasterise at update time, for the same reason as
  /// [_sparklines]: RemoteViews cannot draw vectors.
  final List<({String viewId, String key, String color, double spacing, double radius})>
      _barCharts = [];

  /// Records a bar chart for the provider to rasterise.
  void registerBarChart(String viewId, String key,
      {required String color, required double spacing, required double radius}) {
    if (_barCharts.any((e) => e.viewId == viewId)) return;
    _barCharts.add(
        (viewId: viewId, key: key, color: color, spacing: spacing, radius: radius));
  }

  /// Bound accessibility labels: view id → stored key. Applied by the provider
  /// with setContentDescription.
  final List<({String viewId, String key})> _contentDescriptions = [];

  /// Records a bound accessibility label for the provider to apply.
  void registerContentDescription(String viewId, String key) {
    if (_contentDescriptions.any((e) => e.viewId == viewId)) return;
    _contentDescriptions.add((viewId: viewId, key: key));
  }

  /// Views needing outline clipping (rounded or circular images). RemoteViews
  /// has no clip API, so the provider calls setClipToOutline on each.
  final Set<String> _clippedViews = {};

  /// Marks [viewId] as needing `setClipToOutline`.
  void registerClippedView(String viewId) => _clippedViews.add(viewId);

  /// Set while emitting a widget's ROOT node so the outermost container fills
  /// the tile instead of wrapping its content. Consumed by the first container
  /// that sees it, so nested containers keep sizing to their content.
  ///
  /// Without it the root wraps, and a rounded background then renders as a
  /// narrow capsule instead of covering the widget.
  bool fillRoot = false;

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
    this.controls = const [],
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
    _register(ActivityIndicatorHandler());
    _register(NetworkImageHandler());
    _register(FlipperHandler());
    _register(SemanticsHandler());
    _register(ButtonHandler());
    _register(VisibilityHandler());
    _register(ImageHandler());
    _register(ProgressBarHandler());
    _register(ListViewHandler());
    _register(TimerHandler());
    _register(PositionedHandler());
    _register(CenterHandler());
    _register(AlignHandler());
    _register(SizedBoxHandler());
    _register(FlexibleHandler());
    _register(SparklineHandler());
    _register(BarChartHandler());
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

      final usedBinds = <String, Set<String>>{};
      final visibilityKeys = <String>[];
      final timers = <String, String>{};
      final buttons = <Map<String, dynamic>>[];
      _staticImageUris.clear();
      _visibilityWithReplacement.clear();
      _timersCountUp.clear();
      _colorBinds.clear();
      _textFormats.clear();
      _textCurrencies.clear();
      _listViews.clear();
      _networkImages.clear();
      _sparklines.clear();
      _viewIdOccurrences.clear();
      _boundViews.clear();
      _barCharts.clear();
      _clippedViews.clear();
      _contentDescriptions.clear();
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

      // A second tree for small sizes, rendered into its own layout file.
      //
      // Deliberately generated with the *same* accumulated state as the root
      // above, so the provider emits one set of update calls covering both.
      // `uniqueViewId` keeps the two trees' ids distinct, and a RemoteViews
      // action whose id is absent from the inflated layout is skipped —
      // `BaseReflectionAction.apply` returns early on a null `findViewById`, it
      // does not throw. So each tree quietly receives only the calls that name
      // views it actually contains.
      if (def.compactRoot != null) {
        final compactXml = _generateLayoutXml(
          def.compactRoot!,
          usedBinds,
          visibilityKeys,
          timers,
          buttons,
        );
        await File(p.join(layoutDir.path, '${layoutName}_compact.xml'))
            .writeAsString(compactXml);
      }

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
    await _generateRefreshSources(projectRoot);
    await _generateDeviceMetrics(projectRoot);
    await _generateHostPlugin(projectRoot);

    await _generateLiveActivityLayouts(layoutDir);
    await _generateLiveActivityManager(projectRoot);

    await _generateControlTiles(projectRoot);

    await _writeDrawables(resDir);
    await _writeColors(resDir);
    await _writeStrings(resDir);
    await _writeLocalizations(resDir);

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
      final usedBinds = <String, Set<String>>{};
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
  /// Generates `MosaicRefreshSources.kt` — the network sources a refresh button
  /// fetches directly from the widget process.
  ///
  /// Mirrors the iOS generator: a widget's refresh button cannot run Dart, so
  /// without a declared source it can only redraw stored data and wait for the
  /// app. With one, the provider fetches and stores the values itself, so the
  /// button works while the app is closed.
  ///
  /// Always emitted (empty table when nothing is declared) so providers compile
  /// either way.
  Future<void> _writeDrawables(Directory resDir) async {
    final drawableDir = Directory(p.join(resDir.path, 'drawable'));
    if (_drawables.isNotEmpty && !drawableDir.existsSync()) {
      drawableDir.createSync(recursive: true);
    }
    for (final entry in _drawables.entries) {
      final file = File(p.join(drawableDir.path, '${entry.key}.xml'));
      await file.writeAsString(entry.value);
    }

    // Drop generated drawables this build did not produce.
    //
    // Their names are content hashes, so changing a radius or a colour writes a
    // new file and strands the old one. A stranded drawable is not merely
    // clutter: it still references the colour resource it was written against,
    // and once nothing re-registers that colour, AAPT fails the build with
    // "resource color/mosaic_… not found" pointing at a file no layout uses.
    //
    // Only files carrying the sentinel are considered, so a hand-written
    // drawable sharing the prefix is never touched.
    if (!drawableDir.existsSync()) return;
    for (final f in drawableDir.listSync().whereType<File>()) {
      final name = p.basenameWithoutExtension(f.path);
      if (!f.path.endsWith('.xml') || _drawables.containsKey(name)) continue;
      String head;
      try {
        head = await f.readAsString();
      } on FileSystemException {
        continue;
      }
      if (!head.startsWith(xmlSentinel) &&
          !head.split('\n').take(3).any((l) => l.contains('MOSAIC-GENERATED'))) {
        continue;
      }
      await f.delete();
    }
  }

  /// Writes the adaptive color resources to `res/values/mosaic_colors.xml`
  /// (light) and `res/values-night/mosaic_colors.xml` (dark). Both files lead
  /// with the XML declaration (AAPT requirement) then the generated sentinel.
  Future<void> _writeColors(Directory resDir) async {
    if (_colors.isEmpty && _systemColors.isEmpty) return;
    final entries = _colors.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final sysEntries = _systemColors.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    String wrap(String body) => '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<resources>
$body
</resources>''';

    /// The base files carry every colour, with system entries at their literal
    /// fallback — so a device below API 31 has a complete, valid set.
    String buildFile(bool night) {
      final body = [
        ...entries.map((e) =>
            '    <color name="${e.key}">${night ? e.value.dark : e.value.light}</color>'),
        ...sysEntries.map((e) =>
            '    <color name="${e.key}">${night ? e.value.fallbackDark : e.value.fallbackLight}</color>'),
      ].join('\n');
      return wrap(body);
    }

    /// The v31 files override only the system entries, pointing them at the
    /// live Material You palette. Ordinary colours are inherited unchanged.
    String buildSystemFile(bool night) => wrap(sysEntries
        .map((e) =>
            '    <color name="${e.key}">@android:color/${night ? e.value.sysDark : e.value.sysLight}</color>')
        .join('\n'));

    Future<void> write(String dir, String contents) async {
      final d = Directory(p.join(resDir.path, dir));
      if (!d.existsSync()) d.createSync(recursive: true);
      await File(p.join(d.path, 'mosaic_colors.xml')).writeAsString(contents);
    }

    await write('values', buildFile(false));
    await write('values-night', buildFile(true));
    if (sysEntries.isNotEmpty) {
      await write('values-v31', buildSystemFile(false));
      await write('values-night-v31', buildSystemFile(true));
    }
  }

  /// Writes widget picker descriptions to `res/values/mosaic_strings.xml`.
  ///
  /// `appwidget-provider`'s `android:description` only accepts a string
  /// *resource* reference — a literal fails resource linking with
  /// "is incompatible with attribute description (attr) reference".
  Future<void> _writeStrings(Directory resDir) async {
    final described = config.widgets.where((w) => w.description != null);
    if (described.isEmpty) return;

    final body = described
        .map((w) =>
            '    <string name="${descriptionRes(w.name)}">${xmlEscape(w.description!)}</string>')
        .join('\n');

    final valuesDir = Directory(p.join(resDir.path, 'values'));
    if (!valuesDir.existsSync()) valuesDir.createSync(recursive: true);
    await File(p.join(valuesDir.path, 'mosaic_strings.xml'))
        .writeAsString('''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<resources>
$body
</resources>''');
  }

  /// The string resource name holding [widgetName]'s picker description.
  static String descriptionRes(String widgetName) =>
      'mosaic_desc_${sanitizeIdentifier(widgetName).toLowerCase()}';

  /// The string resource name for a localization key.
  static String localizedRes(String key) =>
      'mosaic_s_${sanitizeIdentifier(key).toLowerCase()}';

  /// Writes localized widget text as real Android string resources: the default
  /// locale into `values/`, the rest into `values-<locale>/`.
  ///
  /// A widget renders outside the Flutter engine, so Dart's localization is
  /// unavailable — the platform has to do the selection.
  Future<void> _writeLocalizations(Directory resDir) async {
    if (config.strings.isEmpty) return;
    final defaultLocale = config.defaultLocale;

    for (final entry in config.strings.entries) {
      // The default locale is the unqualified folder, so it is the fallback for
      // any language without its own table.
      final dirName =
          entry.key == defaultLocale ? 'values' : 'values-${entry.key}';
      final dir = Directory(p.join(resDir.path, dirName));
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final body = (entry.value.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
          .map((s) =>
              '    <string name="${localizedRes(s.key)}">${xmlEscape(s.value)}</string>')
          .join('\n');

      await File(p.join(dir.path, 'mosaic_localized.xml'))
          .writeAsString('''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<resources>
$body
</resources>''');
    }
  }

  String _generateLayoutXml(
    IRNode node,
    Map<String, Set<String>> usedBinds,
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
  /// Maps `MSystemColor` names to their Material You resources. Kept in step
  /// with the enum in `platform/flutter/lib/dsl.dart`; a name missing here
  /// falls back rather than failing the build.
  static const Map<String, ({String light, String dark})> _systemColorNames = {
    'accent': (light: 'system_accent1_600', dark: 'system_accent1_200'),
    'accentMuted': (light: 'system_accent2_600', dark: 'system_accent2_200'),
    'surface': (light: 'system_neutral1_50', dark: 'system_neutral1_900'),
    'onSurface': (light: 'system_neutral1_900', dark: 'system_neutral1_50'),
    'onSurfaceMuted': (light: 'system_neutral2_700', dark: 'system_neutral2_200'),
  };

  String parseColor(Map<String, dynamic> colorData) {
    // Bind form has no static color: emit a transparent placeholder. The
    // provider's bind loop overrides this with the resolved color at update.
    if (isColorBind(colorData)) return '#00000000';

    final double opacity = (colorData['opacity'] ?? 1.0).toDouble();
    final String hex = (colorData['hex'] as String?) ?? '#FFFFFF';
    final light = _applyOpacity(hex, opacity);

    final dark = colorData['dark'] as String?;
    final darkValue = dark != null ? _applyOpacity(dark, opacity) : light;

    // MColor.system: the wire keeps hex/dark as the fallback, so everything
    // below this point still has a real colour to fall back to.
    final system = colorData['system'] as String?;
    if (system != null) {
      final entry = _systemColorNames[system];
      if (entry != null) {
        return registerSystemColor(
            entry.light, entry.dark, light, darkValue);
      }
      // An unknown name is a DSL/generator version mismatch, not a user error
      // worth failing a build over — the fallback still renders correctly.
    }

    if (dark != null) {
      // Adaptive: allocate a day/night color resource and reference it.
      return registerColor(light, darkValue);
    }
    return light;
  }

  String nodeToXml(
    IRNode node,
    Map<String, Set<String>> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
    bool isRoot = false,
  }) {
    final handler = _handlers[node.type];
    if (handler != null) {
      // The outermost container must fill the tile, not wrap its content.
      if (isRoot) fillRoot = true;
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
      fillRoot = false;

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

    // Picker metadata. Without a previewLayout the picker falls back to
    // previewImage and then to the app icon — which is why an unconfigured
    // Flutter project shows the Flutter logo for every widget. Rendering the
    // widget's own layout is the recommended Android 12+ approach and needs no
    // extra asset. `description` (Android 12+) is ignored on older systems.
    final layoutRes = 'hw_${_safeName(def.name).toLowerCase()}';
    final previewLayout = ' android:previewLayout="@layout/$layoutRes"';
    final widgetConfig = config.widgets
        .where((w) => w.name == def.name)
        .cast<MosaicWidgetConfig?>()
        .firstWhere((w) => true, orElse: () => null);
    // Must be a string RESOURCE reference; a literal fails resource linking.
    final description = widgetConfig?.description != null
        ? ' android:description="@string/${descriptionRes(def.name)}"'
        : '';

    return '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="${minWidth}dp"
    android:minHeight="${minHeight}dp"
    android:updatePeriodMillis="$period"
    android:initialLayout="@layout/$layoutRes"
    $resizeMode$previewLayout$description
    $preview$configure>
</appwidget-provider>''';
  }

}
