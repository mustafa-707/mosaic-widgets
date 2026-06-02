// MOSAIC-GENERATED — do not edit
import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct TorchControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "group.com.example.demo_app.widgets.Torch",
            provider: TorchValueProvider()
        ) { value in
            ControlWidgetToggle(
                "Flashlight",
                isOn: value,
                action: TorchSetValueIntent()
            ) { isOn in
                Label("Flashlight", systemImage: "flashlight.on.fill")
            }
        }
        .displayName("Flashlight")
    }
}

/// Supplies the current toggle state by reading the App Group bool at the
/// control's `valueKey`. `ControlValueProvider` is iOS 18.0+.
@available(iOS 18.0, *)
struct TorchValueProvider: ControlValueProvider {
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool {
        UserDefaults(suiteName: kMosaicAppGroup)?.bool(forKey: "torch_on") ?? false
    }
}
