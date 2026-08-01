// Live Activities and Dynamic Island presentations (iOS 16.1+).
part of '../ios.dart';

extension IosLiveActivityEmitters on IosGenerator {
  Future<void> generateLiveActivities(String projectRoot) async {
    if (liveActivities.isEmpty) return;

    final iosDir = Directory(p.join(projectRoot, 'ios', 'HomeWidgetExtension'));
    if (!iosDir.existsSync()) iosDir.createSync(recursive: true);

    // Shared attributes — emitted exactly once for all activities.
    final attrsContent = '''$kGeneratedSentinel
import ActivityKit

@available(iOS 16.1, *)
struct MosaicActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable { var data: [String: String] }
  var activityType: String
}
''';
    final attrsFile =
        File(p.join(iosDir.path, 'MosaicActivityAttributes.swift'));
    await attrsFile.writeAsString(attrsContent);

    for (final la in liveActivities) {
      final name = la['name'] as String;
      final file = File(p.join(iosDir.path, '${name}LiveActivity.swift'));
      await file.writeAsString(_generateLiveActivity(la));
    }

    // Lifecycle controller the host app's AppDelegate routes channel methods
    // to. Emitted once for the whole bundle.
    final controllerContent = _generateActivityController();
    final controllerFile =
        File(p.join(iosDir.path, 'MosaicActivityController.swift'));
    await controllerFile.writeAsString(controllerContent);

    // The host app's AppDelegate references MosaicActivityController and
    // MosaicActivityAttributes. These live in the extension folder which
    // Xcode auto-syncs only to the extension target
    // (PBXFileSystemSynchronizedRootGroup). Copy them into ios/Runner/ so the
    // Runner target can compile them too.
    final runnerDir = Directory(p.join(projectRoot, 'ios', 'Runner'));
    if (runnerDir.existsSync()) {
      await File(p.join(runnerDir.path, 'MosaicActivityAttributes.swift'))
          .writeAsString(attrsContent);
      await File(p.join(runnerDir.path, 'MosaicActivityController.swift'))
          .writeAsString(controllerContent);
    }
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
  ///  - Push updates: `request(..., pushType: .token)` and the
  ///    `activity.pushTokenUpdates` async sequence are iOS 16.1+. The token is
  ///    observed in a detached Task for the activity's lifetime (it can rotate)
  ///    and forwarded via the `onPushToken` hook the AppDelegate wires to the
  ///    channel. The APNs server that pushes updates/ends is the app's concern.
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
@MainActor
enum MosaicActivityController {
    /// Set by the host AppDelegate to forward per-activity APNs push tokens to
    /// Flutter over the `mosaic_bridge` channel (method `liveActivityPushToken`,
    /// arguments `{id, token}`). The token is delivered as a lowercase hex
    /// string. Left nil when push updates are not wired up.
    ///
    /// `nonisolated(unsafe)`: assigned once by the host AppDelegate during
    /// startup and only read afterwards, so no synchronization is required.
    /// Swift 6 language mode rejects a plain mutable static without this.
    nonisolated(unsafe) static var onPushToken: ((String, String) -> Void)?

    /// Requests a new Live Activity and returns its id (nil on failure).
    ///
    /// On iOS 16.2+ uses the non-deprecated
    /// `request(attributes:content:pushType:)` overload with an
    /// `ActivityContent(state:staleDate:)`. On iOS 16.1 it falls back to the
    /// deprecated-in-16.2 `request(attributes:contentState:pushType:)` overload,
    /// isolated in `legacyStart` so the deprecation warning is confined to the
    /// explicitly version-gated legacy path.
    ///
    /// When [push] is true the activity is requested with `pushType: .token`,
    /// and a detached Task observes `activity.pushTokenUpdates` — each emitted
    /// `Data` is hex-encoded and forwarded via [onPushToken] so the host app
    /// can register it with its server for APNs-driven updates. ActivityKit may
    /// rotate the token, so the stream is observed for the activity's lifetime.
    static func start(type: String, data: [String: String], push: Bool = false) -> String? {
        let attributes = MosaicActivityAttributes(activityType: type)
        let state = MosaicActivityAttributes.ContentState(data: data)
        do {
            let activity: Activity<MosaicActivityAttributes>
            if #available(iOS 16.2, *) {
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: push ? .token : nil
                )
            } else {
                activity = try legacyStart(
                    attributes: attributes, state: state, push: push)
            }
            if push {
                let id = activity.id
                // Inherits this type's @MainActor isolation on purpose: a
                // detached task would have to send the non-Sendable Activity
                // across isolation domains, which Swift 6 rejects.
                Task {
                    for await tokenData in activity.pushTokenUpdates {
                        let token = tokenData.map { String(format: "%02x", \$0) }.joined()
                        MosaicActivityController.onPushToken?(id, token)
                    }
                }
            }
            return activity.id
        } catch {
            NSLog("MosaicActivityController.start failed: \\(error)")
            return nil
        }
    }

