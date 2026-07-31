// MOSAIC-GENERATED — do not edit
import SwiftUI
import WidgetKit
import AppIntents

struct FlashlightEntry: TimelineEntry {
    let date: Date
    let data: [String: Any]
}

struct FlashlightProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlashlightEntry {
        FlashlightEntry(date: Date(), data: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (FlashlightEntry) -> ()) {
        let entry = FlashlightEntry(date: Date(), data: loadData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Fetch, then complete. WidgetKit waits for `completion`, so the fresh
        // values render on this pass. Completing first and reloading afterwards
        // would depend on a second reload, which the system may throttle away.
        Task {
            await MosaicRefreshSources.run(keys: ["global_url", "torch_on"])
            // Network images: download after the refresh, so a URL that arrived
            // in this same pass is fetched immediately rather than one timeline
            // later. Cached URLs cost nothing.
            await MosaicImageCache.prefetch([])
            let entry = FlashlightEntry(date: Date(), data: loadData())

                        let timeline = Timeline(entries: [entry], policy: .atEnd)
            

            completion(timeline)
        }
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "group.com.example.demo_app.widgets"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: FlashlightProvider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        // Refresh native device metrics first, so bindings read current values
        // rather than whatever the app last stored.
        MosaicDevice.populate()
        // Re-read from disk: the app and the refresh code write through other
        // UserDefaults instances, and without this the widget can render a
        // snapshot taken before those writes.
        defaults.synchronize()
        for k in ["global_url", "torch_on"] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

struct FlashlightView: View {
    var entry: FlashlightEntry
    
    var body: some View {
        GeometryReader { geometry in
            Group {
    if #available(iOS 17.0, *) {
        Button(intent: MosaicToggleIntent(key: "torch_on")) {
            Group {
        if mosaicBool(entry.data["torch_on"]) {
            ZStack(alignment: .topLeading) {
        Spacer()
        .frame(width: 64.0, height: 64.0)
        .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.28))
        .clipShape(RoundedRectangle(cornerRadius: 32.0))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: -34.0, y: -34.0)
    VStack(alignment: .center, spacing: 0) {
        Spacer()
    Image(systemName: "flashlight.on.fill").font(.system(size: 32.0)).foregroundColor(Color(red: 0.25882352941176473, green: 0.12549019607843137, blue: 0.023529411764705882, opacity: 1.0))
    Color.clear
        .frame(height: 6.0)
    Text("ON").bold().foregroundColor(Color(red: 0.25882352941176473, green: 0.12549019607843137, blue: 0.023529411764705882, opacity: 0.75)).font(.system(size: 10.0)).multilineTextAlignment(.center).dynamicTypeSize(.large)
    Spacer()
    }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.9921568627450981, green: 0.8784313725490196, blue: 0.2784313725490196, opacity: 1.0), Color(red: 0.9607843137254902, green: 0.6196078431372549, blue: 0.043137254901960784, opacity: 1.0)]), startPoint: UnitPoint(x: 0.853553, y: 0.146447), endPoint: UnitPoint(x: 0.146447, y: 0.853553)))
        .clipShape(RoundedRectangle(cornerRadius: 22.0)).accessibilityElement(children: .ignore).accessibilityLabel(Text("Flashlight on, tap to turn off"))
        } else {
            ZStack(alignment: .topLeading) {
        Spacer()
        .frame(width: 64.0, height: 64.0)
        .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 32.0))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: -34.0, y: -34.0)
    VStack(alignment: .center, spacing: 0) {
        Spacer()
    Image(systemName: "flashlight.off.fill").font(.system(size: 32.0)).foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0))
    Color.clear
        .frame(height: 6.0)
    Text("OFF").bold().foregroundColor(Color(red: 0.39215686274509803, green: 0.4549019607843137, blue: 0.5450980392156862, opacity: 1.0)).font(.system(size: 10.0)).multilineTextAlignment(.center).dynamicTypeSize(.large)
    Spacer()
    }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.2, green: 0.2549019607843137, blue: 0.3333333333333333, opacity: 1.0), Color(red: 0.11764705882352941, green: 0.1607843137254902, blue: 0.23137254901960785, opacity: 1.0)]), startPoint: UnitPoint(x: 0.853553, y: 0.146447), endPoint: UnitPoint(x: 0.146447, y: 0.853553)))
        .clipShape(RoundedRectangle(cornerRadius: 22.0)).accessibilityElement(children: .ignore).accessibilityLabel(Text("Flashlight off, tap to turn on"))
        }
    }
        }
        .buttonStyle(.plain)
    } else if let _u = URL(string: "hwrefresh://") {
        Link(destination: _u) {
            Group {
        if mosaicBool(entry.data["torch_on"]) {
            ZStack(alignment: .topLeading) {
        Spacer()
        .frame(width: 64.0, height: 64.0)
        .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.28))
        .clipShape(RoundedRectangle(cornerRadius: 32.0))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: -34.0, y: -34.0)
    VStack(alignment: .center, spacing: 0) {
        Spacer()
    Image(systemName: "flashlight.on.fill").font(.system(size: 32.0)).foregroundColor(Color(red: 0.25882352941176473, green: 0.12549019607843137, blue: 0.023529411764705882, opacity: 1.0))
    Color.clear
        .frame(height: 6.0)
    Text("ON").bold().foregroundColor(Color(red: 0.25882352941176473, green: 0.12549019607843137, blue: 0.023529411764705882, opacity: 0.75)).font(.system(size: 10.0)).multilineTextAlignment(.center).dynamicTypeSize(.large)
    Spacer()
    }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.9921568627450981, green: 0.8784313725490196, blue: 0.2784313725490196, opacity: 1.0), Color(red: 0.9607843137254902, green: 0.6196078431372549, blue: 0.043137254901960784, opacity: 1.0)]), startPoint: UnitPoint(x: 0.853553, y: 0.146447), endPoint: UnitPoint(x: 0.146447, y: 0.853553)))
        .clipShape(RoundedRectangle(cornerRadius: 22.0)).accessibilityElement(children: .ignore).accessibilityLabel(Text("Flashlight on, tap to turn off"))
        } else {
            ZStack(alignment: .topLeading) {
        Spacer()
        .frame(width: 64.0, height: 64.0)
        .background(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 32.0))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: -34.0, y: -34.0)
    VStack(alignment: .center, spacing: 0) {
        Spacer()
    Image(systemName: "flashlight.off.fill").font(.system(size: 32.0)).foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0))
    Color.clear
        .frame(height: 6.0)
    Text("OFF").bold().foregroundColor(Color(red: 0.39215686274509803, green: 0.4549019607843137, blue: 0.5450980392156862, opacity: 1.0)).font(.system(size: 10.0)).multilineTextAlignment(.center).dynamicTypeSize(.large)
    Spacer()
    }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.2, green: 0.2549019607843137, blue: 0.3333333333333333, opacity: 1.0), Color(red: 0.11764705882352941, green: 0.1607843137254902, blue: 0.23137254901960785, opacity: 1.0)]), startPoint: UnitPoint(x: 0.853553, y: 0.146447), endPoint: UnitPoint(x: 0.146447, y: 0.853553)))
        .clipShape(RoundedRectangle(cornerRadius: 22.0)).accessibilityElement(children: .ignore).accessibilityLabel(Text("Flashlight off, tap to turn on"))
        }
    }
        }
    }
}
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .widgetURL(URL(string: loadGlobalUrl()))
    }

    private func loadGlobalUrl() -> String {
        return entry.data["global_url"] as? String ?? ""
    }
}

// NOTE: On iOS, widget sizing is governed by WidgetFamily / supportedFamilies,
// not by the definition's width/height. The definition's width=1,
// height=1 and previewImage are advisory on iOS and not used by
// WidgetKit, which sizes by family and renders the placeholder() view for
// previews. resizeMode=none only acts as a fallback for deriving
// supportedFamilies when mosaic.yaml lists no ios.families for this widget.
struct FlashlightWidget: Widget {
    let kind: String = "Flashlight"

    // Built at runtime so iOS 16+ lock-screen accessory families can be added
    // under an availability check (their WidgetFamily cases are iOS 16+).
    private var families: [WidgetFamily] {
        return [.systemSmall]
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlashlightProvider()) { entry in
            FlashlightView(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("Flashlight")
        .description("This is an auto-generated home widget.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }
}
