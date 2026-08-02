// MOSAIC-GENERATED — do not edit
import SwiftUI
import WidgetKit
import AppIntents

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
        // Fetch, then complete. WidgetKit waits for `completion`, so the fresh
        // values render on this pass. Completing first and reloading afterwards
        // would depend on a second reload, which the system may throttle away.
        Task {
            await MosaicRefreshSources.run(keys: ["global_url", "hi_c", "hi_f", "lo_c", "lo_f", "mosaic_refreshing", "temp_c", "temp_f", "weather_unit_f"])
            // Network images: download after the refresh, so a URL that arrived
            // in this same pass is fetched immediately rather than one timeline
            // later. Cached URLs cost nothing.
            await MosaicImageCache.prefetch([])
            let entry = WeatherEntry(date: Date(), data: loadData())

                        let timeline = Timeline(entries: [entry], policy: .atEnd)
            

            completion(timeline)
        }
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "group.com.example.demo_app.widgets"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: WeatherProvider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        // Refresh native device metrics first, so bindings read current values
        // rather than whatever the app last stored.
        MosaicDevice.populate()
        // Re-read from disk: the app and the refresh code write through other
        // UserDefaults instances, and without this the widget can render a
        // snapshot taken before those writes.
        defaults.synchronize()
        for k in ["global_url", "hi_c", "hi_f", "lo_c", "lo_f", "mosaic_refreshing", "temp_c", "temp_f", "weather_unit_f"] {
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
    HStack(alignment: .center, spacing: 0) {
    Text("San Francisco").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).lineLimit(1).dynamicTypeSize(.large)
Spacer()
Image(systemName: "cloud.sun.fill").font(.system(size: 26.0)).foregroundColor(Color(red: 1.0, green: 0.8431372549019608, blue: 0.0, opacity: 1.0))
}
Spacer()
Group {
    if mosaicBool(entry.data["weather_unit_f"]) {
        HStack(alignment: .center, spacing: 0) {
    Text("\(mosaicStr(entry.data["temp_f"]) ?? "--")").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 28.0)).dynamicTypeSize(.large)
Text("°F").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).dynamicTypeSize(.large)
}
    } else {
        HStack(alignment: .center, spacing: 0) {
    Text("\(mosaicStr(entry.data["temp_c"]) ?? "--")").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 28.0)).dynamicTypeSize(.large)
Text("°C").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).dynamicTypeSize(.large)
}
    }
}
Color.clear
    .frame(height: 2.0)
Group {
    if mosaicBool(entry.data["weather_unit_f"]) {
        HStack(alignment: .center, spacing: 0) {
    Text("H:").foregroundColor(Color(red: 0.8627450980392157, green: 0.9215686274509803, blue: 0.984313725490196, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Text("\(mosaicStr(entry.data["hi_f"]) ?? "--")").foregroundColor(Color(red: 0.8627450980392157, green: 0.9215686274509803, blue: 0.984313725490196, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Text("°   L:").foregroundColor(Color(red: 0.8627450980392157, green: 0.9215686274509803, blue: 0.984313725490196, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Text("\(mosaicStr(entry.data["lo_f"]) ?? "--")").foregroundColor(Color(red: 0.8627450980392157, green: 0.9215686274509803, blue: 0.984313725490196, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Text("°").foregroundColor(Color(red: 0.8627450980392157, green: 0.9215686274509803, blue: 0.984313725490196, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
}
    } else {
        HStack(alignment: .center, spacing: 0) {
    Text("H:").foregroundColor(Color(red: 0.8627450980392157, green: 0.9215686274509803, blue: 0.984313725490196, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Text("\(mosaicStr(entry.data["hi_c"]) ?? "--")").foregroundColor(Color(red: 0.8627450980392157, green: 0.9215686274509803, blue: 0.984313725490196, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Text("°   L:").foregroundColor(Color(red: 0.8627450980392157, green: 0.9215686274509803, blue: 0.984313725490196, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Text("\(mosaicStr(entry.data["lo_c"]) ?? "--")").foregroundColor(Color(red: 0.8627450980392157, green: 0.9215686274509803, blue: 0.984313725490196, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Text("°").foregroundColor(Color(red: 0.8627450980392157, green: 0.9215686274509803, blue: 0.984313725490196, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
}
    }
}
Spacer()
HStack(alignment: .center, spacing: 0) {
    Group {
    if #available(iOS 17.0, *) {
        Button(intent: MosaicCallbackIntent(callbackName: "refresh_weather")) {
            Group {
        if mosaicBool(entry.data["mosaic_refreshing"]) {
            ProgressView().progressViewStyle(.circular).tint(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).frame(width: 14.0, height: 14.0)
        } else {
            Image(systemName: "arrow.clockwise").font(.system(size: 14.0)).foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0))
        }
    }.padding(EdgeInsets(top: 4.0, leading: 8.0, bottom: 4.0, trailing: 8.0))
        .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        }
        .buttonStyle(.plain)
    } else if let _encoded = "refresh_weather".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let _u = URL(string: "mosaic-callback://\(_encoded)") {
        Link(destination: _u) {
            Group {
        if mosaicBool(entry.data["mosaic_refreshing"]) {
            ProgressView().progressViewStyle(.circular).tint(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).frame(width: 14.0, height: 14.0)
        } else {
            Image(systemName: "arrow.clockwise").font(.system(size: 14.0)).foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0))
        }
    }.padding(EdgeInsets(top: 4.0, leading: 8.0, bottom: 4.0, trailing: 8.0))
        .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        }
    }
}
Spacer()
Group {
    if #available(iOS 17.0, *) {
        Button(intent: MosaicToggleIntent(key: "weather_unit_f")) {
            Text("°C / °F").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 4.0, leading: 8.0, bottom: 4.0, trailing: 8.0))
        .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        }
        .buttonStyle(.plain)
    } else if let _u = URL(string: "hwrefresh://") {
        Link(destination: _u) {
            Text("°C / °F").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 4.0, leading: 8.0, bottom: 4.0, trailing: 8.0))
        .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        }
    }
}
}
}
    .padding(EdgeInsets(top: 14.0, leading: 14.0, bottom: 14.0, trailing: 14.0))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        #if os(watchOS)
        return []
        #else
        return [.systemSmall, .systemMedium]
        #endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherProvider()) { entry in
            WeatherView(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("Weather")
        .description("Current conditions, switchable between °C and °F.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }
}
