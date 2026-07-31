// MOSAIC-GENERATED — do not edit
import SwiftUI
import WidgetKit
import AppIntents

struct SearchBarEntry: TimelineEntry {
    let date: Date
    let data: [String: Any]
}

struct SearchBarProvider: TimelineProvider {
    func placeholder(in context: Context) -> SearchBarEntry {
        SearchBarEntry(date: Date(), data: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (SearchBarEntry) -> ()) {
        let entry = SearchBarEntry(date: Date(), data: loadData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Fetch, then complete. WidgetKit waits for `completion`, so the fresh
        // values render on this pass. Completing first and reloading afterwards
        // would depend on a second reload, which the system may throttle away.
        Task {
            await MosaicRefreshSources.run(keys: ["global_url"])
            // Network images: download after the refresh, so a URL that arrived
            // in this same pass is fetched immediately rather than one timeline
            // later. Cached URLs cost nothing.
            await MosaicImageCache.prefetch([])
            let entry = SearchBarEntry(date: Date(), data: loadData())

                        let timeline = Timeline(entries: [entry], policy: .atEnd)
            

            completion(timeline)
        }
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "group.com.example.demo_app.widgets"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: SearchBarProvider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        // Refresh native device metrics first, so bindings read current values
        // rather than whatever the app last stored.
        MosaicDevice.populate()
        // Re-read from disk: the app and the refresh code write through other
        // UserDefaults instances, and without this the widget can render a
        // snapshot taken before those writes.
        defaults.synchronize()
        for k in ["global_url"] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

struct SearchBarView: View {
    var entry: SearchBarEntry
    
    var body: some View {
        GeometryReader { geometry in
            Group {
    if let _u = URL(string: "hwdemo://search") {
        Link(destination: _u) {
            HStack(alignment: .center, spacing: 0) {
        Image(systemName: "magnifyingglass").font(.system(size: 18.0)).foregroundColor(Color(light: Color(hex: "#64748B"), dark: Color(hex: "#94A3B8")))
    Text("Search anything").foregroundColor(Color(light: Color(hex: "#64748B"), dark: Color(hex: "#94A3B8"))).font(.system(size: 14.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 0.0, leading: 10.0, bottom: 0.0, trailing: 0.0))
    Spacer()
    Group {
        if let _u = URL(string: "hwdemo://search?mode=voice") {
            Link(destination: _u) {
                Image(systemName: "mic.fill").font(.system(size: 18.0)).foregroundColor(Color(red: 0.1450980392156863, green: 0.38823529411764707, blue: 0.9215686274509803, opacity: 1.0))
            }
        }
    }
    Group {
        if let _u = URL(string: "hwdemo://search?mode=lens") {
            Link(destination: _u) {
                Image(systemName: "camera.fill").font(.system(size: 18.0)).foregroundColor(Color(red: 0.1450980392156863, green: 0.38823529411764707, blue: 0.9215686274509803, opacity: 1.0)).padding(EdgeInsets(top: 0.0, leading: 14.0, bottom: 0.0, trailing: 0.0))
            }
        }
    }
    }.padding(EdgeInsets(top: 12.0, leading: 16.0, bottom: 12.0, trailing: 16.0))
        }
    }
}
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#1E293B")))
    .clipShape(RoundedRectangle(cornerRadius: 26.0))
    .shadow(color: Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.18), radius: 10.0, x: 0.0, y: 2.0)
    .overlay(RoundedRectangle(cornerRadius: 26.0).stroke(Color(red: 0.8862745098039215, green: 0.9098039215686274, blue: 0.9411764705882353, opacity: 1.0), lineWidth: 1.0))
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .widgetURL(URL(string: loadGlobalUrl()))
    }

    private func loadGlobalUrl() -> String {
        return entry.data["global_url"] as? String ?? ""
    }
}

// NOTE: On iOS, widget sizing is governed by WidgetFamily / supportedFamilies,
// not by the definition's width/height. The definition's width=4,
// height=1 and previewImage are advisory on iOS and not used by
// WidgetKit, which sizes by family and renders the placeholder() view for
// previews. resizeMode=none only acts as a fallback for deriving
// supportedFamilies when mosaic.yaml lists no ios.families for this widget.
struct SearchBarWidget: Widget {
    let kind: String = "SearchBar"

    // Built at runtime so iOS 16+ lock-screen accessory families can be added
    // under an availability check (their WidgetFamily cases are iOS 16+).
    private var families: [WidgetFamily] {
        return [.systemMedium, .systemLarge]
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SearchBarProvider()) { entry in
            SearchBarView(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("Search")
        .description("A search pill that opens the app, with voice and lens shortcuts.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }
}