    /// Updates the activity with [id], optionally surfacing an alert.
    ///
    /// On iOS 16.2+ uses the non-deprecated
    /// `update(_:alertConfiguration:)` overload taking an `ActivityContent`.
    /// On iOS 16.1 it delegates to `legacyUpdate`, isolating the deprecated
    /// `update(using:alertConfiguration:)` overload behind the version gate.
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
            if #available(iOS 16.2, *) {
                await activity.update(
                    ActivityContent(state: state, staleDate: nil),
                    alertConfiguration: alert)
            } else {
                await legacyUpdate(activity, state: state, alert: alert)
            }
        }
    }

    /// Ends the activity with [id]. [policy] maps to a dismissal policy
    /// ("immediate" → .immediate, anything else → .default).
    ///
    /// On iOS 16.2+ uses the non-deprecated `end(_:dismissalPolicy:)` overload
    /// taking an `ActivityContent`. On iOS 16.1 it delegates to `legacyEnd`,
    /// isolating the deprecated `end(using:dismissalPolicy:)` overload behind
    /// the version gate.
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
            if #available(iOS 16.2, *) {
                let content = finalState.map {
                    ActivityContent(state: \$0, staleDate: nil)
                }
                await activity.end(content, dismissalPolicy: dismissal)
            } else {
                await legacyEnd(
                    activity, state: finalState, dismissal: dismissal)
            }
        }
    }

    // MARK: - iOS 16.1 legacy fallbacks
    //
    // These wrap the overloads that are deprecated as of iOS 16.2. They are the
    // ONLY place the deprecated symbols appear and are reachable solely through
    // the `else` of an `#available(iOS 16.2, *)` check, so on iOS 16.2+ devices
    // (every shipping device) they are never executed. Any deprecation warning
    // from the SDK is therefore confined to this clearly-marked legacy path.

    @available(iOS 16.1, *)
    @available(*, deprecated, message: "iOS 16.1 fallback; unused on 16.2+")
    private static func legacyStart(
        attributes: MosaicActivityAttributes,
        state: MosaicActivityAttributes.ContentState,
        push: Bool
    ) throws -> Activity<MosaicActivityAttributes> {
        return try Activity.request(
            attributes: attributes,
            contentState: state,
            pushType: push ? .token : nil
        )
    }

    @available(iOS 16.1, *)
    @available(*, deprecated, message: "iOS 16.1 fallback; unused on 16.2+")
    private static func legacyUpdate(
        _ activity: Activity<MosaicActivityAttributes>,
        state: MosaicActivityAttributes.ContentState,
        alert: AlertConfiguration?
    ) async {
        await activity.update(using: state, alertConfiguration: alert)
    }

    @available(iOS 16.1, *)
    @available(*, deprecated, message: "iOS 16.1 fallback; unused on 16.2+")
    private static func legacyEnd(
        _ activity: Activity<MosaicActivityAttributes>,
        state: MosaicActivityAttributes.ContentState?,
        dismissal: ActivityUIDismissalPolicy
    ) async {
        await activity.end(using: state, dismissalPolicy: dismissal)
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
    // `supplementalActivityFamilies` is iOS 18+, while Live Activities start at
    // 16.1. Opting in raises this activity's floor rather than the project's:
    // the bundle gates it at 18 and it is simply absent below that.
    final watch = liveActivityWantsWatch(name);
    final minVersion = watch ? '18.0' : '16.1';
    final supplemental =
        watch ? '\n    .supplementalActivityFamilies([.small, .medium])' : '';
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

@available(iOS $minVersion, *)
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
    }$supplemental
  }
}
''';
  }

  /// Whether the activity named [name] opted into Apple Watch / CarPlay
  /// presentation in `mosaic.yaml`.
  bool liveActivityWantsWatch(String name) {
    for (final la in config.liveActivities) {
      if (la.name == name) return la.watch;
    }
    return false;
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
}
