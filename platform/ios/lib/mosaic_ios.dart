import 'dart:io';
import 'package:mosaic_core/mosaic_core.dart';
import 'package:path/path.dart' as p;

/// Sentinel marker that must be the FIRST line of every generated .swift file.
/// The CLI `clean` command checks the first line for this marker.
const String kGeneratedSentinel = '// MOSAIC-GENERATED — do not edit';

abstract class IosNodeHandler {
  String get type;
  String handle(IRNode node, IosGenerator context);
}

class IosGenerator {
  final MosaicConfig config;
  final List<IRDefinition> definitions;

  /// Live activity IR collected by the widget runner. Plumbed through for a
  /// later wave; the iOS generator does not emit anything from it yet.
  final List<Map<String, dynamic>> liveActivities;

  final Map<String, IosNodeHandler> _handlers = {};

  /// The Swift expression that `HWBind` keys are resolved against. Defaults to
  /// the timeline entry's data dictionary. While rendering an `HWListView`
  /// item template this is temporarily swapped to the per-element `item`
  /// dictionary so binds resolve against the current element instead of the
  /// global store.
  String bindSource = 'entry.data';

  IosGenerator({
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
    _register(CenterHandler());
    _register(PositionedHandler());
    _register(DividerHandler());
    _register(IconHandler());
    _register(GaugeHandler());
    _register(BadgeHandler());
  }

  void _register(IosNodeHandler handler) {
    _handlers[handler.type] = handler;
  }

  Future<void> generate(String projectRoot) async {
    final iosDir = Directory(p.join(projectRoot, 'ios', 'HomeWidgetExtension'));
    if (!iosDir.existsSync()) iosDir.createSync(recursive: true);

    for (final def in definitions) {
      final swiftFile = File(p.join(iosDir.path, '${def.name}.swift'));
      await swiftFile.writeAsString(_generateSwiftUiWidget(def));
    }

    final bundleFile = File(p.join(iosDir.path, 'HomeWidgetBundle.swift'));
    await bundleFile.writeAsString(_generateWidgetBundle());

    await generateCore(projectRoot);
    await generateIntents(projectRoot);
    await generateLiveActivities(projectRoot);
  }

  /// Emits the ActivityKit Live Activity sources for every entry in
  /// [liveActivities]. Produces:
  ///  - a single shared `MosaicActivityAttributes.swift` (the
  ///    [ActivityAttributes] type whose `ContentState.data` carries the bound
  ///    string values), and
  ///  - one `<Name>LiveActivity.swift` per activity wrapping an
  ///    `ActivityConfiguration` + `DynamicIsland`.
  ///
  /// Availability: every emitted type is gated on `@available(iOS 16.1, *)`
  /// because ActivityKit's `ActivityConfiguration`/`DynamicIsland`/`Widget`
  /// `body: some WidgetConfiguration` Live Activity APIs are iOS 16.1+. Nothing
  /// is written when there are no live activities.
  Future<void> generateLiveActivities(String projectRoot) async {
    if (liveActivities.isEmpty) return;

    final iosDir = Directory(p.join(projectRoot, 'ios', 'HomeWidgetExtension'));
    if (!iosDir.existsSync()) iosDir.createSync(recursive: true);

    // Shared attributes — emitted exactly once for all activities.
    final attrsFile =
        File(p.join(iosDir.path, 'MosaicActivityAttributes.swift'));
    await attrsFile.writeAsString('''$kGeneratedSentinel
import ActivityKit

@available(iOS 16.1, *)
struct MosaicActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable { var data: [String: String] }
  var activityType: String
}
''');

    for (final la in liveActivities) {
      final name = la['name'] as String;
      final file = File(p.join(iosDir.path, '${name}LiveActivity.swift'));
      await file.writeAsString(_generateLiveActivity(la));
    }

    // Lifecycle controller the host app's AppDelegate routes channel methods
    // to. Emitted once for the whole bundle.
    final controllerFile =
        File(p.join(iosDir.path, 'MosaicActivityController.swift'));
    await controllerFile.writeAsString(_generateActivityController());
  }

  /// Emits `MosaicActivityController.swift`: a static facade over the
  /// ActivityKit lifecycle the host app drives from its method-channel handler.
  ///
  /// ActivityKit constraints that shaped this code:
  ///  - `Activity.request`, `Activity.activities`, `Activity.update/end`,
  ///    `ActivityAuthorizationInfo`, and `AlertConfiguration` are iOS 16.1+, so
  ///    the whole type is `@available(iOS 16.1, *)`.
  ///  - `update`/`end` are `async`, so the channel-facing entry points wrap the
  ///    awaits in a detached `Task` and return synchronously — the channel call
  ///    is fire-and-forget from Swift's side.
  ///  - `Activity` lookups iterate `Activity<MosaicActivityAttributes>.activities`
  ///    to find the matching `id`.
  ///  - `Info.plist` must contain `NSSupportsLiveActivities = true` (see note).
  String _generateActivityController() {
    return '''$kGeneratedSentinel
import ActivityKit
import Foundation

// IMPORTANT: For Live Activities to start, the HOST APP's Info.plist must set:
//     <key>NSSupportsLiveActivities</key><true/>
// Without it, `ActivityAuthorizationInfo().areActivitiesEnabled` is false and
// `Activity.request(...)` throws.

@available(iOS 16.1, *)
enum MosaicActivityController {
    /// Requests a new Live Activity and returns its id (nil on failure).
    ///
    /// Uses the iOS 16.1 `request(attributes:contentState:)` overload (the
    /// `content:`/`ActivityContent` form is 16.2+).
    static func start(type: String, data: [String: String]) -> String? {
        let attributes = MosaicActivityAttributes(activityType: type)
        let state = MosaicActivityAttributes.ContentState(data: data)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: state
            )
            return activity.id
        } catch {
            NSLog("MosaicActivityController.start failed: \\(error)")
            return nil
        }
    }

    /// Updates the activity with [id], optionally surfacing an alert.
    ///
    /// Uses the iOS 16.1 `update(using:alertConfiguration:)` overload.
    static func update(
        id: String,
        data: [String: String],
        alertTitle: String? = nil,
        alertBody: String? = nil
    ) {
        guard let activity = Activity<MosaicActivityAttributes>.activities
            .first(where: { \$0.id == id }) else { return }
        let state = MosaicActivityAttributes.ContentState(data: data)
        var alert: AlertConfiguration? = nil
        if let title = alertTitle, let body = alertBody {
            alert = AlertConfiguration(
                title: LocalizedStringResource(stringLiteral: title),
                body: LocalizedStringResource(stringLiteral: body),
                sound: .default
            )
        }
        Task {
            await activity.update(using: state, alertConfiguration: alert)
        }
    }

    /// Ends the activity with [id]. [policy] maps to a dismissal policy
    /// ("immediate" → .immediate, anything else → .default).
    ///
    /// Uses the iOS 16.1 `end(using:dismissalPolicy:)` overload.
    static func end(
        id: String,
        data: [String: String]? = nil,
        policy: String = "default"
    ) {
        guard let activity = Activity<MosaicActivityAttributes>.activities
            .first(where: { \$0.id == id }) else { return }
        let dismissal: ActivityUIDismissalPolicy =
            policy == "immediate" ? .immediate : .default
        let finalState = data.map {
            MosaicActivityAttributes.ContentState(data: \$0)
        }
        Task {
            await activity.end(using: finalState, dismissalPolicy: dismissal)
        }
    }

    /// Whether the user has Live Activities enabled for this app.
    static func enabled() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// The ids of all currently active activities for this attributes type.
    static func active() -> [String] {
        return Activity<MosaicActivityAttributes>.activities.map { \$0.id }
    }
}
''';
  }

  /// Renders a node tree (HWText, HWContainer, …) for a Live Activity view,
  /// resolving binds against the activity's `context.state.data` instead of the
  /// timeline `entry.data`. Saves/restores [bindSource] like the ListView
  /// item-scope pattern so generation outside the activity is unaffected. When
  /// [json] is null (an absent optional region) an `EmptyView()` is emitted.
  String _renderActivityNode(Map<String, dynamic>? json) {
    if (json == null) return 'EmptyView()';
    final previous = bindSource;
    bindSource = 'context.state.data';
    try {
      return nodeToSwiftUI(IRNode.fromJson(json));
    } finally {
      bindSource = previous;
    }
  }

  /// Emits a `<Name>LiveActivity.swift` Widget wrapping an
  /// `ActivityConfiguration` (lock-screen / banner view) and a `DynamicIsland`
  /// with its four expanded regions plus compact-leading/trailing and minimal
  /// presentations. All node trees render with binds resolved against
  /// `context.state.data`.
  String _generateLiveActivity(Map<String, dynamic> la) {
    final name = la['name'] as String;
    final lockScreen =
        _renderActivityNode(la['lockScreen'] as Map<String, dynamic>?);

    final island = (la['dynamicIsland'] as Map<String, dynamic>?) ?? const {};
    final expanded = (island['expanded'] as Map<String, dynamic>?) ?? const {};

    final expLeading =
        _renderActivityNode(expanded['leading'] as Map<String, dynamic>?);
    final expTrailing =
        _renderActivityNode(expanded['trailing'] as Map<String, dynamic>?);
    final expCenter =
        _renderActivityNode(expanded['center'] as Map<String, dynamic>?);
    final expBottom =
        _renderActivityNode(expanded['bottom'] as Map<String, dynamic>?);

    final compactLeading =
        _renderActivityNode(island['compactLeading'] as Map<String, dynamic>?);
    final compactTrailing =
        _renderActivityNode(island['compactTrailing'] as Map<String, dynamic>?);
    final minimal =
        _renderActivityNode(island['minimal'] as Map<String, dynamic>?);

    return '''$kGeneratedSentinel
import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
struct ${name}LiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: MosaicActivityAttributes.self) { context in
      $lockScreen
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          $expLeading
        }
        DynamicIslandExpandedRegion(.trailing) {
          $expTrailing
        }
        DynamicIslandExpandedRegion(.center) {
          $expCenter
        }
        DynamicIslandExpandedRegion(.bottom) {
          $expBottom
        }
      } compactLeading: {
        $compactLeading
      } compactTrailing: {
        $compactTrailing
      } minimal: {
        $minimal
      }
    }
  }
}
''';
  }

  /// Generates the shared AppIntents file used by iOS 17+ interactive buttons.
  ///
  /// WidgetKit AppIntents run in the widget extension process and CANNOT invoke
  /// the Flutter engine directly. The bridge is therefore asynchronous via the
  /// App Group: a callback intent writes the pending callback name + timestamp
  /// into the shared UserDefaults under `mosaic_pending_callback`, and the host
  /// app is expected to read & clear that key when it next becomes active
  /// (e.g. in AppDelegate/SceneDelegate willEnterForeground) and then dispatch
  /// the registered Dart `backgroundCallback`.
  Future<void> generateIntents(String projectRoot) async {
    final iosDir = Directory(p.join(projectRoot, 'ios', 'HomeWidgetExtension'));
    if (!iosDir.existsSync()) iosDir.createSync(recursive: true);

    final file = File(p.join(iosDir.path, 'MosaicIntents.swift'));
    await file.writeAsString('''$kGeneratedSentinel
import AppIntents
import WidgetKit
import Foundation

// iOS 17+ interactive widgets dispatch these AppIntents from Button(intent:).
// They run inside the widget extension process — they CANNOT call the Flutter
// engine. The callback intent therefore records the request into the App Group
// (`mosaic_pending_callback`); the host app must read & clear that key on
// resume to fire the Dart backgroundCallback. See generateIntents() docs.

/// Reloads all widget timelines. Used by MRefreshAction buttons on iOS 17+.
@available(iOS 17.0, *)
struct MosaicRefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Widget"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Records a pending Mosaic callback into the App Group so the host app can
/// pick it up on next foreground, then reloads timelines. Used by
/// MActionCallback buttons on iOS 17+.
@available(iOS 17.0, *)
struct MosaicCallbackIntent: AppIntent {
    static var title: LocalizedStringResource = "Mosaic Callback"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Callback Name")
    var callbackName: String

    init() {}

    init(callbackName: String) {
        self.callbackName = callbackName
    }

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: kMosaicAppGroup) {
            let payload: [String: Any] = [
                "callback": callbackName,
                "timestamp": Date().timeIntervalSince1970,
            ]
            defaults.set(payload, forKey: "mosaic_pending_callback")
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
''');
  }

  String _generateWidgetBundle() {
    final lines = <String>[
      ...definitions.map((def) => '        ${def.name}Widget()'),
    ];

    // Live Activities are iOS 16.1+ Widgets; register each under an
    // availability gate so the bundle still builds when targeting older iOS.
    // `@WidgetBundleBuilder` supports `if #available` blocks.
    for (final la in liveActivities) {
      final name = la['name'] as String;
      lines.add('''        if #available(iOS 16.1, *) {
            ${name}LiveActivity()
        }''');
    }

    return '''$kGeneratedSentinel
import SwiftUI
import WidgetKit

@main
struct HomeWidgetBundle: WidgetBundle {
    var body: some Widget {
${lines.join('\n')}
    }
}
''';
  }

  Future<void> generateCore(String projectRoot) async {
    final iosDir = Directory(p.join(projectRoot, 'ios', 'HomeWidgetExtension'));
    if (!iosDir.existsSync()) iosDir.createSync(recursive: true);

    final coreFile = File(p.join(iosDir.path, 'HomeWidgetCore.swift'));
    await coreFile.writeAsString('''$kGeneratedSentinel
import SwiftUI
import UIKit

let kMosaicAppGroup = "${config.app.iosAppGroup}"

/// Resolves a file-image path to a UIImage. Absolute paths are loaded directly;
/// relative paths are resolved against the App Group container. Returns nil when
/// the path is nil/empty or no image could be loaded.
func resolveFileImage(_ path: String?) -> UIImage? {
    guard let path = path, !path.isEmpty else { return nil }
    if path.hasPrefix("/") {
        return UIImage(contentsOfFile: path)
    }
    if let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: kMosaicAppGroup) {
        let full = container.appendingPathComponent(path).path
        if let img = UIImage(contentsOfFile: full) { return img }
    }
    return UIImage(contentsOfFile: path)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Builds a color that resolves at render time to [light] or [dark] based on
    /// the current interface style. Used for adaptive (dark-mode) MColors.
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

extension View {
    /// iOS 16/17-compatible container background helper.
    /// On iOS 17+ uses .containerBackground(for: .widget); on iOS 16 falls back
    /// to .background(_:) so the widget extension compiles at both targets.
    @ViewBuilder func mosaicContainerBackground<S: ShapeStyle>(_ style: S) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(style, for: .widget)
        } else {
            self.background(style)
        }
    }
}
''');
  }

  String _generateSwiftUiWidget(IRDefinition def) {
    final usedKeys = collectBindKeys(def.root).toList()..sort();
    final keyList =
        usedKeys.map((k) => '"${swiftEscape(k)}"').join(', ');
    return '''$kGeneratedSentinel
import SwiftUI
import WidgetKit

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
        let entry = ${def.name}Entry(date: Date(), data: loadData())
        
        ${def.updateInterval != null ? '''
        let nextUpdate = Calendar.current.date(byAdding: .second, value: ${def.updateInterval! ~/ 1000}, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        ''' : '''
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        '''}
        
        completion(timeline)
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "${config.app.iosAppGroup}"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: ${def.name}Provider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
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
    
    var body: some View {
        GeometryReader { geometry in
            ${nodeToSwiftUI(def.root)}
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
        StaticConfiguration(kind: kind, provider: ${def.name}Provider()) { entry in
            ${def.name}View(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("${def.name}")
        .description("This is an auto-generated home widget.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }
}
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
        throw StateError(
            'Unknown ios.family "$f" for widget "${def.name}". '
            'Valid families: $valid.');
      }
    }

    final systemList = systemSel.map((f) => '.$f').join(', ');
    if (accessorySel.isEmpty) {
      // No accessory families: a plain literal, no availability gate needed.
      return 'return [$systemList]';
    }

    final accessoryList = accessorySel.map((f) => '.$f').join(', ');
    return '''var f: [WidgetFamily] = [$systemList]
        if #available(iOS 16.0, *) {
            f.append(contentsOf: [$accessoryList])
        }
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
  String _colorToSwift(Map<String, dynamic>? data) {
    if (data == null) return 'Color.clear';
    final opacity = (data['opacity'] ?? 1.0).toDouble();

    // Bind form: resolve a hex string from entry/item data at render time.
    final bindKey = data['bind'];
    if (bindKey is String) {
      final src = bindSource;
      final base =
          'Color(hex: ($src["${swiftEscape(bindKey)}"] as? String) ?? "#00000000")';
      return opacity < 1.0 ? '$base.opacity($opacity)' : base;
    }

    final hex = data['hex'] as String;
    final dark = data['dark'] as String?;

    if (dark != null) {
      // Adaptive: pick light/dark by interface style via the Color(light:dark:)
      // helper emitted in HomeWidgetCore.swift.
      final base =
          'Color(light: Color(hex: "$hex"), dark: Color(hex: "$dark"))';
      return opacity < 1.0 ? '$base.opacity($opacity)' : base;
    }

    if (hex.startsWith('#') && hex.length == 7) {
      final r = int.parse(hex.substring(1, 3), radix: 16) / 255.0;
      final g = int.parse(hex.substring(3, 5), radix: 16) / 255.0;
      final b = int.parse(hex.substring(5, 7), radix: 16) / 255.0;
      return 'Color(red: $r, green: $g, blue: $b, opacity: $opacity)';
    }
    return 'Color(hex: "$hex").opacity($opacity)';
  }

  String nodeToSwiftUI(IRNode node) {
    final handler = _handlers[node.type];
    if (handler != null) {
      return handler.handle(node, this);
    }
    throw UnsupportedError('No iOS handler for node type "${node.type}".');
  }

  /// Walks the IR tree rooted at [node] and collects every `HWBind` key that the
  /// widget actually uses. Used to populate `loadData()` with only the keys the
  /// widget reads, instead of leaking all keys via `dictionaryRepresentation()`.
  Set<String> collectBindKeys(IRNode node) {
    final keys = <String>{};
    _collectFromValue(node.toJson(), keys);
    // global_url is always read by the generated view's loadGlobalUrl().
    keys.add('global_url');
    return keys;
  }

  void _collectFromValue(Object? value, Set<String> keys) {
    if (value is Map) {
      if (value['__type'] == 'HWBind' && value['key'] is String) {
        keys.add(value['key'] as String);
      }
      for (final v in value.values) {
        _collectFromValue(v, keys);
      }
    } else if (value is List) {
      for (final v in value) {
        _collectFromValue(v, keys);
      }
    }
  }
}

class ColumnHandler extends IosNodeHandler {
  @override
  String get type => 'HWColumn';
  @override
  String handle(IRNode node, IosGenerator context) {
    var childrenNodes = ((node.data['children'] as List?) ?? const [])
        .map((e) => context.nodeToSwiftUI(IRNode.fromJson(e as Map<String, dynamic>)))
        .toList();

    final mainAxis = node.data['mainAxisAlignment'] ?? 'start';
    if (mainAxis == 'spaceBetween' && childrenNodes.length > 1) {
      final newChildren = <String>[];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        if (i < childrenNodes.length - 1) newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'spaceEvenly') {
      final newChildren = <String>['Spacer()'];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'spaceAround') {
      // Approx for spaceAround: spacer at ends, 2 spacers between?
      // Or just use spaceEvenly logic but start/end are smaller?
      // SwiftUI spacers are equal. Let's map to spaceEvenly for simplicity/robustness.
      final newChildren = <String>['Spacer()'];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'center') {
      childrenNodes.insert(0, 'Spacer()');
      childrenNodes.add('Spacer()');
    } else if (mainAxis == 'end') {
      childrenNodes.insert(0, 'Spacer()');
    }
    // start is default (no spacers needed if alignment maps to leading/top)

    final alignment = _mapAlignment(node.data['crossAxisAlignment']);
    // Force spacing 0 because we handle distribution with Spacers
    return '''
VStack(alignment: $alignment, spacing: 0) {
    ${childrenNodes.join('\n')}
}''';
  }

  String _mapAlignment(String? cross) {
    switch (cross) {
      case 'start':
        return '.leading';
      case 'end':
        return '.trailing';
      default:
        return '.center';
    }
  }
}

class RowHandler extends IosNodeHandler {
  @override
  String get type => 'HWRow';
  @override
  String handle(IRNode node, IosGenerator context) {
    var childrenNodes = ((node.data['children'] as List?) ?? const [])
        .map((e) => context.nodeToSwiftUI(IRNode.fromJson(e as Map<String, dynamic>)))
        .toList();

    final mainAxis = node.data['mainAxisAlignment'] ?? 'start';
    if (mainAxis == 'spaceBetween' && childrenNodes.length > 1) {
      final newChildren = <String>[];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        if (i < childrenNodes.length - 1) newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'spaceEvenly') {
      final newChildren = <String>['Spacer()'];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'spaceAround') {
      // spaceAround approximated as spaceEvenly: SwiftUI Spacers are equal, so
      // the half-size leading/trailing gaps of Flutter's spaceAround can't be
      // expressed exactly here. Comment kept for visibility (Column does too).
      final newChildren = <String>['Spacer() // spaceAround approximated as spaceEvenly'];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'center') {
      childrenNodes.insert(0, 'Spacer()');
      childrenNodes.add('Spacer()');
    } else if (mainAxis == 'end') {
      childrenNodes.insert(0, 'Spacer()');
    }

    final alignment = _mapAlignment(node.data['crossAxisAlignment']);
    return '''
HStack(alignment: $alignment, spacing: 0) {
    ${childrenNodes.join('\n')}
}''';
  }

  String _mapAlignment(String? cross) {
    switch (cross) {
      case 'start':
        return '.top';
      case 'end':
        return '.bottom';
      default:
        return '.center'; // vertically centered
    }
  }
}

class TextHandler extends IosNodeHandler {
  @override
  String get type => 'HWText';
  @override
  String handle(IRNode node, IosGenerator context) {
    final text = node.data['text'];
    final isBind = text is Map && text['__type'] == 'HWBind';
    final src = context.bindSource;
    final format = node.data['format'] as String?;

    // Build the `Text(...)` expression. Formatting only applies to bound text;
    // a static literal is rendered verbatim.
    final String textExpr;
    if (isBind && format != null) {
      textExpr = _formattedText(format, swiftEscape(text['key'] as String), src);
    } else {
      final textValue = isBind
          ? '"\\($src[\"${swiftEscape(text['key'] as String)}\"] as? String ?? String(describing: $src[\"${swiftEscape(text['key'] as String)}\"] ?? \"--\"))"'
          : '"${swiftEscape(text as String)}"';
      textExpr = 'Text($textValue)';
    }

    final style = node.data['style'] ?? {};
    final bold = style['bold'] == true ? '.bold()' : '';
    final color = style['color'] != null
        ? '.foregroundColor(${context._colorToSwift(style['color'])})'
        : '';
    final size = style['size'] != null
        ? '.font(.system(size: ${style['size']}))'
        : '';
    final opacity = style['opacity'] != null
        ? '.opacity(${style['opacity']})'
        : '';
    // Use dynamicTypeSize to prevent text scaling with device accessibility settings
    return '$textExpr$bold$color$size$opacity.dynamicTypeSize(.large)';
  }

  /// Emits a `Text(...)` for a bound value formatted per MFormat, localized via
  /// `Locale.current`. decimal/currency/percent parse the bound value as a
  /// Double; date/relativeTime read it as epoch milliseconds (Double) and
  /// divide by 1000.0 to obtain epoch seconds — matching Flutter's
  /// `millisecondsSinceEpoch` convention used on Android. The `.formatted`
  /// style APIs used here are iOS15+.
  String _formattedText(String format, String key, String src) {
    // Parse a Double from the bound entry value (NSNumber or String).
    final dbl =
        '(($src["$key"] as? NSNumber)?.doubleValue ?? Double("\\($src["$key"] ?? "0")") ?? 0)';
    switch (format) {
      case 'decimal':
        return 'Text($dbl.formatted(.number))';
      case 'currency':
        return 'Text($dbl.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))';
      case 'percent':
        return 'Text($dbl.formatted(.percent))';
      case 'date':
        return 'Text((Date(timeIntervalSince1970: $dbl / 1000.0)).formatted(date: .abbreviated, time: .omitted))';
      case 'relativeTime':
        return 'Text(Date(timeIntervalSince1970: $dbl / 1000.0), style: .relative)';
      default:
        // Unknown format: fall back to the plain interpolated string.
        return 'Text("\\($src["$key"] as? String ?? String(describing: $src["$key"] ?? "--"))")';
    }
  }
}

class ContainerHandler extends IosNodeHandler {
  @override
  String get type => 'HWContainer';
  @override
  String handle(IRNode node, IosGenerator context) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final radius = node.data['radius'] ?? 0;
    // A background is present whether it carries a hex or a runtime bind key.
    final background = node.data['background'];
    final gradient = node.data['gradient'];
    final border = node.data['border'];
    final padding = node.data['padding'] ?? {};

    // Build modifiers in correct order
    List<String> modifiers = [];

    // 1. Frame (size)
    final width = node.data['width'];
    final height = node.data['height'];
    if (width != null || height != null) {
      modifiers.add(
        '.frame(${width != null ? 'width: $width' : ''}${width != null && height != null ? ', ' : ''}${height != null ? 'height: $height' : ''})',
      );
    }

    // 2. Internal padding
    if (padding.isNotEmpty) {
      modifiers.add(
        '.padding(EdgeInsets(top: ${padding['top'] ?? 0}, leading: ${padding['left'] ?? 0}, bottom: ${padding['bottom'] ?? 0}, trailing: ${padding['right'] ?? 0}))',
      );
    }

    // 3. Background
    if (gradient != null && gradient['__type'] == 'HWLinearGradient') {
      final colorMaps = (gradient['colors'] as List)
          .map((c) => (c as Map).cast<String, dynamic>())
          .toList();
      final stops = gradient['stops'] as List?;
      final String gradientExpr;
      if (stops != null && stops.length == colorMaps.length) {
        // SwiftUI supports arbitrary stops via Gradient.Stop.
        final stopExprs = <String>[];
        for (var i = 0; i < colorMaps.length; i++) {
          stopExprs.add(
              '.init(color: ${context._colorToSwift(colorMaps[i])}, location: ${stops[i]})');
        }
        gradientExpr = 'Gradient(stops: [${stopExprs.join(', ')}])';
      } else {
        final colors =
            colorMaps.map((c) => context._colorToSwift(c)).join(', ');
        gradientExpr = 'Gradient(colors: [$colors])';
      }
      modifiers.add(
        '.background(LinearGradient(gradient: $gradientExpr, startPoint: .topLeading, endPoint: .bottomTrailing))',
      );
    } else if (background != null) {
      modifiers.add(
        '.background(${context._colorToSwift(node.data['background'])})',
      );
    }

    // 4. Clip shape (corner radius) or explicit clip
    if (radius > 0) {
      modifiers.add('.clipShape(RoundedRectangle(cornerRadius: $radius))');
    } else if (width != null || height != null) {
      // Ensure content doesn't overflow if explicit size is set
      modifiers.add('.clipped()');
    }

    // 5. Border using overlay (preserves rounded corners)
    if (border != null) {
      final borderColor = (border['color'] as Map).cast<String, dynamic>();
      final lineWidth = (border['width'] ?? 1.0);
      modifiers.add(
        '.overlay(RoundedRectangle(cornerRadius: $radius).stroke(${context._colorToSwift(borderColor)}, lineWidth: $lineWidth))',
      );
    }

    // 6. Margin (external padding)
    final margin = node.data['margin'] ?? {};
    if (margin.isNotEmpty) {
      modifiers.add(
        '.padding(EdgeInsets(top: ${margin['top'] ?? 0}, leading: ${margin['left'] ?? 0}, bottom: ${margin['bottom'] ?? 0}, trailing: ${margin['right'] ?? 0}))',
      );
    }

    return '''
${context.nodeToSwiftUI(child)}
    ${modifiers.join('\n    ')}''';
  }
}

class PaddingHandler extends IosNodeHandler {
  @override
  String get type => 'HWPadding';
  @override
  String handle(IRNode node, IosGenerator context) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final insets = node.data['insets'] ?? {};
    return '${context.nodeToSwiftUI(child)}.padding(EdgeInsets(top: ${insets['top'] ?? 0}, leading: ${insets['left'] ?? 0}, bottom: ${insets['bottom'] ?? 0}, trailing: ${insets['right'] ?? 0}))';
  }
}

