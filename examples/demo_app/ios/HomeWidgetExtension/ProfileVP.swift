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
        let entry = ProfileVPEntry(date: Date(), data: loadData())
        
                let timeline = Timeline(entries: [entry], policy: .atEnd)
        
        
        completion(timeline)
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "group.com.example.demo_app.widgets"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: ProfileVPProvider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        for k in ["battery_level", "battery_progress", "global_url", "memory_progress", "memory_usage", "system_status"] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

struct ProfileVPView: View {
    var entry: ProfileVPEntry
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
    Spacer()
    .frame(width: 80.0, height: 80.0)
    .background(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 0.1))
    .clipShape(RoundedRectangle(cornerRadius: 40.0))
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    VStack(alignment: .leading, spacing: 0) {
    Text("SYSTEM STATUS").bold().foregroundColor(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0)).font(.system(size: 9.0)).dynamicTypeSize(.large)
Text("\(entry.data["system_status"] as? String ?? String(describing: entry.data["system_status"] ?? "--"))").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
}
Spacer()
Image(systemName: "bolt.fill").font(.system(size: 12.0)).foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .frame(width: 24.0, height: 24.0)
    .background(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0))
    .clipShape(RoundedRectangle(cornerRadius: 12.0))
}
Spacer()
VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    Text("Battery").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Spacer()
HStack(alignment: .center, spacing: 0) {
    Text("\(entry.data["battery_level"] as? String ?? String(describing: entry.data["battery_level"] ?? "--"))").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).dynamicTypeSize(.large)
Text("%").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
}
}
ProgressView(value: ((entry.data["battery_progress"] as? NSNumber)?.doubleValue ?? Double("\(entry.data["battery_progress"] ?? "0")") ?? 0), total: 100.0).tint(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0)).padding(EdgeInsets(top: 4.0, leading: 0.0, bottom: 4.0, trailing: 0.0))
}
Spacer()
VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    Text("Memory").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Spacer()
HStack(alignment: .center, spacing: 0) {
    Text("\(entry.data["memory_usage"] as? String ?? String(describing: entry.data["memory_usage"] ?? "--"))").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).dynamicTypeSize(.large)
Text("GB").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
}
}
ProgressView(value: ((entry.data["memory_progress"] as? NSNumber)?.doubleValue ?? Double("\(entry.data["memory_progress"] ?? "0")") ?? 0), total: 100.0).tint(Color(red: 0.13333333333333333, green: 0.7725490196078432, blue: 0.3686274509803922, opacity: 1.0)).padding(EdgeInsets(top: 4.0, leading: 0.0, bottom: 4.0, trailing: 0.0))
}
Spacer()
HStack(alignment: .center, spacing: 0) {
    if let _u = URL(string: "hwdemo://profile/details") {
    Link(destination: _u) {
        Text("Details").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 6.0, leading: 8.0, bottom: 6.0, trailing: 8.0))
    .background(Color(red: 0.11764705882352941, green: 0.1607843137254902, blue: 0.23137254901960785, opacity: 1.0))
    .clipShape(RoundedRectangle(cornerRadius: 8.0))
    .overlay(RoundedRectangle(cornerRadius: 8.0).stroke(Color(red: 0.2, green: 0.2549019607843137, blue: 0.3333333333333333, opacity: 1.0), lineWidth: 1.0))
    }
}
Spacer()
if #available(iOS 17.0, *) {
    Button(intent: MosaicCallbackIntent(callbackName: "refresh_all")) {
        Text("Refresh").bold().foregroundColor(Color(red: 0.058823529411764705, green: 0.09019607843137255, blue: 0.16470588235294117, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 6.0, leading: 8.0, bottom: 6.0, trailing: 8.0))
    .background(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0))
    .clipShape(RoundedRectangle(cornerRadius: 8.0))
    }
    .buttonStyle(.plain)
} else if let _encoded = "refresh_all".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
          let _u = URL(string: "mosaic-callback://\(_encoded)") {
    Link(destination: _u) {
        Text("Refresh").bold().foregroundColor(Color(red: 0.058823529411764705, green: 0.09019607843137255, blue: 0.16470588235294117, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 6.0, leading: 8.0, bottom: 6.0, trailing: 8.0))
    .background(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0))
    .clipShape(RoundedRectangle(cornerRadius: 8.0))
    }
}
}
}.padding(EdgeInsets(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0))
}
    .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.058823529411764705, green: 0.09019607843137255, blue: 0.16470588235294117, opacity: 1.0), Color(red: 0.11764705882352941, green: 0.1607843137254902, blue: 0.23137254901960785, opacity: 1.0)]), startPoint: UnitPoint(x: 0.0, y: 0.5), endPoint: UnitPoint(x: 1.0, y: 0.5)))
    .clipShape(RoundedRectangle(cornerRadius: 28.0))
    .overlay(RoundedRectangle(cornerRadius: 28.0).stroke(Color(red: 0.2, green: 0.2549019607843137, blue: 0.3333333333333333, opacity: 1.0), lineWidth: 1.5))
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
        .configurationDisplayName("ProfileVP")
        .description("This is an auto-generated home widget.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }
}
