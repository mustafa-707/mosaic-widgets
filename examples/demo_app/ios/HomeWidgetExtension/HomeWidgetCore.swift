// MOSAIC-GENERATED — do not edit
import SwiftUI
import UIKit
import WidgetKit

let kMosaicAppGroup = "group.com.example.demo_app.widgets"

/// Resolves a file-image path to a UIImage. Absolute paths are loaded directly;
/// relative paths are resolved against the App Group container. Returns nil when
/// the path is nil/empty or no image could be loaded.
func resolveFileImage(_ path: String?) -> UIImage? {
    guard let path = path, !path.isEmpty else { return nil }
    if path.hasPrefix("/") {
        return UIImage(contentsOfFile: path)
    }
    if let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: kMosaicAppGroup) {
        let full = container.appendingPathComponent(path).path
        if let img = UIImage(contentsOfFile: full) { return img }
    }
    return UIImage(contentsOfFile: path)
}

/// Device metrics read inside the widget extension, so they are correct even
/// when the app has not run for days.
///
/// Values are written into the App Group before a render, so they resolve
/// through the same binding path as everything else and no view code needs to
/// know they came from the device.
enum MosaicDevice {
    static func populate() {
        guard let defaults = UserDefaults(suiteName: kMosaicAppGroup) else { return }
        // An extension cannot turn battery monitoring on — `isBatteryMonitoring`
        // is a no-op here, so `batteryLevel` stays -1 even on a real device.
        // The app publishes the real value into this same App Group (see
        // MosaicPlugin.startBatteryPublishing); this only fills in on the
        // chance the extension does have it, and never overwrites a good value
        // with the -1 placeholder.
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        if level >= 0 {
            defaults.set(String(Int((level * 100).rounded())),
                         forKey: "mosaic_battery_level")
            let state = UIDevice.current.batteryState
            defaults.set(state == .charging || state == .full,
                         forKey: "mosaic_battery_charging")
        }
        if let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityKey,
                                      .volumeTotalCapacityKey]),
           let free = values.volumeAvailableCapacity,
           let total = values.volumeTotalCapacity, total > 0 {
            defaults.set(String(format: "%.1f", Double(free) / 1_000_000_000.0),
                         forKey: "mosaic_storage_free_gb")
            let usedPercent = Double(total - free) * 100.0 / Double(total)
            defaults.set(String(format: "%.0f", usedPercent),
                         forKey: "mosaic_storage_used_percent")
        }
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        defaults.set(String(totalBytes / 1_048_576),
                     forKey: "mosaic_memory_total_mb")

        // Free pages as the OS counts them. `inactive` is reclaimable on
        // demand, so counting it as free matches what a memory panel reports —
        // free_count alone reads far lower than any figure a user recognises.
        var vmStats = vm_statistics64_data_t()
        var vmCount = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let vmResult = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
            }
        }
        if vmResult == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let freeBytes =
                (UInt64(vmStats.free_count) + UInt64(vmStats.inactive_count)) * pageSize
            defaults.set(String(freeBytes / 1_048_576),
                         forKey: "mosaic_memory_free_mb")
            if totalBytes > 0 {
                let usedPercent =
                    Double(totalBytes - min(freeBytes, totalBytes)) * 100.0 / Double(totalBytes)
                defaults.set(String(format: "%.0f", usedPercent),
                             forKey: "mosaic_memory_used_percent")
            }
        } else if #available(iOS 13.0, *) {
            // Mach call refused: fall back to this process's own headroom, which
            // is a gauge rather than the device figure, but beats showing zero.
            defaults.set(String(os_proc_available_memory() / 1_048_576),
                         forKey: "mosaic_memory_free_mb")
        }
        defaults.synchronize()
    }
}

/// Disk cache for `MNetworkImage`.
///
/// Downloads land in the App Group container keyed by a hash of the URL, so a
/// render reads a local file and the image survives redraws and offline
/// launches. Fetching happens in the timeline provider — see mosaicPrefetch —
/// because a render pass cannot wait on the network.
enum MosaicImageCache {
    static func fileURL(for url: String) -> URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: kMosaicAppGroup)
        else { return nil }
        let dir = container.appendingPathComponent("mosaic_images", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        // Hash rather than the raw URL: query strings are not path-safe.
        return dir.appendingPathComponent(String(abs(url.hashValue)) + ".img")
    }

    static func cached(_ url: String?) -> UIImage? {
        guard let url = url, !url.isEmpty, let file = fileURL(for: url) else {
            return nil
        }
        return UIImage(contentsOfFile: file.path)
    }

    /// Downloads any of [urls] not already cached. Safe to call on every
    /// timeline pass — a cached URL costs nothing.
    static func prefetch(_ urls: [String]) async {
        for url in urls where !url.isEmpty {
            guard let file = fileURL(for: url),
                  !FileManager.default.fileExists(atPath: file.path),
                  let remote = URL(string: url)
            else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: remote)
                try data.write(to: file)
            } catch {
                NSLog("[Mosaic] image download failed: \(url)")
            }
        }
    }
}