class StackHandler extends IosNodeHandler {
  @override
  String get type => 'HWStack';
  @override
  String handle(IRNode node, IosGenerator context) {
    final children = ((node.data['children'] as List?) ?? const [])
        .map((e) => IRNode.fromJson(e as Map<String, dynamic>))
        .toList();
    final alignment = _mapStackAlignment(node.data['alignment']);
    return '''
ZStack(alignment: $alignment) {
    ${children.map((c) => context.nodeToSwiftUI(c)).join('\n')}
}''';
  }

  String _mapStackAlignment(String? align) {
    switch (align) {
      case 'topCenter':
        return '.top';
      case 'topRight':
        return '.topTrailing';
      case 'centerLeft':
        return '.leading';
      case 'center':
        return '.center';
      case 'centerRight':
        return '.trailing';
      case 'bottomLeft':
        return '.bottomLeading';
      case 'bottomCenter':
        return '.bottom';
      case 'bottomRight':
        return '.bottomTrailing';
      case 'topLeft':
      default:
        return '.topLeading';
    }
  }
}

class SpacerHandler extends IosNodeHandler {
  @override
  String get type => 'HWSpacer';
  @override
  String handle(IRNode node, IosGenerator context) {
    return 'Spacer()';
  }
}

class ButtonHandler extends IosNodeHandler {
  @override
  String get type => 'HWButton';
  @override
  String handle(IRNode node, IosGenerator context) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final action = node.data['action'];
    final childSwift = context.nodeToSwiftUI(child);

