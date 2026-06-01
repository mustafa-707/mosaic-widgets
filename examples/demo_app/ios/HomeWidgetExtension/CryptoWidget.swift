// MOSAIC-GENERATED — do not edit
import SwiftUI
import WidgetKit

struct CryptoWidgetEntry: TimelineEntry {
    let date: Date
    let data: [String: Any]
}

struct CryptoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CryptoWidgetEntry {
        CryptoWidgetEntry(date: Date(), data: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (CryptoWidgetEntry) -> ()) {
        let entry = CryptoWidgetEntry(date: Date(), data: loadData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = CryptoWidgetEntry(date: Date(), data: loadData())
        
                let timeline = Timeline(entries: [entry], policy: .atEnd)
        
        
        completion(timeline)
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "group.com.example.demo_app.widgets"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: CryptoWidgetProvider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        for k in ["btc_change", "btc_price", "global_url"] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

struct CryptoWidgetView: View {
    var entry: CryptoWidgetEntry
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
    Spacer()
    .frame(width: 100.0, height: 100.0)
    .background(Color(hex: (entry.data["accent"] as? String) ?? "#00000000"))
    .clipShape(RoundedRectangle(cornerRadius: 50.0))
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    VStack(alignment: .leading, spacing: 0) {
    Text("BITCOIN").bold().foregroundColor(Color(red: 0.5764705882352941, green: 0.7725490196078432, blue: 0.9921568627450981, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
Text("BTC/USD").bold().foregroundColor(Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#E5E7EB"))).font(.system(size: 14.0)).dynamicTypeSize(.large)
}
Spacer()
Text("₿").font(.system(size: 18.0)).dynamicTypeSize(.large)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .frame(width: 32.0, height: 32.0)
    .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.2))
    .clipShape(RoundedRectangle(cornerRadius: 8.0))
}
Spacer()
VStack(alignment: .leading, spacing: 0) {
    Text(((entry.data["btc_price"] as? NSNumber)?.doubleValue ?? Double("\(entry.data["btc_price"] ?? "0")") ?? 0).formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))).bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 20.0)).dynamicTypeSize(.large)
HStack(alignment: .center, spacing: 0) {
    Text("\(entry.data["btc_change"] as? String ?? String(describing: entry.data["btc_change"] ?? "--"))").bold().foregroundColor(Color(red: 0.2901960784313726, green: 0.8705882352941177, blue: 0.5019607843137255, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Text("24h").foregroundColor(Color(red: 0.5764705882352941, green: 0.7725490196078432, blue: 0.9921568627450981, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 0.0, leading: 4.0, bottom: 0.0, trailing: 0.0))
}
}
Spacer()
HStack(alignment: .center, spacing: 0) {
    if #available(iOS 17.0, *) {
    Button(intent: MosaicRefreshIntent()) {
        Text("Refresh").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 6.0, leading: 12.0, bottom: 6.0, trailing: 12.0))
    .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.1))
    .clipShape(RoundedRectangle(cornerRadius: 10.0))
    }
    .buttonStyle(.plain)
} else if let _u = URL(string: "hwrefresh://") {
    Link(destination: _u) {
        Text("Refresh").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 6.0, leading: 12.0, bottom: 6.0, trailing: 12.0))
    .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.1))
    .clipShape(RoundedRectangle(cornerRadius: 10.0))
    }
}
Spacer()
HStack(alignment: .center, spacing: 0) {
    Text("LIVE: ").bold().foregroundColor(Color(red: 0.5764705882352941, green: 0.7725490196078432, blue: 0.9921568627450981, opacity: 1.0)).font(.system(size: 8.0)).dynamicTypeSize(.large)
Group {
    if #available(iOS 16.0, *) {
        Text(timerInterval: Date(timeIntervalSince1970: 1780302014.236)...Date.distantFuture, countsDown: false)
    } else {
        Text(Date(timeIntervalSince1970: 1780302014.236), style: .timer)
    }
}.foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 8.0)).monospacedDigit()
}
}
}.padding(EdgeInsets(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0))
}
    .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.1450980392156863, green: 0.38823529411764707, blue: 0.9215686274509803, opacity: 1.0), Color(red: 0.11764705882352941, green: 0.22745098039215686, blue: 0.5411764705882353, opacity: 1.0)]), startPoint: .topLeading, endPoint: .bottomTrailing))
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
struct CryptoWidgetWidget: Widget {
    let kind: String = "CryptoWidget"

    // Built at runtime so iOS 16+ lock-screen accessory families can be added
    // under an availability check (their WidgetFamily cases are iOS 16+).
    private var families: [WidgetFamily] {
        var f: [WidgetFamily] = [.systemMedium]
        if #available(iOS 16.0, *) {
            f.append(contentsOf: [.accessoryRectangular])
        }
        return f
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CryptoWidgetProvider()) { entry in
            CryptoWidgetView(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("CryptoWidget")
        .description("This is an auto-generated home widget.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }
}
