import SwiftUI
import WidgetKit

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
        let entry = NewsWidgetEntry(date: Date(), data: loadData())
        
                let nextUpdate = Calendar.current.date(byAdding: .second, value: 900, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        
        completion(timeline)
    }

    private func loadData() -> [String: Any] {
        if let defaults = UserDefaults(suiteName: "group.com.example.demo_app.widgets") {
            return defaults.dictionaryRepresentation()
        }
        return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
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
VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    Text("TRENDING NOW").bold().foregroundColor(Color(red: 0.9568627450980393, green: 0.24705882352941178, blue: 0.3686274509803922, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
Spacer()
HStack(alignment: .center, spacing: 0) {
    Text(Date(timeIntervalSince1970: 1770123605.122), style: .timer).bold().foregroundColor(Color(red: 0.13333333333333333, green: 0.7725490196078432, blue: 0.3686274509803922, opacity: 1.0)).font(.system(size: 10.0)).monospacedDigit()
Text("LIVE").bold().foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 0.0, leading: 4.0, bottom: 0.0, trailing: 0.0))
}
}
Spacer()
Text("\(entry.data["news_title"] ?? "--")").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).dynamicTypeSize(.large)
Spacer()
HStack(alignment: .center, spacing: 0) {
    VStack(alignment: .leading, spacing: 0) {
    Text("World News • Just now").foregroundColor(Color(red: 0.39215686274509803, green: 0.4549019607843137, blue: 0.5450980392156862, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
}
Spacer()
Link(destination: URL(string: "hwcallback://refresh_news")!) {
    Text("READ").bold().foregroundColor(Color(red: 0.9568627450980393, green: 0.24705882352941178, blue: 0.3686274509803922, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 4.0, leading: 10.0, bottom: 4.0, trailing: 10.0))
    .background(Color(red: 0.9568627450980393, green: 0.24705882352941178, blue: 0.3686274509803922, opacity: 0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8.0))
}
}
}.padding(EdgeInsets(top: 16.0, leading: 16.0, bottom: 16.0, trailing: 16.0))
}
    .background(LinearGradient(gradient: Gradient(colors: [Color(hex: "#0F172A"), Color(hex: "#1E293B")]), startPoint: .top, endPoint: .bottom))
    .clipShape(RoundedRectangle(cornerRadius: 24.0))
    .overlay(RoundedRectangle(cornerRadius: 24.0).stroke(Color(hex: "#334155"), lineWidth: 1.0))
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .widgetURL(URL(string: loadGlobalUrl()))
    }

    private func loadGlobalUrl() -> String {
        return entry.data["global_url"] as? String ?? ""
    }
}

struct NewsWidgetWidget: Widget {
    let kind: String = "NewsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NewsWidgetProvider()) { entry in
            NewsWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("NewsWidget")
        .description("This is an auto-generated home widget.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