    if (action['__type'] == 'HWLaunchUrlAction') {
      final url = swiftEscape(action['url'] as String);
      return '''
if let _u = URL(string: "$url") {
    Link(destination: _u) {
        $childSwift
    }
}''';
    } else if (action['__type'] == 'HWActionCallback') {
      final callbackName = swiftEscape(action['callbackName'] as String);
      // iOS 17+: dispatch a real AppIntent that records the pending callback in
      // the App Group (the host app fires the Dart backgroundCallback on
      // resume). Pre-iOS17: fall back to the mosaic-callback:// deep link Link,
      // which only re-opens the app. The mosaic-callback URL is built at
      // runtime via percent-encoding to stay force-unwrap-free.
      return '''
if #available(iOS 17.0, *) {
    Button(intent: MosaicCallbackIntent(callbackName: "$callbackName")) {
        $childSwift
    }
    .buttonStyle(.plain)
} else if let _encoded = "$callbackName".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
          let _u = URL(string: "mosaic-callback://\\(_encoded)") {
    Link(destination: _u) {
        $childSwift
    }
}''';
    } else {
      // hwrefresh. iOS 17+: AppIntent reloads timelines in-process. Pre-iOS17:
      // fall back to the hwrefresh:// deep link Link (static well-formed URL,
      // still no force-unwrap).
      return '''
if #available(iOS 17.0, *) {
    Button(intent: MosaicRefreshIntent()) {
        $childSwift
    }
    .buttonStyle(.plain)
} else if let _u = URL(string: "hwrefresh://") {
    Link(destination: _u) {
        $childSwift
    }
}''';
    }
  }
}

