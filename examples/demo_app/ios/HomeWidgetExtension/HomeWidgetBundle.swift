// MOSAIC-GENERATED — do not edit
import SwiftUI
import WidgetKit

@main
struct HomeWidgetBundle: WidgetBundle {
    var body: some Widget {
        ProfileVPWidget()
        NewsWidgetWidget()
        if #available(iOS 17.0, *) {
            CryptoWidgetWidget()
        }
        WeatherWidget()
        if #available(iOS 16.1, *) {
            OrderTrackerLiveActivity()
        }
        if #available(iOS 18.0, *) {
            TorchControl()
        }
    }
}
