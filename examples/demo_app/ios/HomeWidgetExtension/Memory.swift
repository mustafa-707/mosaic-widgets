// MOSAIC-GENERATED — do not edit
import SwiftUI
import WidgetKit
import AppIntents

struct MemoryEntry: TimelineEntry {
    let date: Date
    let data: [String: Any]
}

struct MemoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoryEntry {
        MemoryEntry(date: Date(), data: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoryEntry) -> ()) {
        let entry = MemoryEntry(date: Date(), data: loadData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Fetch, then complete. WidgetKit waits for `completion`, so the fresh
        // values render on this pass. Completing first and reloading afterwards
        // would depend on a second reload, which the system may throttle away.
        Task {
            await MosaicRefreshSources.run(keys: ["global_url", "mosaic_memory_free_mb", "mosaic_memory_total_mb", "mosaic_memory_used_percent", "mosaic_refreshing"])
            // Network images: download after the refresh, so a URL that arrived
            // in this same pass is fetched immediately rather than one timeline
            // later. Cached URLs cost nothing.
            await MosaicImageCache.prefetch([])
            let entry = MemoryEntry(date: Date(), data: loadData())

                        let timeline = Timeline(entries: [entry], policy: .atEnd)
            

            completion(timeline)
        }
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "group.com.example.demo_app.widgets"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: MemoryProvider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        // Refresh native device metrics first, so bindings read current values
        // rather than whatever the app last stored.
        MosaicDevice.populate()
        // Re-read from disk: the app and the refresh code write through other
        // UserDefaults instances, and without this the widget can render a
        // snapshot taken before those writes.
        defaults.synchronize()
        for k in ["global_url", "mosaic_memory_free_mb", "mosaic_memory_total_mb", "mosaic_memory_used_percent", "mosaic_refreshing"] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

struct MemoryView: View {
    var entry: MemoryEntry
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    Text("USED").bold().foregroundColor(Color(red: 0.20392156862745098, green: 0.8274509803921568, blue: 0.6, opacity: 1.0)).font(.system(size: 9.0)).dynamicTypeSize(.large)
Spacer()
Group {
    if mosaicBool(entry.data["mosaic_refreshing"]) {
        ProgressView().progressViewStyle(.circular).frame(width: 12.0, height: 12.0)
    } else {
        HStack(alignment: .center, spacing: 0) {
    Text((mosaicNum(entry.data["mosaic_memory_used_percent"]) ?? 0).formatted(.number)).bold().foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 9.0)).dynamicTypeSize(.large)
Text("%").foregroundColor(Color(red: 0.39215686274509803, green: 0.4549019607843137, blue: 0.5450980392156862, opacity: 1.0)).font(.system(size: 9.0)).dynamicTypeSize(.large)
}
    }
}
}
Color.clear
    .frame(height: 8.0)
HStack(alignment: .bottom, spacing: 0) {
    Text((mosaicNum(entry.data["mosaic_memory_free_mb"]) ?? 0).formatted(.number)).bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 30.0)).dynamicTypeSize(.large)
Text("MB free").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 11.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 0.0, leading: 3.0, bottom: 5.0, trailing: 0.0))
}.accessibilityElement(children: .ignore).accessibilityLabel(Text("Free memory"))
Color.clear
    .frame(height: 8.0)
VStack(alignment: .leading, spacing: 0) {
    ProgressView(value: (mosaicNum(entry.data["mosaic_memory_used_percent"]) ?? 0), total: 100.0).tint(Color(red: 0.20392156862745098, green: 0.8274509803921568, blue: 0.6, opacity: 1.0))
Color.clear
    .frame(height: 5.0)
HStack(alignment: .center, spacing: 0) {
    Text("in use").foregroundColor(Color(red: 0.39215686274509803, green: 0.4549019607843137, blue: 0.5450980392156862, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
Spacer()
HStack(alignment: .center, spacing: 0) {
    Text((mosaicNum(entry.data["mosaic_memory_total_mb"]) ?? 0).formatted(.number)).foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
Text(" MB total").foregroundColor(Color(red: 0.39215686274509803, green: 0.4549019607843137, blue: 0.5450980392156862, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
}
}
}.accessibilityLabel(Text("Memory in use"))
Color.clear
    .frame(height: 10.0)
Group {
    if mosaicBool(entry.data["mosaic_refreshing"]) {
        ProgressView().progressViewStyle(.circular).frame(width: 14.0, height: 14.0)
    .frame(maxWidth: .infinity, maxHeight: .infinity).padding(EdgeInsets(top: 7.0, leading: 10.0, bottom: 7.0, trailing: 10.0))
    .background(Color(red: 0.12156862745098039, green: 0.1607843137254902, blue: 0.21568627450980393, opacity: 1.0))
    .clipShape(RoundedRectangle(cornerRadius: 8.0))
    .overlay(RoundedRectangle(cornerRadius: 8.0).stroke(Color(red: 0.21568627450980393, green: 0.2549019607843137, blue: 0.3176470588235294, opacity: 1.0), lineWidth: 1.0))
    } else {
        Group {
    if #available(iOS 17.0, *) {
        Button(intent: MosaicCallbackIntent(callbackName: "clear_ram")) {
            Text("Optimize").bold().foregroundColor(Color(red: 0.023529411764705882, green: 0.1568627450980392, blue: 0.11372549019607843, opacity: 1.0)).font(.system(size: 11.0)).dynamicTypeSize(.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(EdgeInsets(top: 6.0, leading: 10.0, bottom: 6.0, trailing: 10.0))
        .background(Color(red: 0.20392156862745098, green: 0.8274509803921568, blue: 0.6, opacity: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        }
        .buttonStyle(.plain)
    } else if let _encoded = "clear_ram".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let _u = URL(string: "mosaic-callback://\(_encoded)") {
        Link(destination: _u) {
            Text("Optimize").bold().foregroundColor(Color(red: 0.023529411764705882, green: 0.1568627450980392, blue: 0.11372549019607843, opacity: 1.0)).font(.system(size: 11.0)).dynamicTypeSize(.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(EdgeInsets(top: 6.0, leading: 10.0, bottom: 6.0, trailing: 10.0))
        .background(Color(red: 0.20392156862745098, green: 0.8274509803921568, blue: 0.6, opacity: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        }
    }
}
    }
}
}.padding(EdgeInsets(top: 14.0, leading: 14.0, bottom: 14.0, trailing: 14.0))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.06666666666666667, green: 0.09411764705882353, blue: 0.15294117647058825, opacity: 1.0), Color(red: 0.12156862745098039, green: 0.1607843137254902, blue: 0.21568627450980393, opacity: 1.0)]), startPoint: UnitPoint(x: 0.0, y: 0.5), endPoint: UnitPoint(x: 1.0, y: 0.5)))
    .clipShape(RoundedRectangle(cornerRadius: 24.0))
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
// previews. resizeMode=both only acts as a fallback for deriving
// supportedFamilies when mosaic.yaml lists no ios.families for this widget.
struct MemoryWidget: Widget {
    let kind: String = "Memory"

    // Built at runtime so iOS 16+ lock-screen accessory families can be added
    // under an availability check (their WidgetFamily cases are iOS 16+).
    private var families: [WidgetFamily] {
        return [.systemSmall, .systemMedium]
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoryProvider()) { entry in
            MemoryView(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("Memory")
        .description("This is an auto-generated home widget.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }
}