class VisibilityHandler extends IosNodeHandler {
  @override
  String get type => 'HWVisibility';
  @override
  String handle(IRNode node, IosGenerator context) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final replacement = node.data['replacement'] != null
        ? IRNode.fromJson(node.data['replacement'] as Map<String, dynamic>)
        : null;
    final bindMap = node.data['bind'] as Map<String, dynamic>?;
    if (bindMap == null) return '// missing bind';
    final key = swiftEscape(bindMap['key'] as String);
    final condition =
        '(${context.bindSource}["$key"] as? NSNumber)?.boolValue ?? false';
    return '''
if $condition {
    ${context.nodeToSwiftUI(child)}
} else {
    ${replacement != null ? context.nodeToSwiftUI(replacement) : 'EmptyView()'}
}''';
  }
}

class ImageHandler extends IosNodeHandler {
  @override
  String get type => 'HWImage';
  @override
  String handle(IRNode node, IosGenerator context) {
    final source = node.data['source'];
    final type = source['__type'];
    final fit = node.data['fit'];

    String imageCode;
    if (type == 'HWAssetImage') {
      // iOS asset catalogs reference assets by name without a file extension.
      final rawPath = source['path'] as String;
      final dot = rawPath.lastIndexOf('.');
      final slash = rawPath.lastIndexOf('/');
      final assetName =
          (dot > slash && dot != -1) ? rawPath.substring(0, dot) : rawPath;
      imageCode = 'Image("${swiftEscape(assetName)}")';
    } else if (type == 'HWFileImage') {
      final path = source['path'];
      final isBind = path is Map && path['__type'] == 'HWBind';
      final pathValue = isBind
          ? '(${context.bindSource}["${swiftEscape(path['key'] as String)}"] as? String)'
          : '"${swiftEscape(path.toString())}"';
      // Resolve the file via the shared helper (absolute paths used as-is,
      // relative paths resolved against the App Group container). Nil-safe.
      imageCode = 'Image(uiImage: resolveFileImage($pathValue) ?? UIImage())';
    } else {
      return '// Unsupported Image Source';
    }

    // Map all 7 MBoxFit values onto SwiftUI image modifiers.
    String modifiers;
    switch (fit) {
      case 'cover':
        modifiers = '.resizable().aspectRatio(contentMode: .fill)';
        break;
      case 'contain':
        modifiers = '.resizable().aspectRatio(contentMode: .fit)';
        break;
      case 'fill':
        // Stretch to fill the frame on both axes — no aspectRatio.
        modifiers = '.resizable()';
        break;
      case 'fitWidth':
        modifiers =
            '.resizable().aspectRatio(contentMode: .fit).frame(maxWidth: .infinity)';
        break;
      case 'fitHeight':
        modifiers =
            '.resizable().aspectRatio(contentMode: .fit).frame(maxHeight: .infinity)';
        break;
      case 'none':
        // Intrinsic size — do not make the image resizable.
        modifiers = '';
        break;
      case 'scaleDown':
        modifiers = '.resizable().aspectRatio(contentMode: .fit)';
        break;
      default:
        modifiers = '.resizable().aspectRatio(contentMode: .fit)';
    }

    return '$imageCode$modifiers';
  }
}