/// Bound-value coercion helpers.
///
/// Timeline entries carry `[String: Any]` (JSON-decoded, numbers arrive as
/// NSNumber) while Live Activity content state carries `[String: String]`
/// (ActivityKit requires Codable). These helpers accept either, so the same
/// emitted expression is correct in both contexts.
/// Coerces a stored value into a numeric series for charting.
///
/// The store round-trips through JSON, so a list saved from Dart can arrive as
/// numbers, as numeric strings, or as a JSON string that was never decoded.
func mosaicNumList(_ value: Any?) -> [Double] {
    if let array = value as? [Any] {
        return array.compactMap { mosaicNum($0) }
    }
    if let text = value as? String,
       let data = text.data(using: .utf8),
       let decoded = try? JSONSerialization.jsonObject(with: data) as? [Any] {
        return decoded.compactMap { mosaicNum($0) }
    }
    return []
}

/// A stored list of row maps, however it was written.
///
/// `MosaicBridge.saveList` JSON-encodes to a String, because Android's store
/// keeps everything as strings. `mosaicNumList` already handled that for
/// charts; MListView cast straight to `[[String: Any]]` and so silently
/// rendered an empty list from every list the app ever saved.
func mosaicRowList(_ value: Any?) -> [[String: Any]] {
    if let rows = value as? [[String: Any]] { return rows }
    if let text = value as? String,
       let data = text.data(using: .utf8),
       let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        return decoded
    }
    return []
}

func mosaicNum(_ value: Any?) -> Double? {
    if let n = value as? NSNumber { return n.doubleValue }
    if let s = value as? String { return Double(s) }
    return nil
}

func mosaicBool(_ value: Any?) -> Bool {
    if let n = value as? NSNumber { return n.boolValue }
    if let s = value as? String {
        switch s.lowercased() {
        case "true", "1", "yes": return true
        default: return false
        }
    }
    return false
}

func mosaicStr(_ value: Any?) -> String? {
    if let s = value as? String { return s }
    guard let value = value else { return nil }
    return String(describing: value)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Builds a color that resolves at render time to [light] or [dark] based on
    /// the current interface style. Used for adaptive (dark-mode) MColors.
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

extension Image {
    /// Chooses how this image renders when the user tints their widgets.
    ///
    /// `widgetAccentedRenderingMode` is iOS 18+, so older systems fall through
    /// unchanged. It is declared on Image but returns `some View`, so it must sit
    /// after `.resizable()` (Image → Image) and before any View modifiers —
    /// see iosImageFitParts.
    @ViewBuilder func mosaicAccentedRendering(_ mode: String) -> some View {
        if #available(iOS 18.0, *) {
            switch mode {
            case "accented":
                self.widgetAccentedRenderingMode(.accented)
            case "accentedDesaturated":
                self.widgetAccentedRenderingMode(.accentedDesaturated)
            case "desaturated":
                self.widgetAccentedRenderingMode(.desaturated)
            case "fullColor":
                self.widgetAccentedRenderingMode(.fullColor)
            default:
                self
            }
        } else {
            self
        }
    }
}

extension View {
    /// Rolls digits when a value changes. `contentTransition` is iOS 17+, so
    /// older systems fall through to a plain swap.
    @ViewBuilder func mosaicNumericTransition() -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }

    /// iOS 16/17-compatible container background helper.
    /// On iOS 17+ uses .containerBackground(for: .widget); on iOS 16 falls back
    /// to .background(_:) so the widget extension compiles at both targets.
    @ViewBuilder func mosaicContainerBackground<S: ShapeStyle>(_ style: S) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(style, for: .widget)
        } else {
            self.background(style)
        }
    }

    /// Per-corner rounded clip. UnevenRoundedRectangle is iOS 16.4+, so on
    /// older systems this falls back to a uniform RoundedRectangle using the
    /// largest of the four corner radii. Keeps the extension type-checking at
    /// the 16.1 deployment target.
    @ViewBuilder func mosaicCornerClip(
        topLeft: CGFloat,
        topRight: CGFloat,
        bottomLeft: CGFloat,
        bottomRight: CGFloat
    ) -> some View {
        if #available(iOS 16.4, *) {
            self.clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: topLeft,
                    bottomLeadingRadius: bottomLeft,
                    bottomTrailingRadius: bottomRight,
                    topTrailingRadius: topRight
                )
            )
        } else {
            let maxRadius = max(max(topLeft, topRight), max(bottomLeft, bottomRight))
            self.clipShape(RoundedRectangle(cornerRadius: maxRadius))
        }
    }
}
