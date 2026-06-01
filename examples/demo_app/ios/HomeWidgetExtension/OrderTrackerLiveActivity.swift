// MOSAIC-GENERATED — do not edit
import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
struct OrderTrackerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: MosaicActivityAttributes.self) { context in
      VStack(alignment: .leading, spacing: 0) {
    Text("Order on the way").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 14.0)).dynamicTypeSize(.large)
Text("\(context.state.data["status"] as? String ?? String(describing: context.state.data["status"] ?? "--"))").foregroundColor(Color(red: 0.611764705882353, green: 0.6392156862745098, blue: 0.6862745098039216, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
ProgressView(value: ((context.state.data["progress"] as? NSNumber)?.doubleValue ?? Double("\(context.state.data["progress"] ?? "0")") ?? 0), total: 100.0).tint(Color(red: 0.20392156862745098, green: 0.8274509803921568, blue: 0.6, opacity: 1.0))
HStack(alignment: .center, spacing: 0) {
    Text("ETA ").foregroundColor(Color(red: 0.611764705882353, green: 0.6392156862745098, blue: 0.6862745098039216, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
Text("\(context.state.data["eta"] as? String ?? String(describing: context.state.data["eta"] ?? "--"))").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
}
}.padding(EdgeInsets(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0))
    .background(Color(light: Color(hex: "#111827"), dark: Color(hex: "#000000")))
    .clipShape(RoundedRectangle(cornerRadius: 16.0))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text("Order").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("\(context.state.data["eta"] as? String ?? String(describing: context.state.data["eta"] ?? "--"))").bold().foregroundColor(Color(red: 0.20392156862745098, green: 0.8274509803921568, blue: 0.6, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
        }
        DynamicIslandExpandedRegion(.center) {
          Text("\(context.state.data["status"] as? String ?? String(describing: context.state.data["status"] ?? "--"))").foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
        }
        DynamicIslandExpandedRegion(.bottom) {
          ProgressView(value: ((context.state.data["progress"] as? NSNumber)?.doubleValue ?? Double("\(context.state.data["progress"] ?? "0")") ?? 0), total: 100.0).tint(Color(red: 0.20392156862745098, green: 0.8274509803921568, blue: 0.6, opacity: 1.0))
        }
      } compactLeading: {
        Text("🛵").font(.system(size: 14.0)).dynamicTypeSize(.large)
      } compactTrailing: {
        Text("\(context.state.data["eta"] as? String ?? String(describing: context.state.data["eta"] ?? "--"))").bold().foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)).font(.system(size: 12.0)).dynamicTypeSize(.large)
      } minimal: {
        Text("🛵").font(.system(size: 12.0)).dynamicTypeSize(.large)
      }
    }
  }
}