class ProgressBarHandler extends IosNodeHandler {
  @override
  String get type => 'HWProgressBar';
  @override
  String handle(IRNode node, IosGenerator context) {
    final value = node.data['value'];
    final isBind = value is Map && value['__type'] == 'HWBind';
    // For binds, resolve the value from entry data at runtime. NSNumber covers
    // Int/Double/Bool stored in UserDefaults; fall back to parsing a String.
    final src = context.bindSource;
    final valStr = isBind
        ? '(($src["${swiftEscape(value['key'] as String)}"] as? NSNumber)?.doubleValue ?? Double("\\($src["${swiftEscape(value['key'] as String)}"] ?? "0")") ?? 0)'
        : '$value';
    final max = node.data['max'] ?? 100.0;
    final color = node.data['color'];

    String tint = '';
    if (color != null) {
      tint = '.tint(${context._colorToSwift(color)})';
    }

    return 'ProgressView(value: $valStr, total: $max)$tint';
  }
}

class ListViewHandler extends IosNodeHandler {
  @override
  String get type => 'HWListView';
  @override
  String handle(IRNode node, IosGenerator context) {
    final bindMap = node.data['bind'] as Map<String, dynamic>?;
    if (bindMap == null) return '// missing bind';
    final key = swiftEscape(bindMap['key'] as String);
    final itemJson = node.data['itemTemplate'];
    if (itemJson == null) return '// missing itemTemplate';
    final itemTemplate = IRNode.fromJson(itemJson as Map<String, dynamic>);

    // Render the item template with binds resolved against the per-element
    // `item` dictionary instead of the global `entry.data`. Save and restore
    // the bind source so nested generation outside the loop is unaffected.
    final previousSource = context.bindSource;
    context.bindSource = 'item';
    final String itemSwift;
    try {
      itemSwift = context.nodeToSwiftUI(itemTemplate);
    } finally {
      context.bindSource = previousSource;
    }

    // Decode the bound JSON array from entry data and iterate. A stable id is
    // derived from the enumeration offset so SwiftUI can diff elements.
    return '''
ForEach(Array((entry.data["$key"] as? [[String: Any]] ?? []).enumerated()), id: \\.offset) { _, item in
    $itemSwift
}''';
  }
}

