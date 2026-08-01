// MOSAIC-GENERATED — do not edit
import SwiftUI
import WidgetKit
import AppIntents

struct NewsWidgetEntry: TimelineEntry {
    let date: Date
    let data: [String: Any]
}

struct NewsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NewsWidgetEntry {
        NewsWidgetEntry(date: Date(), data: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (NewsWidgetEntry) -> ()) {
        let entry = NewsWidgetEntry(date: Date(), data: loadData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Fetch, then complete. WidgetKit waits for `completion`, so the fresh
        // values render on this pass. Completing first and reloading afterwards
        // would depend on a second reload, which the system may throttle away.
        Task {
            await MosaicRefreshSources.run(keys: ["global_url", "news_image", "news_source", "news_title", "news_title_2", "news_updated"])
            // Network images: download after the refresh, so a URL that arrived
            // in this same pass is fetched immediately rather than one timeline
            // later. Cached URLs cost nothing.
            await MosaicImageCache.prefetch([mosaicStr(loadData()["news_image"])].compactMap { $0 })
            let entry = NewsWidgetEntry(date: Date(), data: loadData())

                        let nextUpdate = Calendar.current.date(byAdding: .second, value: 900, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            

            completion(timeline)
        }
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "group.com.example.demo_app.widgets"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: NewsWidgetProvider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        // Refresh native device metrics first, so bindings read current values
        // rather than whatever the app last stored.
        MosaicDevice.populate()
        // Re-read from disk: the app and the refresh code write through other
        // UserDefaults instances, and without this the widget can render a
        // snapshot taken before those writes.
        defaults.synchronize()
        for k in ["global_url", "news_image", "news_source", "news_title", "news_title_2", "news_updated"] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

struct NewsWidgetView: View {
    var entry: NewsWidgetEntry
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
    Spacer()
    .frame(width: 4.0, height: 100.0)
    .background(Color(red: 0.9568627450980393, green: 0.24705882352941178, blue: 0.3686274509803922, opacity: 1.0))
    .clipped()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
Group {
    if let _img = MosaicImageCache.cached(mosaicStr(entry.data["news_image"])) {
        Image(mosaic: _img).resizable().mosaicAccentedRendering("fullColor").aspectRatio(contentMode: .fill).clipShape(RoundedRectangle(cornerRadius: 16.0))
    } else {
        Color(red: 0.11764705882352941, green: 0.1607843137254902, blue: 0.23137254901960785, opacity: 1.0).clipShape(RoundedRectangle(cornerRadius: 16.0))
    }
}
    .frame(width: 88.0)
    .clipped()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    Text(LocalizedStringKey("trending_now")).bold().foregroundColor(Color(red: 0.9568627450980393, green: 0.24705882352941178, blue: 0.3686274509803922, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
Spacer()
Text(Date(timeIntervalSince1970: (mosaicNum(entry.data["news_updated"]) ?? 0) / 1000.0), style: .relative).foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
}
Spacer()
// MFlipper cycles on Android only; showing the first child.
Text("\(mosaicStr(entry.data["news_title"]) ?? "--")").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).lineLimit(2).dynamicTypeSize(.large)
Spacer()
HStack(alignment: .center, spacing: 0) {
    Text("\(mosaicStr(entry.data["news_source"]) ?? "--")").foregroundColor(Color(red: 0.39215686274509803, green: 0.4549019607843137, blue: 0.5450980392156862, opacity: 1.0)).font(.system(size: 10.0)).lineLimit(1).dynamicTypeSize(.large)
Spacer()
Group {
    if #available(iOS 17.0, *) {
        Button(intent: MosaicCallbackIntent(callbackName: "refresh_news")) {
            Text(LocalizedStringKey("read_action")).bold().foregroundColor(Color(red: 0.9568627450980393, green: 0.24705882352941178, blue: 0.3686274509803922, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 4.0, leading: 10.0, bottom: 4.0, trailing: 10.0))
        .background(Color(red: 0.9568627450980393, green: 0.24705882352941178, blue: 0.3686274509803922, opacity: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        }
        .buttonStyle(.plain)
    } else if let _encoded = "refresh_news".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let _u = URL(string: "mosaic-callback://\(_encoded)") {
        Link(destination: _u) {
            Text(LocalizedStringKey("read_action")).bold().foregroundColor(Color(red: 0.9568627450980393, green: 0.24705882352941178, blue: 0.3686274509803922, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 4.0, leading: 10.0, bottom: 4.0, trailing: 10.0))
        .background(Color(red: 0.9568627450980393, green: 0.24705882352941178, blue: 0.3686274509803922, opacity: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        }
    }
}
}
}.padding(EdgeInsets(top: 16.0, leading: 16.0, bottom: 16.0, trailing: 104.0))
}
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.058823529411764705, green: 0.09019607843137255, blue: 0.16470588235294117, opacity: 1.0), Color(red: 0.11764705882352941, green: 0.1607843137254902, blue: 0.23137254901960785, opacity: 1.0)]), startPoint: UnitPoint(x: 0.0, y: 0.5), endPoint: UnitPoint(x: 1.0, y: 0.5)))
    .clipShape(RoundedRectangle(cornerRadius: 24.0))
    .overlay(RoundedRectangle(cornerRadius: 24.0).stroke(Color(red: 0.2, green: 0.2549019607843137, blue: 0.3333333333333333, opacity: 1.0), lineWidth: 1.0))
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
// previews. resizeMode=horizontal only acts as a fallback for deriving
// supportedFamilies when mosaic.yaml lists no ios.families for this widget.
struct NewsWidgetWidget: Widget {
    let kind: String = "NewsWidget"

    // Built at runtime so iOS 16+ lock-screen accessory families can be added
    // under an availability check (their WidgetFamily cases are iOS 16+).
    private var families: [WidgetFamily] {
        return [.systemMedium]
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NewsWidgetProvider()) { entry in
            NewsWidgetView(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("Top Headline")
        .description("The latest space and science headline.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }
}
