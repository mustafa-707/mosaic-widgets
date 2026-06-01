// MOSAIC-GENERATED — do not edit
import ActivityKit
import Foundation

// IMPORTANT: For Live Activities to start, the HOST APP's Info.plist must set:
//     <key>NSSupportsLiveActivities</key><true/>
// Without it, `ActivityAuthorizationInfo().areActivitiesEnabled` is false and
// `Activity.request(...)` throws.

@available(iOS 16.1, *)
enum MosaicActivityController {
    /// Set by the host AppDelegate to forward per-activity APNs push tokens to
    /// Flutter over the `mosaic_bridge` channel (method `liveActivityPushToken`,
    /// arguments `{id, token}`). The token is delivered as a lowercase hex
    /// string. Left nil when push updates are not wired up.
    static var onPushToken: ((String, String) -> Void)?

    /// Requests a new Live Activity and returns its id (nil on failure).
    ///
    /// Uses the iOS 16.1 `request(attributes:contentState:pushType:)` overload
    /// (the `content:`/`ActivityContent` form is 16.2+).
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
            let activity = try Activity.request(
                attributes: attributes,
                contentState: state,
                pushType: push ? .token : nil
            )
            if push {
                let id = activity.id
                Task.detached {
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
    /// Uses the iOS 16.1 `update(using:alertConfiguration:)` overload.
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
            .first(where: { $0.id == id }) else { return }
        let dismissal: ActivityUIDismissalPolicy =
            policy == "immediate" ? .immediate : .default
        let finalState = data.map {
            MosaicActivityAttributes.ContentState(data: $0)
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
        return Activity<MosaicActivityAttributes>.activities.map { $0.id }
    }
}