class TimerHandler extends IosNodeHandler {
  @override
  String get type => 'HWTimer';
  @override
  String handle(IRNode node, IosGenerator context) {
    final targetEpoch = node.data['target'];
    final isBind = targetEpoch is Map && targetEpoch['__type'] == 'HWBind';

    final String dateExpr;
    if (isBind) {
      // Read the target epoch (milliseconds) from entry data at runtime.
      final key = swiftEscape(targetEpoch['key'] as String);
      dateExpr =
          'Date(timeIntervalSince1970: ((${context.bindSource}["$key"] as? NSNumber)?.doubleValue ?? 0) / 1000.0)';
    } else {
      final DateTime target;
      if (targetEpoch is int) {
        target = DateTime.fromMillisecondsSinceEpoch(targetEpoch);
      } else {
        target = DateTime.parse(targetEpoch.toString());
      }
      final seconds = target.millisecondsSinceEpoch / 1000.0;
      dateExpr = 'Date(timeIntervalSince1970: $seconds)';
    }

    final style = node.data['style'] ?? {};
    final bold = style['bold'] == true ? '.bold()' : '';
    final color = style['color'] != null
        ? '.foregroundColor(${context._colorToSwift(style['color'])})'
        : '';
    final size = style['size'] != null
        ? '.font(.system(size: ${style['size']}))'
        : '';
    final modifiers = '$bold$color$size.monospacedDigit()';

    final countUp = node.data['countUp'] == true;
    if (countUp) {
      // Counting up: SwiftUI's relative timer Text counts down by default, so
      // we use Text(timerInterval:countsDown:) with countsDown: false to show
      // elapsed time from the target date. That initializer is iOS 16+, so we
      // gate it and fall back to the plain `.timer` style (which counts down)
      // on iOS 14/15 — the closest available behavior.
      return '''
Group {
    if #available(iOS 16.0, *) {
        Text(timerInterval: $dateExpr...Date.distantFuture, countsDown: false)
    } else {
        Text($dateExpr, style: .timer)
    }
}$modifiers''';
    }

    return 'Text($dateExpr, style: .timer)$modifiers';
  }
}

