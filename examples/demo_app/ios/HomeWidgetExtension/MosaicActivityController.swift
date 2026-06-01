// MOSAIC-GENERATED — do not edit
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
