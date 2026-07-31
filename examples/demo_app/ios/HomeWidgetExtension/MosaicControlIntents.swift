// MOSAIC-GENERATED — do not edit
import AppIntents
import WidgetKit
import Foundation

// iOS 18 Control Widget toggles dispatch these SetValueIntents from
// ControlWidgetToggle(action:). They run inside the widget extension process
// and CANNOT call the Flutter engine, so (like MosaicCallbackIntent) they
// record the request into the App Group (`mosaic_pending_callback`); the host
// app must read & clear that key on resume to fire the Dart backgroundCallback.

@available(iOS 18.0, *)
struct TorchSetValueIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Flashlight"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Value")
    var value: Bool

    init() {}

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: kMosaicAppGroup) {
            defaults.set(value, forKey: "torch_on")
            let payload: [String: Any] = [
                "callback": "toggle_torch",
                "timestamp": Date().timeIntervalSince1970,
            ]
            defaults.set(payload, forKey: "mosaic_pending_callback")
        }
        ControlCenter.shared.reloadControls(ofKind: "group.com.example.demo_app.widgets.Torch")
        return .result()
    }
}
