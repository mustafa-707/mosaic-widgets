// MOSAIC-GENERATED — do not edit
import SwiftUI
import WidgetKit
import AppIntents

struct CryptoWidgetEntry: TimelineEntry {
    let date: Date
    let data: [String: Any]
}

// iOS 17+ user-configurable parameters surfaced in the widget's edit sheet.
// The chosen values are copied into the timeline entry's `data` dict by the
// provider so the widget tree's existing bind resolution (entry.data[key])
// renders them.
@available(iOS 17.0, macOS 14.0, *)
struct CryptoWidgetConfigIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "CryptoWidget"
    static let description = IntentDescription("Configure this widget.")

    // choices: "BTC/USD", "ETH/USD", "SOL/USD"
    @Parameter(title: "Trading Pair", default: "BTC/USD")
    var pair: String

    @Parameter(title: "Custom Label", default: "BITCOIN")
    var label: String

    @Parameter(title: "Decimals", default: 2.0)
    var decimals: Double

    @Parameter(title: "Compact Mode", default: false)
    var compact: Bool

    init() {}
}

@available(iOS 17.0, macOS 14.0, *)
struct CryptoWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CryptoWidgetEntry {
        CryptoWidgetEntry(date: Date(), data: [:])
    }

    func snapshot(for configuration: CryptoWidgetConfigIntent, in context: Context) async -> CryptoWidgetEntry {
        CryptoWidgetEntry(date: Date(), data: mergedData(configuration))
    }

    func timeline(for configuration: CryptoWidgetConfigIntent, in context: Context) async -> Timeline<CryptoWidgetEntry> {
        let entry = CryptoWidgetEntry(date: Date(), data: mergedData(configuration))
        return Timeline(entries: [entry], policy: .atEnd)
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "group.com.example.demo_app.widgets"

    // Loads App-Group-backed data, then overlays the configured param values
    // (stringified) under their param keys so binds resolve to the user's
    // choices.
    private func mergedData(_ configuration: CryptoWidgetConfigIntent) -> [String: Any] {
        var data = loadData()
        data["pair"] = configuration.pair
        data["label"] = configuration.label
        data["decimals"] = configuration.decimals == configuration.decimals.rounded() ? String(Int(configuration.decimals)) : String(configuration.decimals)
        data["compact"] = configuration.compact ? "true" : "false"
        return data
    }

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: CryptoWidgetProvider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        // Refresh native device metrics first, so bindings read current values
        // rather than whatever the app last stored.
        MosaicDevice.populate()
        // Re-read from disk: the app and the refresh code write through other
        // UserDefaults instances, and without this the widget can render a
        // snapshot taken before those writes.
        defaults.synchronize()
        for k in ["btc_change", "btc_price", "btc_series", "global_url"] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct CryptoWidgetView: View {
    var entry: CryptoWidgetEntry

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
    Spacer()
    .frame(width: 100.0, height: 100.0)
    .background(Color(hex: mosaicStr(entry.data["accent"]) ?? "#00000000").opacity(0.28))
    .clipShape(RoundedRectangle(cornerRadius: 50.0))
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    .offset(x: 30.0, y: -30.0)
VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    VStack(alignment: .leading, spacing: 0) {
    Text("BITCOIN").bold().foregroundColor(Color(red: 0.5764705882352941, green: 0.7725490196078432, blue: 0.9921568627450981, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
Text("BTC/USD").bold().foregroundColor(Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#E5E7EB"))).font(.system(size: 14.0)).dynamicTypeSize(.large)
}
Spacer()
Image(systemName: "bitcoinsign").font(.system(size: 18.0)).foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .frame(width: 32.0, height: 32.0)
    .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.2))
    .clipShape(RoundedRectangle(cornerRadius: 8.0))
}
Spacer()
VStack(alignment: .leading, spacing: 0) {
    Text((mosaicNum(entry.data["btc_price"]) ?? 0).formatted(.currency(code: "USD"))).bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 20.0)).mosaicNumericTransition().dynamicTypeSize(.large)
HStack(alignment: .center, spacing: 0) {
    Text((mosaicNum(entry.data["btc_change"]) ?? 0).formatted(.number.precision(.fractionLength(2)).sign(strategy: .always())) + "%").bold().foregroundColor(Color(red: 0.2901960784313726, green: 0.8705882352941177, blue: 0.5019607843137255, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Text("24h").foregroundColor(Color(red: 0.5764705882352941, green: 0.7725490196078432, blue: 0.9921568627450981, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 0.0, leading: 4.0, bottom: 0.0, trailing: 0.0))
}
}
Spacer()
GeometryReader { geo in
    let raw = mosaicNumList(entry.data["btc_series"])
    let lo = raw.min() ?? 0
    let hi = raw.max() ?? 1
    // A flat series would divide by zero; render it down the middle instead.
    let span = (hi - lo) == 0 ? 1 : (hi - lo)
    let points: [CGFloat] = raw.map { v in
        geo.size.height - (geo.size.height * CGFloat((v - lo) / span))
    }
    ZStack {
                    Path { p in
                        guard points.count > 1 else { return }
                        p.move(to: CGPoint(x: 0, y: geo.size.height))
                        for (i, pt) in points.enumerated() {
                            p.addLine(to: CGPoint(
                                x: geo.size.width * CGFloat(i) / CGFloat(points.count - 1),
                                y: pt))
                        }
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(Color(red: 0.49019607843137253, green: 0.8274509803921568, blue: 0.9882352941176471, opacity: 1.0).opacity(0.18))
        Path { p in
            guard points.count > 1 else { return }
            p.move(to: CGPoint(x: 0, y: points[0]))
            for (i, pt) in points.enumerated().dropFirst() {
                p.addLine(to: CGPoint(
                    x: geo.size.width * CGFloat(i) / CGFloat(points.count - 1),
                    y: pt))
            }
        }
        .stroke(Color(red: 0.49019607843137253, green: 0.8274509803921568, blue: 0.9882352941176471, opacity: 1.0), style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))
    }
}
    .frame(height: 26.0)
Spacer()
HStack(alignment: .center, spacing: 0) {
    Group {
    if #available(iOS 17.0, *) {
        Button(intent: MosaicCallbackIntent(callbackName: "refresh_crypto")) {
            Text("Refresh").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 6.0, leading: 12.0, bottom: 6.0, trailing: 12.0))
        .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10.0))
        }
        .buttonStyle(.plain)
    } else if let _encoded = "refresh_crypto".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let _u = URL(string: "mosaic-callback://\(_encoded)") {
        Link(destination: _u) {
            Text("Refresh").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large).padding(EdgeInsets(top: 6.0, leading: 12.0, bottom: 6.0, trailing: 12.0))
        .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10.0))
        }
    }
}
Spacer()
HStack(alignment: .center, spacing: 0) {
    Text("LIVE: ").bold().foregroundColor(Color(red: 0.5764705882352941, green: 0.7725490196078432, blue: 0.9921568627450981, opacity: 1.0)).font(.system(size: 8.0)).dynamicTypeSize(.large)
Group {
    if #available(iOS 16.0, *) {
        Text(timerInterval: Date(timeIntervalSince1970: 1785663449.2)...Date.distantFuture, countsDown: false)
    } else {
        Text(Date(timeIntervalSince1970: 1785663449.2), style: .timer)
    }
}.foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 8.0)).monospacedDigit()
}
}
}.padding(EdgeInsets(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0))
}
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.1450980392156863, green: 0.38823529411764707, blue: 0.9215686274509803, opacity: 1.0), Color(red: 0.11764705882352941, green: 0.22745098039215686, blue: 0.5411764705882353, opacity: 1.0)]), startPoint: UnitPoint(x: 0.0, y: 0.5), endPoint: UnitPoint(x: 1.0, y: 0.5)))
    .clipShape(RoundedRectangle(cornerRadius: 24.0))
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .widgetURL(URL(string: loadGlobalUrl()))
    }

    private func loadGlobalUrl() -> String {
        return entry.data["global_url"] as? String ?? ""
    }
}

