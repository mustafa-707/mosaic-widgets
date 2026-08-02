// The generated `Widget` / `TimelineProvider` Swift for each definition,
// including push configuration, gallery metadata, and family support.
part of '../ios.dart';

extension IosWidgetViews on IosGenerator {
  String _pushConfiguration(IRDefinition def, {bool configurable = false}) {
    final configuration = configurable
        ? 'AppIntentConfiguration(kind: kind, intent: ${def.name}ConfigIntent.self, provider: ${def.name}Provider())'
        : 'StaticConfiguration(kind: kind, provider: ${def.name}Provider())';
    final fallbackDescription = configurable
        ? 'This is an auto-generated configurable widget.'
        : 'This is an auto-generated home widget.';
    final base = '''$configuration { entry in
            ${def.name}View(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("${_galleryTitle(def)}")
        .description("${_galleryDescription(def, fallbackDescription)}")
        .supportedFamilies(families)
        .contentMarginsDisabled()''';

    if (!_pushEnabled(def)) return '        $base';

    // The handler type carries macOS 26 too, so the call site must match or it
    // will not resolve on a macOS target.
    return '''        if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
            return $base
                .pushHandler(${def.name}PushHandler.self)
        } else {
            return $base
        }''';
  }

  /// The `WidgetPushHandler` for [def], or nothing when push is disabled.
  ///
  /// The token is stored in the App Group rather than sent anywhere: only the
  /// host app can reach your server, and the extension may run while the app is
  /// not. The app reads `mosaic_widget_push_token` on next foreground and
  /// registers it.
  String _pushHandler(IRDefinition def) {
    if (!_pushEnabled(def)) return '';
    return '''

/// Receives the APNs token WidgetKit issues for this widget.
///
/// Send `{"aps":{"content-changed":true}}` to that token with
/// `apns-push-type: widgets` and topic `<bundle-id>.push-type.widgets` to
/// reload the timeline with the app closed.
@available(iOS 26.0, macOS 26.0, watchOS 26.0, *)
struct ${def.name}PushHandler: WidgetPushHandler {
    init() {}

    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        let hex = pushInfo.token.map { String(format: "%02x", \$0) }.joined()
        guard let defaults = UserDefaults(suiteName: kMosaicAppGroup) else { return }
        // Keyed per widget kind: each kind gets its own token.
        defaults.set(hex, forKey: "mosaic_widget_push_token_${def.name}")
        defaults.synchronize()
        NSLog("[Mosaic] widget push token for ${def.name}: \\(hex.prefix(8))…")
    }
}''';
  }

  /// A Swift array literal of the network-image URLs [def] renders, for the
  /// provider to prefetch.
  ///
  /// Literal URLs are emitted directly; bound ones resolve from stored data at
  /// runtime, so a URL delivered by a `refresh:` source is downloaded on the
  /// same pass that fetched it.
  String _networkImageUrls(IRDefinition def) {
    final literals = <String>[];
    final binds = <String>[];

    void walk(Object? value) {
      if (value is Map) {
        if (value['__type'] == 'HWNetworkImage') {
          final url = value['url'];
          if (url is Map && url['__type'] == 'HWBind') {
            binds.add(
                'mosaicStr(loadData()["${swiftEscape(url['key'] as String)}"])');
          } else if (url != null) {
            literals.add('"${swiftEscape(url.toString())}"');
          }
        }
        value.values.forEach(walk);
      } else if (value is List) {
        value.forEach(walk);
      }
    }

    walk(def.root.toJson());
    if (literals.isEmpty && binds.isEmpty) return '[]';
    final parts = [
      ...literals,
      // Bound URLs may be absent; compactMap drops the nils.
      ...binds,
    ];
    return '[${parts.join(', ')}].compactMap { \$0 }';
  }

  /// The widget gallery title for [def] — the config `label` when set,
  /// otherwise the widget name.
  String _galleryTitle(IRDefinition def) {
    for (final w in config.widgets) {
      if (w.name == def.name) return swiftEscape(w.displayName);
    }
    return swiftEscape(def.name);
  }

