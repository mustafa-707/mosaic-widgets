// MOSAIC-GENERATED — do not edit
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
                        let token = tokenData.map { String(format: "%02x", $0) }.joined()
                        MosaicActivityController.onPushToken?(id, token)
                    }
                }
            }
            return activity.id
        } catch {
            NSLog("MosaicActivityController.start failed: \(error)")
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
            .first(where: { $0.id == id }) else { return }
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
            .first(where: { $0.id == id }) else { return }
        let dismissal: ActivityUIDismissalPolicy =
            policy == "immediate" ? .immediate : .default
        let finalState = data.map {
            MosaicActivityAttributes.ContentState(data: $0)
        }
        Task {
            if #available(iOS 16.2, *) {
                let content = finalState.map {
                    ActivityContent(state: $0, staleDate: nil)
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
        return Activity<MosaicActivityAttributes>.activities.map { $0.id }
    }
}