// NOTE: width=2, height=2, previewImage and resizeMode=both
// are advisory on iOS; WidgetKit sizes by family.
@available(iOS 17.0, macOS 14.0, *)
struct CryptoWidgetWidget: Widget {
    let kind: String = "CryptoWidget"

    private var families: [WidgetFamily] {
        var f: [WidgetFamily] = [.systemMedium]
        #if os(iOS)
        if #available(iOS 16.0, *) {
            f.append(contentsOf: [.accessoryRectangular])
        }
        #endif
        return f
    }

    var body: some WidgetConfiguration {
        if #available(iOS 26.0, macOS 26.0, *) {
            return AppIntentConfiguration(kind: kind, intent: CryptoWidgetConfigIntent.self, provider: CryptoWidgetProvider()) { entry in
            CryptoWidgetView(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("Bitcoin Price")
        .description("Live BTC price and 24-hour change.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
                .pushHandler(CryptoWidgetPushHandler.self)
        } else {
            return AppIntentConfiguration(kind: kind, intent: CryptoWidgetConfigIntent.self, provider: CryptoWidgetProvider()) { entry in
            CryptoWidgetView(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("Bitcoin Price")
        .description("Live BTC price and 24-hour change.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
        }
    }
}
/// Receives the APNs token WidgetKit issues for this widget.
///
/// Send `{"aps":{"content-changed":true}}` to that token with
/// `apns-push-type: widgets` and topic `<bundle-id>.push-type.widgets` to
/// reload the timeline with the app closed.
@available(iOS 26.0, macOS 26.0, *)
struct CryptoWidgetPushHandler: WidgetPushHandler {
    init() {}

    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        let hex = pushInfo.token.map { String(format: "%02x", $0) }.joined()
        guard let defaults = UserDefaults(suiteName: kMosaicAppGroup) else { return }
        // Keyed per widget kind: each kind gets its own token.
        defaults.set(hex, forKey: "mosaic_widget_push_token_CryptoWidget")
        defaults.synchronize()
        NSLog("[Mosaic] widget push token for CryptoWidget: \(hex.prefix(8))…")
    }
}
