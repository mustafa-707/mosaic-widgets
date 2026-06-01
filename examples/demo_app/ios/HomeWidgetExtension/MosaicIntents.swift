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
