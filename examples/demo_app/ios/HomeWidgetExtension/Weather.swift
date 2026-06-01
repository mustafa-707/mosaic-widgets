// MOSAIC-GENERATED — do not edit
import SwiftUI
import WidgetKit

struct WeatherEntry: TimelineEntry {
    let date: Date
    let data: [String: Any]
}

struct WeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: Date(), data: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> ()) {
        let entry = WeatherEntry(date: Date(), data: loadData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = WeatherEntry(date: Date(), data: loadData())
        
                let timeline = Timeline(entries: [entry], policy: .atEnd)
        
        
        completion(timeline)
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "group.com.example.demo_app.widgets"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: WeatherProvider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        for k in ["global_url", "temp"] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

struct WeatherView: View {
    var entry: WeatherEntry
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
    Text("San Francisco").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).dynamicTypeSize(.large)
Spacer()
Image(systemName: "cloud.sun.fill").font(.system(size: 32.0)).foregroundColor(Color(red: 1.0, green: 0.8431372549019608, blue: 0.0, opacity: 1.0))
Spacer()
Text("\(entry.data["temp"] as? String ?? String(describing: entry.data["temp"] ?? "--"))").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 28.0)).dynamicTypeSize(.large)
}.padding(EdgeInsets(top: 14.0, leading: 14.0, bottom: 14.0, trailing: 14.0))
    .background(Color(light: Color(hex: "#4A90D9"), dark: Color(hex: "#1C3D5A")))
    .clipShape(RoundedRectangle(cornerRadius: 20.0))
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .widgetURL(URL(string: loadGlobalUrl()))
    }

    private func loadGlobalUrl() -> String {
        return entry.data["global_url"] as? String ?? ""
    }
}

// NOTE: On iOS, widget sizing is governed by WidgetFamily / supportedFamilies,
// not by the definition's width/height. The definition's width=2,
// height=2 and previewImage are advisory on iOS and not used by
// WidgetKit, which sizes by family and renders the placeholder() view for
// previews. resizeMode=none only acts as a fallback for deriving
// supportedFamilies when mosaic.yaml lists no ios.families for this widget.
struct WeatherWidget: Widget {
    let kind: String = "Weather"

    // Built at runtime so iOS 16+ lock-screen accessory families can be added
    // under an availability check (their WidgetFamily cases are iOS 16+).
    private var families: [WidgetFamily] {
        return [.systemSmall, .systemMedium]
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherProvider()) { entry in
            WeatherView(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("Weather")
        .description("This is an auto-generated home widget.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }
}