  /// The widget gallery subtitle for [def], or a generic fallback.
  String _galleryDescription(IRDefinition def, String fallback) {
    for (final w in config.widgets) {
      if (w.name == def.name && w.description != null) {
        return swiftEscape(w.description!);
      }
    }
    return fallback;
  }

  String _generateSwiftUiWidget(IRDefinition def) {
    // A definition carrying user-configurable params is emitted as an iOS 17+
    // AppIntentConfiguration widget; otherwise it stays a StaticConfiguration
    // widget compatible with iOS 14/16.
    if (def.params.isNotEmpty) {
      return _generateConfigurableWidget(def);
    }
    final usedKeys = collectBindKeys(def.root).toList()..sort();
    final keyList = usedKeys.map((k) => '"${swiftEscape(k)}"').join(', ');
    return '''$kGeneratedSentinel
import SwiftUI
import WidgetKit
import AppIntents

struct ${def.name}Entry: TimelineEntry {
    let date: Date
    let data: [String: Any]
}

struct ${def.name}Provider: TimelineProvider {
    func placeholder(in context: Context) -> ${def.name}Entry {
        ${def.name}Entry(date: Date(), data: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (${def.name}Entry) -> ()) {
        let entry = ${def.name}Entry(date: Date(), data: loadData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Fetch, then complete. WidgetKit waits for `completion`, so the fresh
        // values render on this pass. Completing first and reloading afterwards
        // would depend on a second reload, which the system may throttle away.
        Task {
            await MosaicRefreshSources.run(keys: [$keyList])
            // Network images: download after the refresh, so a URL that arrived
            // in this same pass is fetched immediately rather than one timeline
            // later. Cached URLs cost nothing.
            await MosaicImageCache.prefetch(${_networkImageUrls(def)})
            let entry = ${def.name}Entry(date: Date(), data: loadData())

            ${def.updateInterval != null ? '''
            let nextUpdate = Calendar.current.date(byAdding: .second, value: ${def.updateInterval! ~/ 1000}, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            ''' : '''
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            '''}

            completion(timeline)
        }
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "${config.app.iosAppGroup}"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: ${def.name}Provider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        // Refresh native device metrics first, so bindings read current values
        // rather than whatever the app last stored.
        MosaicDevice.populate()
        // Re-read from disk: the app and the refresh code write through other
        // UserDefaults instances, and without this the widget can render a
        // snapshot taken before those writes.
        defaults.synchronize()
        for k in [$keyList] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

struct ${def.name}View: View {
    var entry: ${def.name}Entry
${_familyEnvironment(def)}
    var body: some View {
        GeometryReader { geometry in
            ${_rootForFamily(def)}
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .widgetURL(URL(string: loadGlobalUrl()))
    }

    private func loadGlobalUrl() -> String {
        return entry.data["global_url"] as? String ?? ""
    }
}

// NOTE: On iOS, widget sizing is governed by WidgetFamily / supportedFamilies,
// not by the definition's width/height. The definition's width=${def.width},
// height=${def.height} and previewImage are advisory on iOS and not used by
// WidgetKit, which sizes by family and renders the placeholder() view for
// previews. resizeMode=${def.resizeMode} only acts as a fallback for deriving
// supportedFamilies when mosaic.yaml lists no ios.families for this widget.
struct ${def.name}Widget: Widget {
    let kind: String = "${def.name}"

    // Built at runtime so iOS 16+ lock-screen accessory families can be added
    // under an availability check (their WidgetFamily cases are iOS 16+).
    private var families: [WidgetFamily] {
        ${_supportedFamiliesProperty(def)}
    }

    var body: some WidgetConfiguration {
${_pushConfiguration(def)}
    }
}${_pushHandler(def)}
''';
  }

  /// Maps a param `type` to the Swift property type used inside the generated
  /// `WidgetConfigurationIntent`. `choice` is modelled as a plain `String`
  /// (the chosen value); the available choices are surfaced as a doc comment.
  static String _paramSwiftType(String type) {
    switch (type) {
      case 'number':
        return 'Double';
      case 'toggle':
        return 'Bool';
      case 'text':
      case 'choice':
      default:
        return 'String';
    }
  }

  /// Renders the Swift literal for a param's default value, coerced to the
  /// Swift type chosen by [_paramSwiftType].
  static String _paramDefaultLiteral(String type, Object? defaultValue) {
    switch (type) {
      case 'number':
        final n = defaultValue is num ? defaultValue : 0;
        return '${n.toDouble()}';
      case 'toggle':
        return defaultValue == true ? 'true' : 'false';
      case 'text':
      case 'choice':
      default:
        final s = defaultValue == null ? '' : '$defaultValue';
        return '"${swiftEscape(s)}"';
    }
  }

  /// Swift expression that stringifies a configured param value so it can be
  /// stored in the `[String: Any]` entry-data dict using the same
  /// string-valued convention as App-Group-loaded data.
  static String _stringifyParam(String type, String varName) {
    switch (type) {
      case 'number':
        // Drop a trailing `.0` for whole numbers so bound text reads cleanly.
        return 'configuration.$varName == configuration.$varName.rounded() '
            '? String(Int(configuration.$varName)) '
            ': String(configuration.$varName)';
      case 'toggle':
        return 'configuration.$varName ? "true" : "false"';
      case 'text':
      case 'choice':
      default:
        return 'configuration.$varName';
    }
  }

  /// Generates an iOS 17+ configurable widget for a definition carrying
  /// `params`. Produces, all gated `@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)`:
  ///  - a `<Name>ConfigIntent: WidgetConfigurationIntent` with one `@Parameter`
  ///    per param,
  ///  - a `<Name>Provider: AppIntentTimelineProvider` whose
  ///    `timeline(for:in:)` copies each configured value into `entry.data`
  ///    under the param `key` (stringified), so the existing `MBind` resolution
  ///    (`entry.data[key]`) shows the chosen value, and
  ///  - an `AppIntentConfiguration`-based `<Name>Widget`.
  ///
  /// The whole struct family is `@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)` because
  /// `AppIntentConfiguration`/`AppIntentTimelineProvider`/
  /// `WidgetConfigurationIntent` are iOS-17 APIs; the WidgetBundle registers it
  /// under `if #available(iOS 17.0, *)`.
  String _generateConfigurableWidget(IRDefinition def) {
    final usedKeys = collectBindKeys(def.root).toList()..sort();
    final keyList = usedKeys.map((k) => '"${swiftEscape(k)}"').join(', ');
    final params = def.params;

    final paramDecls = params.map((pm) {
      final key = pm['key'] as String;
      final type = pm['type'] as String;
      final label = (pm['label'] as String?) ?? key;
      final swiftType = _paramSwiftType(type);
      final def0 = _paramDefaultLiteral(type, pm['defaultValue']);
      final choices = (pm['choices'] as List?)?.cast<Object?>() ?? const [];
      final choiceDoc = (type == 'choice' && choices.isNotEmpty)
          ? '    // choices: ${choices.map((c) => '"${swiftEscape('$c')}"').join(', ')}\n'
          : '';
      return '$choiceDoc'
          '    @Parameter(title: "${swiftEscape(label)}", default: $def0)\n'
          '    var $key: $swiftType';
    }).join('\n\n');

    final copyLines = params.map((pm) {
      final key = pm['key'] as String;
      final type = pm['type'] as String;
      final varName = key;
      return '        data["${swiftEscape(key)}"] = ${_stringifyParam(type, varName)}';
    }).join('\n');

    final timelinePolicy = def.updateInterval != null
        ? '''
        let nextUpdate = Calendar.current.date(byAdding: .second, value: ${def.updateInterval! ~/ 1000}, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))'''
        : '''
        return Timeline(entries: [entry], policy: .atEnd)''';

    return '''$kGeneratedSentinel
import SwiftUI
import WidgetKit
import AppIntents

struct ${def.name}Entry: TimelineEntry {
    let date: Date
    let data: [String: Any]
}

// iOS 17+ user-configurable parameters surfaced in the widget's edit sheet.
// The chosen values are copied into the timeline entry's `data` dict by the
// provider so the widget tree's existing bind resolution (entry.data[key])
// renders them.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ${def.name}ConfigIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "${swiftEscape(def.name)}"
    static let description = IntentDescription("Configure this widget.")

$paramDecls

    init() {}
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ${def.name}Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ${def.name}Entry {
        ${def.name}Entry(date: Date(), data: [:])
    }

    /// What the complication picker offers before the user configures anything.
    ///
    /// Optional on iOS and macOS, where the protocol supplies a default, but
    /// **required on watchOS** — without it the provider does not conform and
    /// the extension will not build for a watch target.
    func recommendations() -> [AppIntentRecommendation<${def.name}ConfigIntent>] {
        [AppIntentRecommendation(intent: ${def.name}ConfigIntent(),
                                 description: Text("${def.name}"))]
    }

    func snapshot(for configuration: ${def.name}ConfigIntent, in context: Context) async -> ${def.name}Entry {
        ${def.name}Entry(date: Date(), data: mergedData(configuration))
    }

    func timeline(for configuration: ${def.name}ConfigIntent, in context: Context) async -> Timeline<${def.name}Entry> {
        let entry = ${def.name}Entry(date: Date(), data: mergedData(configuration))
$timelinePolicy
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "${config.app.iosAppGroup}"

    // Loads App-Group-backed data, then overlays the configured param values
    // (stringified) under their param keys so binds resolve to the user's
    // choices.
    private func mergedData(_ configuration: ${def.name}ConfigIntent) -> [String: Any] {
        var data = loadData()
$copyLines
        return data
    }

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: ${def.name}Provider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        // Refresh native device metrics first, so bindings read current values
        // rather than whatever the app last stored.
        MosaicDevice.populate()
        // Re-read from disk: the app and the refresh code write through other
        // UserDefaults instances, and without this the widget can render a
        // snapshot taken before those writes.
        defaults.synchronize()
        for k in [$keyList] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ${def.name}View: View {
    var entry: ${def.name}Entry

    var body: some View {
        GeometryReader { geometry in
            ${renderRoot(def.root)}
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .widgetURL(URL(string: loadGlobalUrl()))
    }

    private func loadGlobalUrl() -> String {
        return entry.data["global_url"] as? String ?? ""
    }
}

// NOTE: width=${def.width}, height=${def.height}, previewImage and resizeMode=${def.resizeMode}
// are advisory on iOS; WidgetKit sizes by family.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ${def.name}Widget: Widget {
    let kind: String = "${def.name}"

    private var families: [WidgetFamily] {
        ${_supportedFamiliesProperty(def)}
    }

    var body: some WidgetConfiguration {
${_pushConfiguration(def, configurable: true)}
    }
}${_pushHandler(def)}
''';
  }

  /// Valid `ios.families` values: WidgetKit system families + the three iOS 16+
  /// lock-screen accessory families.
  static const Set<String> _systemFamilies = {
    'systemSmall',
    'systemMedium',
    'systemLarge',
    'systemExtraLarge',
  };
  static const Set<String> _accessoryFamilies = {
    'accessoryRectangular',
    'accessoryCircular',
    'accessoryInline',
  };

  /// Emits the Swift body of the `families` computed property for [def].
  ///
  /// WidgetKit sizes widgets by family, so the families declared in mosaic.yaml
  /// (`ios.families`) are authoritative. When that list is empty/absent we fall
  /// back to deriving sensible families from the definition's advisory
  /// `resizeMode`/size so the widget is not silently un-renderable.
  ///
  /// Lock-screen accessory families (iOS 16+) are appended under an
  /// `if #available(iOS 16.0, *)` gate so the extension still compiles when
  /// targeting older iOS. An unknown family value is a gen-time error.
  /// The `@Environment` line a per-family definition needs, or nothing.
  ///
  /// Declared only when a compact tree exists — an unused environment property
  /// is a warning in generated code a developer cannot edit away.
  String _familyEnvironment(IRDefinition def) => def.compactRoot == null
      ? '    '
      : '    @Environment(\\.widgetFamily) private var family\n    ';

  /// The view body: one tree, or a switch on family when a compact variant is
  /// declared.
  ///
  /// `systemSmall` and the circular/inline accessory families are the sizes with
  /// no room for a full layout, so they take the compact tree.
  String _rootForFamily(IRDefinition def) {
    final compact = def.compactRoot;
    if (compact == null) return renderRoot(def.root);
    // The decision goes through a helper rather than naming the accessory cases
    // inline: those enum cases do not exist on macOS, and a view body is an
    // awkward place to put a compile fence.
    return '''Group {
                if mosaicPrefersCompact(family) {
                    ${renderRoot(compact)}
                } else {
                    ${renderRoot(def.root)}
                }
            }''';
  }

  String _supportedFamiliesProperty(IRDefinition def) {
    final widget = config.widgets.firstWhere(
      (w) => w.name == def.name,
      orElse: () => throw StateError(
          'No widget config entry named "${def.name}". Add it to mosaic.yaml.'),
    );
    final families = widget.ios.families;
    final List<String> resolved;
    if (families.isNotEmpty) {
      resolved = families.toList();
    } else {
      // Fallback derived from the advisory resizeMode / declared size.
      switch (def.resizeMode) {
        case 'both':
          resolved = ['systemSmall', 'systemMedium', 'systemLarge'];
          break;
        case 'horizontal':
          resolved = ['systemMedium', 'systemLarge'];
          break;
        case 'vertical':
          resolved = ['systemSmall', 'systemLarge'];
          break;
        default:
          // 'none' or unknown: pick by declared height (advisory grid cells).
          resolved = def.height >= 3
              ? ['systemLarge']
              : (def.width >= 3 ? ['systemMedium'] : ['systemSmall']);
      }
    }

    // Validate and partition into system vs accessory families.
    final systemSel = <String>[];
    final accessorySel = <String>[];
    for (final f in resolved) {
      if (_systemFamilies.contains(f)) {
        systemSel.add(f);
      } else if (_accessoryFamilies.contains(f)) {
        accessorySel.add(f);
      } else {
        final valid = [..._systemFamilies, ..._accessoryFamilies].join(', ');
        throw StateError('Unknown ios.family "$f" for widget "${def.name}". '
            'Valid families: $valid.');
      }
    }

    final systemList = systemSel.map((f) => '.$f').join(', ');
    if (accessorySel.isEmpty) {
      // No accessory families, so no availability gate — but still fenced:
      // watchOS has no system families at all, and a bare literal here is what
      // broke a watch target even though the widget was never meant for one.
      // An empty list is the honest answer: the widget offers nothing there.
      return '''#if os(watchOS)
        return []
        #else
        return [$systemList]
        #endif''';
    }

    final accessoryList = accessorySel.map((f) => '.$f').join(', ');
    // Accessory families are lock-screen/watch surfaces; the enum cases do not
    // exist on macOS at all, so this is a compile fence rather than a runtime
    // availability check.
    // watchOS has no system families at all — a complication is only ever an
    // accessory — so the system list is fenced out rather than gated.
    // Accessory families exist on iOS 16+ and watchOS 9+, which is why that
    // block covers both.
    return '''var f: [WidgetFamily] = []
        #if !os(watchOS)
        f.append(contentsOf: [$systemList])
        #endif
        #if os(iOS) || os(watchOS)
        if #available(iOS 16.0, watchOS 9.0, *) {
            f.append(contentsOf: [$accessoryList])
        }
        #endif
        return f''';
  }

  /// Turns a canonical color wire map into a Swift `Color` expression.
  ///
  /// Wire shapes (see project spec):
  ///  - static/adaptive: `{hex, dark, opacity}` (dark may be null)
  ///  - bind:            `{bind, opacity}` (no hex key)
  ///
  /// Detection: a non-null `bind` ⇒ runtime resolve from [bindSource];
  /// otherwise use hex (+ dark when non-null ⇒ adaptive `Color(light:dark:)`).
}
