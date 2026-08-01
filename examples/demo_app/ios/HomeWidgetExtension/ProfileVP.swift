// MOSAIC-GENERATED — do not edit
import SwiftUI
import WidgetKit
import AppIntents

struct ProfileVPEntry: TimelineEntry {
    let date: Date
    let data: [String: Any]
}

struct ProfileVPProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProfileVPEntry {
        ProfileVPEntry(date: Date(), data: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (ProfileVPEntry) -> ()) {
        let entry = ProfileVPEntry(date: Date(), data: loadData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Fetch, then complete. WidgetKit waits for `completion`, so the fresh
        // values render on this pass. Completing first and reloading afterwards
        // would depend on a second reload, which the system may throttle away.
        Task {
            await MosaicRefreshSources.run(keys: ["global_url", "mosaic_battery_level", "mosaic_storage_free_gb", "storage_week", "system_status"])
            // Network images: download after the refresh, so a URL that arrived
            // in this same pass is fetched immediately rather than one timeline
            // later. Cached URLs cost nothing.
            await MosaicImageCache.prefetch([])
            let entry = ProfileVPEntry(date: Date(), data: loadData())

                        let timeline = Timeline(entries: [entry], policy: .atEnd)
            

            completion(timeline)
        }
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "group.com.example.demo_app.widgets"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: ProfileVPProvider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        // Refresh native device metrics first, so bindings read current values
        // rather than whatever the app last stored.
        MosaicDevice.populate()
        // Re-read from disk: the app and the refresh code write through other
        // UserDefaults instances, and without this the widget can render a
        // snapshot taken before those writes.
        defaults.synchronize()
        for k in ["global_url", "mosaic_battery_level", "mosaic_storage_free_gb", "storage_week", "system_status"] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

struct ProfileVPView: View {
    var entry: ProfileVPEntry
    @Environment(\.widgetFamily) private var family
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if mosaicPrefersCompact(family) {
                    VStack(alignment: .leading, spacing: 0) {
    Spacer()
Text("BATTERY").bold().foregroundColor(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0)).font(.system(size: 9.0)).dynamicTypeSize(.large)
HStack(alignment: .bottom, spacing: 0) {
    Text("\(mosaicStr(entry.data["mosaic_battery_level"]) ?? "--")").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 34.0)).dynamicTypeSize(.large)
Text("%").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 13.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 0.0, leading: 2.0, bottom: 5.0, trailing: 0.0))
}.accessibilityLabel(Text("Battery level"))
ProgressView(value: (mosaicNum(entry.data["mosaic_battery_level"]) ?? 0), total: 100.0).tint(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0))
Spacer()
}.padding(EdgeInsets(top: 14.0, leading: 14.0, bottom: 14.0, trailing: 14.0))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.058823529411764705, green: 0.09019607843137255, blue: 0.16470588235294117, opacity: 1.0), Color(red: 0.11764705882352941, green: 0.1607843137254902, blue: 0.23137254901960785, opacity: 1.0)]), startPoint: UnitPoint(x: 0.0, y: 0.5), endPoint: UnitPoint(x: 1.0, y: 0.5)))
    .clipShape(RoundedRectangle(cornerRadius: 28.0))
    .overlay(RoundedRectangle(cornerRadius: 28.0).stroke(Color(red: 0.2, green: 0.2549019607843137, blue: 0.3333333333333333, opacity: 1.0), lineWidth: 1.5))
                } else {
                    ZStack(alignment: .topLeading) {
    Spacer()
    .frame(width: 80.0, height: 80.0)
    .background(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 0.1))
    .clipShape(RoundedRectangle(cornerRadius: 40.0))
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    .offset(x: 20.0, y: -20.0)
VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    VStack(alignment: .leading, spacing: 0) {
    Text("SYSTEM STATUS").bold().foregroundColor(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0)).font(.system(size: 9.0)).dynamicTypeSize(.large)
Text("\(mosaicStr(entry.data["system_status"]) ?? "--")").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
}
Spacer()
Image(systemName: "bolt.fill").font(.system(size: 12.0)).foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .frame(width: 24.0, height: 24.0)
    .background(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0))
    .clipShape(RoundedRectangle(cornerRadius: 12.0))
}
Color.clear
    .frame(height: 10.0)
VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    Text("Battery").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Spacer()
HStack(alignment: .center, spacing: 0) {
    Text("\(mosaicStr(entry.data["mosaic_battery_level"]) ?? "--")").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).dynamicTypeSize(.large)
Text("%").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
}
}
Color.clear
    .frame(height: 4.0)
ProgressView(value: (mosaicNum(entry.data["mosaic_battery_level"]) ?? 0), total: 100.0).tint(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0))
Color.clear
    .frame(height: 4.0)
}.accessibilityElement(children: .ignore).accessibilityLabel(Text("Battery level"))
Color.clear
    .frame(height: 10.0)
VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    Text("Free").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Spacer()
HStack(alignment: .center, spacing: 0) {
    Text("\(mosaicStr(entry.data["mosaic_storage_free_gb"]) ?? "--")").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).dynamicTypeSize(.large)
Text("GB").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
}
}
Color.clear
    .frame(height: 6.0)
GeometryReader { geo in
    let raw = mosaicNumList(entry.data["storage_week"])
    let hi = raw.max() ?? 0
    let scale = hi <= 0 ? 0 : hi
    HStack(alignment: .bottom, spacing: 3.0) {
        ForEach(Array(raw.enumerated()), id: \.offset) { _, v in
            RoundedRectangle(cornerRadius: 2.0)
                .fill(Color(red: 0.13333333333333333, green: 0.7725490196078432, blue: 0.3686274509803922, opacity: 1.0))
                .frame(height: scale == 0
                    ? 0
                    : max(1, geo.size.height * CGFloat(max(0, v) / scale)))
                .frame(maxWidth: .infinity, alignment: .bottom)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
}
    .frame(height: 22.0)
}.accessibilityLabel(Text("Free storage, last 7 days"))
Color.clear
    .frame(height: 10.0)
HStack(alignment: .center, spacing: 0) {
    Group {
    if let _u = URL(string: "hwdemo://profile/details") {
        Link(destination: _u) {
            Text("Details").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 6.0, leading: 8.0, bottom: 6.0, trailing: 8.0))
        .background(Color(red: 0.11764705882352941, green: 0.1607843137254902, blue: 0.23137254901960785, opacity: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        .overlay(RoundedRectangle(cornerRadius: 8.0).stroke(Color(red: 0.2, green: 0.2549019607843137, blue: 0.3333333333333333, opacity: 1.0), lineWidth: 1.0))
        }
    }
}
    .frame(maxWidth: .infinity, maxHeight: .infinity)
Color.clear
    .frame(width: 8.0)
Group {
    if #available(iOS 17.0, *) {
        Button(intent: MosaicRefreshIntent()) {
            Text("Refresh").bold().foregroundColor(Color(red: 0.058823529411764705, green: 0.09019607843137255, blue: 0.16470588235294117, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 6.0, leading: 8.0, bottom: 6.0, trailing: 8.0))
        .background(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        }
        .buttonStyle(.plain)
    } else if let _u = URL(string: "hwrefresh://") {
        Link(destination: _u) {
            Text("Refresh").bold().foregroundColor(Color(red: 0.058823529411764705, green: 0.09019607843137255, blue: 0.16470588235294117, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 6.0, leading: 8.0, bottom: 6.0, trailing: 8.0))
        .background(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        }
    }
}
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
}.padding(EdgeInsets(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0))
}
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.058823529411764705, green: 0.09019607843137255, blue: 0.16470588235294117, opacity: 1.0), Color(red: 0.11764705882352941, green: 0.1607843137254902, blue: 0.23137254901960785, opacity: 1.0)]), startPoint: UnitPoint(x: 0.0, y: 0.5), endPoint: UnitPoint(x: 1.0, y: 0.5)))
    .clipShape(RoundedRectangle(cornerRadius: 28.0))
    .overlay(RoundedRectangle(cornerRadius: 28.0).stroke(Color(red: 0.2, green: 0.2549019607843137, blue: 0.3333333333333333, opacity: 1.0), lineWidth: 1.5))
                }
            }
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
struct ProfileVPWidget: Widget {
    let kind: String = "ProfileVP"

    // Built at runtime so iOS 16+ lock-screen accessory families can be added
    // under an availability check (their WidgetFamily cases are iOS 16+).
    private var families: [WidgetFamily] {
        return [.systemSmall, .systemMedium]
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProfileVPProvider()) { entry in
            ProfileVPView(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("System Status")
        .description("Battery, memory and system health at a glance.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }
}
