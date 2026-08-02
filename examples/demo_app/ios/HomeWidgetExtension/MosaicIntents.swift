// MOSAIC-GENERATED — do not edit
import AppIntents
import WidgetKit
import Foundation

// iOS 17+ interactive widgets dispatch these AppIntents from Button(intent:).
// They run inside the widget extension process — they CANNOT call the Flutter
// engine. The callback intent therefore records the request into the App Group
// (`mosaic_pending_callback`); the host app must read & clear that key on
// resume to fire the Dart backgroundCallback. See generateIntents() docs.

/// Reloads all widget timelines. Used by MRefreshAction buttons on iOS 17+.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MosaicRefreshIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Widget"
    static let isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        // Fetch here as well as in the timeline provider — see
        // MosaicCallbackIntent for why both paths run.
        await MosaicRefreshSources.run("refresh_all")

        if let defaults = UserDefaults(suiteName: "group.com.example.demo_app.widgets") {
            let payload: [String: Any] = [
                "callback": "refresh_all",
                "timestamp": Date().timeIntervalSince1970,
            ]
            defaults.set(payload, forKey: "mosaic_pending_callback")
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Flips a boolean in the App Group and redraws. Used by MToggleAction buttons
/// on iOS 17+. Runs entirely in the extension — no app launch, no network — so
/// in-widget state like a unit switch responds immediately.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MosaicToggleIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Value"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Key")
    var key: String

    init() {}

    init(key: String) {
        self.key = key
    }

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: kMosaicAppGroup) {
            defaults.set(!defaults.bool(forKey: key), forKey: key)
            defaults.synchronize()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Records a pending Mosaic callback into the App Group so the host app can
/// pick it up on next foreground, then reloads timelines. Used by
/// MActionCallback buttons on iOS 17+.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MosaicCallbackIntent: AppIntent {
    static let title: LocalizedStringResource = "Mosaic Callback"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Callback Name")
    var callbackName: String

    init() {}

    init(callbackName: String) {
        self.callbackName = callbackName
    }

    func perform() async throws -> some IntentResult {
        // Fetch here AND in the timeline provider, on purpose. Either path can
        // be the one that survives: an intent has a short execution window, and
        // a provider reload can be coalesced by the system. Both write the same
        // keys, so whichever lands first wins and the other is a no-op refresh.
        await MosaicRefreshSources.run(callbackName)

        // Still recorded so the host app can run any app-side work for this
        // callback next time it is foregrounded.
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