class CenterHandler extends IosNodeHandler {
  @override
  String get type => 'HWCenter';
  @override
  String handle(IRNode node, IosGenerator context) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    return '''
${context.nodeToSwiftUI(child)}
    .frame(maxWidth: .infinity, maxHeight: .infinity)''';
  }
}

class DividerHandler extends IosNodeHandler {
  @override
  String get type => 'HWDivider';
  @override
  String handle(IRNode node, IosGenerator context) {
    final thickness = node.data['thickness'] ?? 1.0;
    final indent = node.data['indent'] ?? 0;
    final colorMap = node.data['color'];
    // Default to a faint separator color when none is given.
    final fill = colorMap != null
        ? context._colorToSwift(colorMap)
        : 'Color.gray.opacity(0.3)';
    final vertical = node.data['vertical'] == true;
    if (vertical) {
      // A vertical rule: width = thickness, stretch height. Indent pads
      // top/bottom via .vertical so the rule doesn't touch the edges.
      return 'Rectangle().fill($fill).frame(width: $thickness).padding(.vertical, $indent)';
    }
    // Horizontal rule: height = thickness, indent pads the sides.
    return 'Rectangle().fill($fill).frame(height: $thickness).padding(.horizontal, $indent)';
  }
}

class IconHandler extends IosNodeHandler {
  @override
  String get type => 'HWIcon';
  @override
  String handle(IRNode node, IosGenerator context) {
    final sfSymbol = node.data['sfSymbol'] as String?;
    // SwiftUI needs a concrete SF Symbol name; when the DSL only supplied an
    // androidDrawable (sfSymbol null) fall back to a stable placeholder glyph.
    final symbol = (sfSymbol != null && sfSymbol.isNotEmpty)
        ? swiftEscape(sfSymbol)
        : 'questionmark';
    final size = node.data['size'] ?? 24.0;
    final colorMap = node.data['color'];
    final color = colorMap != null
        ? '.foregroundColor(${context._colorToSwift(colorMap)})'
        : '';
    return 'Image(systemName: "$symbol").font(.system(size: $size))$color';
  }
}

