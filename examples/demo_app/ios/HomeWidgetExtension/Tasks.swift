// MOSAIC-GENERATED — do not edit
import SwiftUI
import WidgetKit
import AppIntents

struct TasksEntry: TimelineEntry {
    let date: Date
    let data: [String: Any]
}

struct TasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        TasksEntry(date: Date(), data: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> ()) {
        let entry = TasksEntry(date: Date(), data: loadData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Fetch, then complete. WidgetKit waits for `completion`, so the fresh
        // values render on this pass. Completing first and reloading afterwards
        // would depend on a second reload, which the system may throttle away.
        Task {
            await MosaicRefreshSources.run(keys: ["due", "global_url", "marker", "tasks", "tasks_count", "title"])
            // Network images: download after the refresh, so a URL that arrived
            // in this same pass is fetched immediately rather than one timeline
            // later. Cached URLs cost nothing.
            await MosaicImageCache.prefetch([])
            let entry = TasksEntry(date: Date(), data: loadData())

                        let nextUpdate = Calendar.current.date(byAdding: .second, value: 1800, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            

            completion(timeline)
        }
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "group.com.example.demo_app.widgets"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: TasksProvider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        // Refresh native device metrics first, so bindings read current values
        // rather than whatever the app last stored.
        MosaicDevice.populate()
        // Re-read from disk: the app and the refresh code write through other
        // UserDefaults instances, and without this the widget can render a
        // snapshot taken before those writes.
        defaults.synchronize()
        for k in ["due", "global_url", "marker", "tasks", "tasks_count", "title"] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

struct TasksView: View {
    var entry: TasksEntry
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
    HStack(alignment: .center, spacing: 0) {
    Text("TODAY").bold().foregroundColor(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
Spacer()
Text("\(mosaicStr(entry.data["tasks_count"]) ?? "--")").foregroundColor(Color(red: 0.39215686274509803, green: 0.4549019607843137, blue: 0.5450980392156862, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
}
Color.clear
    .frame(height: 8.0)
ForEach(Array(mosaicRowList(entry.data["tasks"]).enumerated()), id: \.offset) { _, item in
    HStack(alignment: .center, spacing: 0) {
    Text("\(mosaicStr(item["marker"]) ?? "--")").foregroundColor(Color(red: 0.2196078431372549, green: 0.7411764705882353, blue: 0.9725490196078431, opacity: 1.0)).font(.system(size: 13.0)).dynamicTypeSize(.large)
Color.clear
    .frame(width: 10.0)
Text("\(mosaicStr(item["title"]) ?? "--")").foregroundColor(Color(red: 0.8862745098039215, green: 0.9098039215686274, blue: 0.9411764705882353, opacity: 1.0)).font(.system(size: 13.0)).lineLimit(1).dynamicTypeSize(.large)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
Color.clear
    .frame(width: 8.0)
Text("\(mosaicStr(item["due"]) ?? "--")").bold().foregroundColor(Color(red: 0.5803921568627451, green: 0.6392156862745098, blue: 0.7215686274509804, opacity: 1.0)).font(.system(size: 10.0)).dynamicTypeSize(.large)
    .padding(EdgeInsets(top: 3.0, leading: 6.0, bottom: 3.0, trailing: 6.0))
    .background(Color(red: 0.058823529411764705, green: 0.09019607843137255, blue: 0.16470588235294117, opacity: 1.0))
    .clipShape(RoundedRectangle(cornerRadius: 6.0))
}
    .padding(EdgeInsets(top: 9.0, leading: 10.0, bottom: 9.0, trailing: 10.0))
    .background(Color(red: 0.11764705882352941, green: 0.1607843137254902, blue: 0.23137254901960785, opacity: 1.0))
    .clipShape(RoundedRectangle(cornerRadius: 10.0)).padding(EdgeInsets(top: 0.0, leading: 0.0, bottom: 6.0, trailing: 0.0))
}
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
    .padding(EdgeInsets(top: 14.0, leading: 14.0, bottom: 14.0, trailing: 14.0))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(light: Color(hex: "#0F172A"), dark: Color(hex: "#0B1120")))
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
// height=2 and previewImage are advisory on iOS and not used by
// WidgetKit, which sizes by family and renders the placeholder() view for
// previews. resizeMode=none only acts as a fallback for deriving
// supportedFamilies when mosaic.yaml lists no ios.families for this widget.
struct TasksWidget: Widget {
    let kind: String = "Tasks"

    // Built at runtime so iOS 16+ lock-screen accessory families can be added
    // under an availability check (their WidgetFamily cases are iOS 16+).
    private var families: [WidgetFamily] {
        return [.systemMedium, .systemLarge]
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksProvider()) { entry in
            TasksView(entry: entry)
                .mosaicContainerBackground(.clear)
                .widgetAccentable()
        }
        .configurationDisplayName("Tasks")
        .description("This is an auto-generated home widget.")
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }
}
