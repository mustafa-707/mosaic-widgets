import SwiftUI
import WidgetKit

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

    private func loadData() -> [String: Any] {
        if let defaults = UserDefaults(suiteName: "group.com.example.demo_app.widgets") {
            return defaults.dictionaryRepresentation()
        }
        return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
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
Text("\(entry.data["system_status"] ?? "--")").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
}
Spacer()
Text("⚡").font(.system(size: 12.0)).dynamicTypeSize(.large)
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
    Text("\(entry.data["battery_level"] ?? "--")").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).dynamicTypeSize(.large)
Text("%").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
}
}
ProgressView(value: Double("\(entry.data["battery_progress"] ?? 0)") ?? 0.0, total: 100.0).tint(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0)).padding(EdgeInsets(top: 4.0, leading: 0.0, bottom: 4.0, trailing: 0.0))
}
Spacer()
VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    Text("Memory").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Spacer()
HStack(alignment: .center, spacing: 0) {
    Text("\(entry.data["memory_usage"] ?? "--")").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).dynamicTypeSize(.large)
Text("GB").foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
}
}
ProgressView(value: Double("\(entry.data["memory_progress"] ?? 0)") ?? 0.0, total: 100.0).tint(Color(red: 0.13333333333333333, green: 0.7725490196078432, blue: 0.3686274509803922, opacity: 1.0)).padding(EdgeInsets(top: 4.0, leading: 0.0, bottom: 4.0, trailing: 0.0))
}
Spacer()
HStack(alignment: .center, spacing: 0) {
    Link(destination: URL(string: "hwdemo://profile/details")!) {
    Text("Details").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 6.0, leading: 8.0, bottom: 6.0, trailing: 8.0))
    .background(Color(red: 0.11764705882352941, green: 0.1607843137254902, blue: 0.23137254901960785, opacity: 1.0))
    .clipShape(RoundedRectangle(cornerRadius: 8.0))
    .overlay(RoundedRectangle(cornerRadius: 8.0).stroke(Color(hex: "#334155"), lineWidth: 1.0))
}
Spacer()
Link(destination: URL(string: "hwrefresh://")!) {
    Text("Refresh").bold().foregroundColor(Color(red: 0.058823529411764705, green: 0.09019607843137255, blue: 0.16470588235294117, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 6.0, leading: 8.0, bottom: 6.0, trailing: 8.0))
    .background(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0))
    .clipShape(RoundedRectangle(cornerRadius: 8.0))
}
}
}.padding(EdgeInsets(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0))
}
    .background(LinearGradient(gradient: Gradient(colors: [Color(hex: "#0F172A"), Color(hex: "#1E293B")]), startPoint: .top, endPoint: .bottom))
    .clipShape(RoundedRectangle(cornerRadius: 28.0))
    .overlay(RoundedRectangle(cornerRadius: 28.0).stroke(Color(hex: "#334155"), lineWidth: 1.5))
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .widgetURL(URL(string: loadGlobalUrl()))
    }

    private func loadGlobalUrl() -> String {
        return entry.data["global_url"] as? String ?? ""
    }
}

struct ProfileVPWidget: Widget {
    let kind: String = "ProfileVP"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProfileVPProvider()) { entry in
            ProfileVPView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("ProfileVP")
        .description("This is an auto-generated home widget.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