class GaugeHandler extends IosNodeHandler {
  @override
  String get type => 'HWGauge';
  @override
  String handle(IRNode node, IosGenerator context) {
    final value = node.data['value'];
    final isBind = value is Map && value['__type'] == 'HWBind';
    final src = context.bindSource;
    // Resolve the value as a Double. Binds parse NSNumber/String from the data
    // dictionary; a literal is emitted verbatim.
    final String valStr;
    if (isBind) {
      final key = swiftEscape(value['key'] as String);
      valStr =
          '(($src["$key"] as? NSNumber)?.doubleValue ?? Double("\\($src["$key"] ?? "0")") ?? 0)';
    } else {
      valStr = '$value';
    }
    final max = node.data['max'] ?? 100.0;
    final lineWidth = node.data['lineWidth'] ?? 6.0;
    final trackMap = node.data['trackColor'];
    final fillMap = node.data['fillColor'];
    final track = trackMap != null
        ? context._colorToSwift(trackMap)
        : 'Color.gray.opacity(0.3)';
    final fill = fillMap != null ? context._colorToSwift(fillMap) : 'Color.blue';
    // Trim fraction guarded against a zero max to avoid NaN.
    final fraction = 'min(max(($valStr) / ${max == 0 ? 1.0 : max}, 0), 1)';
    return '''
ZStack {
    Circle().stroke($track, lineWidth: $lineWidth)
    Circle().trim(from: 0, to: $fraction).stroke($fill, style: StrokeStyle(lineWidth: $lineWidth, lineCap: .round)).rotationEffect(.degrees(-90))
}''';
  }
}

class BadgeHandler extends IosNodeHandler {
  @override
  String get type => 'HWBadge';
  @override
  String handle(IRNode node, IosGenerator context) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final childSwift = context.nodeToSwiftUI(child);
    final count = node.data['count'];
    final isBind = count is Map && count['__type'] == 'HWBind';
    final src = context.bindSource;
    final String countExpr;
    if (isBind) {
      final key = swiftEscape(count['key'] as String);
      // Render the bound count as a string (covers Int/Double/String stored
      // in the data dictionary).
      countExpr =
          '"\\($src[\"$key\"] as? String ?? String(describing: $src[\"$key\"] ?? \"\"))"';
    } else {
      countExpr = '"${swiftEscape(count.toString())}"';
    }
    final colorMap = node.data['color'];
    final color =
        colorMap != null ? context._colorToSwift(colorMap) : 'Color.red';
    return '''
$childSwift
    .overlay(alignment: .topTrailing) {
        Text($countExpr)
            .font(.system(size: 10))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill($color))
    }''';
  }
}

class PositionedHandler extends IosNodeHandler {
  @override
  String get type => 'HWPositioned';
  @override
  String handle(IRNode node, IosGenerator context) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final top = node.data['top'];
    final left = node.data['left'];
    final right = node.data['right'];
    final bottom = node.data['bottom'];

    String alignment = '.topLeading';
    if (top != null && right != null)
      alignment = '.topTrailing';
    else if (bottom != null && left != null)
      alignment = '.bottomLeading';
    else if (bottom != null && right != null)
      alignment = '.bottomTrailing';
    else if (top != null)
      alignment = '.top';
    else if (bottom != null)
      alignment = '.bottom';
    else if (left != null)
      alignment = '.leading';
    else if (right != null)
      alignment = '.trailing';

    return '''
${context.nodeToSwiftUI(child)}
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: $alignment)''';
  }
}
