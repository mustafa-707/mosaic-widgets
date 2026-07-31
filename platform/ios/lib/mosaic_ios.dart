// iOS (WidgetKit) generator for Mosaic.
//
// Split across parts to keep each file navigable:
//   src/ios_support.dart  — sentinels, escaping, and the handler interface
//   src/ios_handlers.dart — one IosNodeHandler per DSL node type, plus the
//                           image-modifier helpers they share
//
// Parts share one library, so private members remain visible across all three.
library;

import 'dart:io';
import 'dart:math' as math;
import 'package:mosaic_core/mosaic_core.dart';
import 'package:path/path.dart' as p;

part 'src/ios_support.dart';
part 'src/ios_handlers.dart';
part 'src/ios_widgets.dart';
part 'src/ios_emitters.dart';
part 'src/ios_controls.dart';
part 'src/ios_live_activities.dart';
part 'src/ios_widget_views.dart';

class IosGenerator {
  final MosaicConfig config;
  final List<IRDefinition> definitions;

  /// Live activity IR collected by the widget runner. Plumbed through for a
  /// later wave; the iOS generator does not emit anything from it yet.
  final List<Map<String, dynamic>> liveActivities;

  /// Control IR collected by the widget runner. Plumbed through for a
  /// later wave; the iOS generator does not emit anything from it yet.
  final List<Map<String, dynamic>> controls;

  final Map<String, IosNodeHandler> _handlers = {};

  /// The Swift expression that `HWBind` keys are resolved against. Defaults to
  /// the timeline entry's data dictionary. While rendering an `HWListView`
  /// item template this is temporarily swapped to the per-element `item`
  /// dictionary so binds resolve against the current element instead of the
  /// global store.
  String bindSource = 'entry.data';

  /// Set while emitting a widget's ROOT node so the outermost container expands
  /// to fill the tile. Consumed by the first container that sees it, so nested
  /// containers keep hugging their content.
  bool fillRoot = false;

  /// Emits a widget's root node such that it fills the whole tile.
  ///
  /// A container applies its background BEFORE any outer `.frame`, so without
  /// this the background hugged the content and the system's default widget
  /// background showed through as a light gutter around it.
  String renderRoot(IRNode root) {
    if (root.type == 'HWContainer') {
      fillRoot = true;
      final swift = nodeToSwiftUI(root);
      fillRoot = false;
      return swift;
    }
    return '${nodeToSwiftUI(root)}\n            '
        '.frame(maxWidth: .infinity, maxHeight: .infinity)';
  }

  IosGenerator({
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
    _register(CenterHandler());
    _register(AlignHandler());
    _register(SizedBoxHandler());
    _register(FlexibleHandler());
    _register(SparklineHandler());
    _register(BarChartHandler());
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
    await generateControls(projectRoot);
    await generateHostPlugin(projectRoot);
    await _generateLocalizations(projectRoot);
    await registerUrlScheme(projectRoot);
  }

  /// Registers `deep_link_scheme` in the host app's `Info.plist`.
  ///
  /// A widget's `Link`/`widgetURL` on a custom scheme opens nothing unless the
  /// app declares that scheme under `CFBundleURLTypes`. Mosaic already injects
  /// the equivalent Android intent-filter, so doing it here too keeps a deep
  /// link from being silently dead on one platform only.
  ///
  /// The entry is tagged so re-running after a scheme change replaces it rather
  /// than leaving the old scheme registered. Any hand-written `CFBundleURLTypes`
  /// is left untouched.
  Future<void> registerUrlScheme(String projectRoot) async {
    final plist = File(p.join(projectRoot, 'ios', 'Runner', 'Info.plist'));
    if (!plist.existsSync()) return;

    final scheme = config.app.deepLinkScheme;
    var content = await plist.readAsString();

    content = stripGeneratedUrlTypes(content);

    // A hand-written registration wins: the developer may have extra keys
    // (roles, icon files) that we must not clobber.
    if (content.contains('CFBundleURLTypes')) {
      await plist.writeAsString(content);
      return;
    }

    final closing = content.lastIndexOf('</dict>');
    if (closing < 0) return;

    final entry = urlTypesEntry(scheme, config.app.bundleId);
    content = content.replaceRange(closing, closing, entry);
    await plist.writeAsString(content);
  }

  /// The `CFBundleURLTypes` block for [scheme], fenced by begin/end markers.
  ///
  /// The fence is what makes removal safe: the block nests an `<array>` inside
  /// an `<array>`, so matching up to the first `</array>` would strip only the
  /// inner one and leave the outer tag orphaned — silently corrupting the plist
  /// a little more on every build.
  static String urlTypesEntry(String scheme, String bundleId) => '''	<!-- $plistUrlTypesMarker -->
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string>${xmlEscapeIos(bundleId)}</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>${xmlEscapeIos(scheme)}</string>
			</array>
		</dict>
	</array>
	<!-- $plistUrlTypesEndMarker -->
''';

  /// Removes a previously generated `CFBundleURLTypes` block, fence included.
  static String stripGeneratedUrlTypes(String plist) => plist.replaceAll(
        RegExp(
          '[ \t]*<!--\\s*$plistUrlTypesMarker\\s*-->'
          '.*?'
          '<!--\\s*$plistUrlTypesEndMarker\\s*-->\\n?',
          dotAll: true,
        ),
        '',
      );

  /// Writes one `<locale>.lproj/Localizable.strings` per locale declared under
  /// `strings:`.
  ///
  /// The widget extension carries its own bundle, so these must live beside the
  /// generated Swift — the app's localizations are not visible to it.
  Future<void> _generateLocalizations(String projectRoot) async {
    if (config.strings.isEmpty) return;
    final iosDir = Directory(p.join(projectRoot, 'ios', 'HomeWidgetExtension'));
    if (!iosDir.existsSync()) return;

    for (final entry in config.strings.entries) {
      final dir = Directory(p.join(iosDir.path, '${entry.key}.lproj'));
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final body = (entry.value.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
          .map((s) =>
              '"${swiftEscape(s.key)}" = "${swiftEscape(s.value)}";')
          .join('\n');

      await File(p.join(dir.path, 'Localizable.strings')).writeAsString(
        '// MOSAIC-GENERATED — do not edit\n$body\n',
      );
    }
  }

  /// Emits `ios/Runner/MosaicPlugin.swift` — the host-app side of the bridge.
  ///
  /// This is everything an integrator used to hand-copy into `AppDelegate`:
  /// the `mosaic_bridge` method channel, the App Group writes, widget reloads,
  /// the Live Activity lifecycle, deep-link forwarding, and draining the
  /// pending callback the widget extension leaves behind. Registering it is one
  /// line, so there is no boilerplate left to copy incorrectly.
  ///
  /// The Live Activity branches are emitted only when the project declares live
  /// activities, because `MosaicActivityController` is generated only then —
  /// keeping the file compilable either way.
  Future<void> generateHostPlugin(String projectRoot) async {
    final runnerDir = Directory(p.join(projectRoot, 'ios', 'Runner'));
    if (!runnerDir.existsSync()) return;

    final hasActivities = liveActivities.isNotEmpty;

    // Battery has to be read in the *app*, not the widget extension.
    // `isBatteryMonitoringEnabled` is a no-op in an extension, so
    // `UIDevice.current.batteryLevel` there returns -1 on a real device just as
    // it does in the simulator — which is why the metric never appeared. The
    // app can enable monitoring, so it publishes the value into the App Group
    // and the widget reads it like any other stored key.
    final metrics = <MosaicDeviceMetric>{};
    for (final def in definitions) {
      metrics.addAll(deviceMetricsIn(def.root.toJson()));
      final compact = def.compactRoot;
      if (compact != null) metrics.addAll(deviceMetricsIn(compact.toJson()));
    }
    final needsBattery = metrics.contains(MosaicDeviceMetric.batteryLevel) ||
        metrics.contains(MosaicDeviceMetric.batteryCharging);

    final batteryWiring = needsBattery
        ? '''
        // Publish battery from the app process and keep it current: the widget
        // extension cannot enable monitoring, so this is the only place the
        // value can come from.
        instance.startBatteryPublishing()
'''
        : '';

    final batteryMembers = needsBattery
        ? '''
    /// Enables battery monitoring and mirrors it into the App Group.
    ///
    /// Runs in the app because an extension cannot turn monitoring on. The
    /// first read right after enabling is often still -1 — the value is
    /// populated asynchronously — so this also observes the change
    /// notifications rather than sampling once and giving up.
    private func startBatteryPublishing() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        publishBattery()
        for name in [UIDevice.batteryLevelDidChangeNotification,
                     UIDevice.batteryStateDidChangeNotification] {
            NotificationCenter.default.addObserver(
                self, selector: #selector(batteryChanged),
                name: name, object: nil)
        }
        // Re-read when the app comes forward; the level moves while it is away.
        NotificationCenter.default.addObserver(
            self, selector: #selector(batteryChanged),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func batteryChanged() { publishBattery() }

    private func publishBattery() {
        guard let defaults = UserDefaults(suiteName: MosaicPlugin.appGroup) else { return }
        let level = UIDevice.current.batteryLevel
        // A negative level means "not known yet". Writing it would replace a
        // good value with a placeholder every time monitoring is restarted.
        guard level >= 0 else { return }
        defaults.set(String(Int((level * 100).rounded())),
                     forKey: "${MosaicDeviceMetric.batteryLevel.key}")
        let state = UIDevice.current.batteryState
        defaults.set(state == .charging || state == .full,
                     forKey: "${MosaicDeviceMetric.batteryCharging.key}")
        // Matches the rest of the plugin: WidgetCenter is iOS 14+, and the
        // Runner's deployment target can be lower.
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
'''
        : '';

    final pushTokenWiring = hasActivities
        ? '''
        // Forward per-activity APNs push tokens (Live Activities started with
        // push: true) to Dart, where they surface on
        // MosaicLiveActivities.onPushToken.
        if #available(iOS 16.1, *) {
            MosaicActivityController.onPushToken = { [weak channel] id, token in
                channel?.invokeMethod(
                    "liveActivityPushToken", arguments: ["id": id, "token": token])
            }
        }
'''
        : '';

    final activityCases = hasActivities
        ? '''
        // MosaicActivityController is @MainActor (ActivityKit's Activity type is
        // not Sendable), so these hop to the main actor and answer from there.
        case "startActivity":
            if #available(iOS 16.1, *) {
                guard let args = call.arguments as? [String: Any],
                      let type = args["activityType"] as? String else {
                    result(Self.badArguments("activityType is required"))
                    return
                }
                Task { @MainActor in
                    result(MosaicActivityController.start(
                        type: type,
                        data: (args["state"] as? [String: String]) ?? [:],
                        push: (args["push"] as? Bool) ?? false))
                }
            } else {
                result(Self.unavailable())
            }

        case "updateActivity":
            if #available(iOS 16.1, *) {
                guard let args = call.arguments as? [String: Any],
                      let id = args["id"] as? String else {
                    result(Self.badArguments("id is required"))
                    return
                }
                let alert = args["alert"] as? [String: Any]
                Task { @MainActor in
                    MosaicActivityController.update(
                        id: id,
                        data: (args["state"] as? [String: String]) ?? [:],
                        alertTitle: alert?["title"] as? String,
                        alertBody: alert?["body"] as? String)
                    result(nil)
                }
            } else {
                result(Self.unavailable())
            }

        case "endActivity":
            if #available(iOS 16.1, *) {
                guard let args = call.arguments as? [String: Any],
                      let id = args["id"] as? String else {
                    result(Self.badArguments("id is required"))
                    return
                }
                Task { @MainActor in
                    MosaicActivityController.end(
                        id: id,
                        data: args["state"] as? [String: String],
                        policy: (args["policy"] as? String) ?? "afterDefault")
                    result(nil)
                }
            } else {
                result(Self.unavailable())
            }

        case "activitiesEnabled":
            if #available(iOS 16.1, *) {
                Task { @MainActor in result(MosaicActivityController.enabled()) }
            } else {
                result(false)
            }

        case "activeActivities":
            if #available(iOS 16.1, *) {
                Task { @MainActor in result(MosaicActivityController.active()) }
            } else {
                result([String]())
            }
'''
        : '''
        // This project declares no live_activities, so MosaicActivityController
        // is not generated and these calls cannot be served.
        case "startActivity", "updateActivity", "endActivity":
            result(Self.unavailable())

        case "activitiesEnabled":
            result(false)

        case "activeActivities":
            result([String]())
''';

    final file = File(p.join(runnerDir.path, 'MosaicPlugin.swift'));
    await file.writeAsString('''$kGeneratedSentinel
import Flutter
import UIKit
import WidgetKit

/// Host-app side of the Mosaic bridge.
///
/// Register it once from your AppDelegate:
///
///     MosaicPlugin.register(with: self)
///
/// That is the whole integration — the channel, App Group writes, widget
/// reloads, Live Activity lifecycle, deep links and pending-callback draining
/// are all handled here.
public class MosaicPlugin: NSObject, FlutterPlugin {
    /// The App Group from mosaic.yaml. Used when Dart has not called
    /// `MosaicBridge.setAppGroupId(...)`, so that call is optional.
    public static let appGroup = "${config.app.iosAppGroup}"

    private static let pendingCallbackKey = "mosaic_pending_callback"

    private var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "mosaic_bridge", binaryMessenger: registrar.messenger())
        let instance = MosaicPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
$batteryWiring$pushTokenWiring    }
$batteryMembers

    /// Convenience for `FlutterAppDelegate`, which is a `FlutterPluginRegistry`.
    public static func register(with registry: FlutterPluginRegistry) {
        guard let registrar = registry.registrar(forPlugin: "MosaicPlugin") else {
            NSLog("[Mosaic] could not obtain a plugin registrar; bridge inactive")
            return
        }
        register(with: registrar)
    }

    // MARK: - Method channel

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "saveString", "saveBool":
            guard let args = call.arguments as? [String: Any],
                  let key = args["key"] as? String,
                  let value = args["value"] else {
                result(Self.badArguments("key and value are required"))
                return
            }
            save(key: key, value: value, groupId: args["appGroupId"] as? String,
                 result: result)

        case "refresh":
            guard let args = call.arguments as? [String: Any],
                  let widgetName = args["widgetName"] as? String else {
                result(Self.badArguments("widgetName is required"))
                return
            }
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadTimelines(ofKind: widgetName)
            }
            result(nil)

        case "refreshAll":
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
            result(nil)

        case "widgetPushTokens":
            // WidgetKit hands each widget kind its own APNs token, and only the
            // extension sees it. It stores them in the App Group; this is how
            // the app collects them to register with a server.
            guard let defaults = UserDefaults(suiteName: Self.appGroup) else {
                result([String: String]())
                return
            }
            let prefix = "mosaic_widget_push_token_"
            var tokens: [String: String] = [:]
            for (key, value) in defaults.dictionaryRepresentation()
            where key.hasPrefix(prefix) {
                if let token = value as? String, !token.isEmpty {
                    tokens[String(key.dropFirst(prefix.count))] = token
                }
            }
            result(tokens)

        // iOS has no API to place a widget for the user — Apple routes that
        // through the widget gallery only. Answering false rather than
        // notImplemented lets Dart branch to manual instructions.
        case "canRequestPinWidget", "requestPinWidget":
            result(false)

$activityCases
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func save(
        key: String, value: Any, groupId: String?, result: FlutterResult
    ) {
        let suiteName = groupId ?? Self.appGroup
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            result(FlutterError(
                code: "APP_GROUP_ERROR",
                message: "Could not access App Group \\(suiteName). "
                    + "Check the App Groups capability on the Runner target.",
                details: nil))
            return
        }
        defaults.set(value, forKey: key)
        result(nil)
    }

    private static func badArguments(_ message: String) -> FlutterError {
        FlutterError(code: "INVALID_ARGUMENTS", message: message, details: nil)
    }

    private static func unavailable() -> FlutterError {
        FlutterError(
            code: "UNAVAILABLE",
            message: "Live Activities require iOS 16.1+ and a live_activities "
                + "entry in mosaic.yaml.",
            details: nil)
    }

    // MARK: - Pending callbacks

    /// Drains the callback the widget extension recorded when its AppIntent
    /// could not do the work itself, and dispatches it to Dart.
    private func drainPendingCallback() {
        guard let defaults = UserDefaults(suiteName: Self.appGroup) else { return }
        guard let payload = defaults.dictionary(forKey: Self.pendingCallbackKey),
              let callback = payload["callback"] as? String else { return }
        defaults.removeObject(forKey: Self.pendingCallbackKey)
        channel?.invokeMethod("backgroundCallback",
                              arguments: ["callbackName": callback])
    }

    // MARK: - UIApplicationDelegate

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any] = [:]
    ) -> Bool {
        drainPendingCallback()
        return true
    }

    public func applicationWillEnterForeground(_ application: UIApplication) {
        drainPendingCallback()
    }

    public func applicationDidBecomeActive(_ application: UIApplication) {
        drainPendingCallback()
    }

    public func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        channel?.invokeMethod("onDeepLink", arguments: ["url": url.absoluteString])
        return false
    }
}
''');
  }

  /// Emits iOS 18 Control Widget sources (Control Center / Lock Screen / Action
  /// Button) for every entry in [controls]. Produces, all gated
  /// `@available(iOS 18.0, *)` because `ControlWidget`,
  /// `StaticControlConfiguration`, `ControlWidgetToggle`,
  /// `ControlWidgetButton`, `ControlValueProvider`, `SetValueIntent` and
  /// `ControlCenter.shared.reloadControls(ofKind:)` are iOS 18.0+:
  ///  - one `<Name>Control.swift` per control (a `ControlWidget`), and
  ///  - a single shared `MosaicControlIntents.swift` carrying one
  ///    `SetValueIntent`-conforming intent per toggle control (its `perform()`
  ///    writes the new bool into the App Group under `valueKey`, records the
  ///    callback like the existing callback path, then reloads the control).
  ///
  /// Buttons reuse the existing iOS-17 `MosaicCallbackIntent` (an `AppIntent`),
  /// so no extra intent type is generated for them. Nothing is written when
  /// there are no controls.
  String _colorToSwift(Map<String, dynamic>? data) {
    if (data == null) return 'Color.clear';
    final opacity = (data['opacity'] ?? 1.0).toDouble();

    // Bind form: resolve a hex string from entry/item data at render time.
    final bindKey = data['bind'];
    if (bindKey is String) {
      final src = bindSource;
      final base =
          'Color(hex: mosaicStr($src["${swiftEscape(bindKey)}"]) ?? "#00000000")';
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

  /// Maps a gradient angle in degrees to SwiftUI start/end `UnitPoint`s.
  ///
  /// Convention (matches the DSL): 0° = left→right, 90° = top→bottom. The unit
  /// square has y growing downward, so the direction vector is
  /// `(cos θ, sin θ)`. The line passes through the center (0.5, 0.5); the start
  /// is half a unit back along the direction and the end half a unit forward.
  /// Returns `[startExpr, endExpr]` as Swift `UnitPoint(x:y:)` literals.
  List<String> _gradientPoints(double degrees) {
    final rad = degrees * math.pi / 180.0;
    final dx = math.cos(rad);
    final dy = math.sin(rad);
    final sx = _round(0.5 - dx / 2);
    final sy = _round(0.5 - dy / 2);
    final ex = _round(0.5 + dx / 2);
    final ey = _round(0.5 + dy / 2);
    return [
      'UnitPoint(x: $sx, y: $sy)',
      'UnitPoint(x: $ex, y: $ey)',
    ];
  }

  /// Rounds a unit-point coordinate to avoid float noise (e.g. cos(90°) → 0).
  String _round(double v) {
    final r = (v * 1e6).roundToDouble() / 1e6;
    // Normalize -0.0 to 0.0 for stable output.
    final n = r == 0 ? 0.0 : r;
    return n.toString();
  }

  String nodeToSwiftUI(
    IRNode node, {
    bool isInsideStack = false,
    bool isVertical = true,
  }) {
    final handler = _handlers[node.type];
    if (handler != null) {
      return _asSingleView(handler.handle(
        node,
        this,
        isInsideStack: isInsideStack,
        isVertical: isVertical,
      ));
    }
    throw UnsupportedError('No iOS handler for node type "${node.type}".');
  }

  /// Wraps [swift] in a `Group` when it is a bare control-flow statement.
  ///
  /// Several nodes emit `if #available(...) { … } else { … }` — availability
  /// gates, visibility, cached images. A parent then appends `.padding(...)` or
  /// `.frame(...)`, and applying a modifier to a *statement* is not valid Swift
  /// ("consecutive statements on a line must be separated by ';'"). Group turns
  /// the statement back into one view that accepts modifiers.
  ///
  /// Done here rather than in each handler so a new statement-emitting node
  /// cannot reintroduce the bug.
  String _asSingleView(String swift) {
    final trimmed = swift.trimLeft();
    // A leading comment is fine; only an `if` at the head is a statement.
    if (trimmed.startsWith('if ')) {
      final indented = swift
          .split('\n')
          .map((line) => line.isEmpty ? line : '    $line')
          .join('\n');
      return 'Group {\n$indented\n}';
    }
    return swift;
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
