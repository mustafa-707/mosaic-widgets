// Shared Swift runtime: configuration intents, in-widget refresh, the widget
// bundle, and the core helpers every generated view uses.
part of '../ios.dart';

extension IosRuntimeEmitters on IosGenerator {
  Future<void> generateIntents(String projectRoot) async {
    final iosDir = Directory(p.join(projectRoot, 'ios', 'HomeWidgetExtension'));
    if (!iosDir.existsSync()) iosDir.createSync(recursive: true);

    final file = File(p.join(iosDir.path, 'MosaicIntents.swift'));
    await file.writeAsString('''$kGeneratedSentinel
import AppIntents
import WidgetKit
import Foundation

// iOS 17+ interactive widgets dispatch these AppIntents from Button(intent:).
// They run inside the widget extension process — they CANNOT call the Flutter
// engine. The callback intent therefore records the request into the App Group
// (`mosaic_pending_callback`); the host app must read & clear that key on
// resume to fire the Dart backgroundCallback. See generateIntents() docs.

/// Reloads all widget timelines. Used by MRefreshAction buttons on iOS 17+.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MosaicRefreshIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Widget"
    static let isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        // Fetch here as well as in the timeline provider — see
        // MosaicCallbackIntent for why both paths run.
        await MosaicRefreshSources.run("refresh_all")

        if let defaults = UserDefaults(suiteName: "${config.app.iosAppGroup}") {
            let payload: [String: Any] = [
                "callback": "refresh_all",
                "timestamp": Date().timeIntervalSince1970,
            ]
            defaults.set(payload, forKey: "mosaic_pending_callback")
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Flips a boolean in the App Group and redraws. Used by MToggleAction buttons
/// on iOS 17+. Runs entirely in the extension — no app launch, no network — so
/// in-widget state like a unit switch responds immediately.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MosaicToggleIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Value"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Key")
    var key: String

    init() {}

    init(key: String) {
        self.key = key
    }

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: kMosaicAppGroup) {
            defaults.set(!defaults.bool(forKey: key), forKey: key)
            defaults.synchronize()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Records a pending Mosaic callback into the App Group so the host app can
/// pick it up on next foreground, then reloads timelines. Used by
/// MActionCallback buttons on iOS 17+.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MosaicCallbackIntent: AppIntent {
    static let title: LocalizedStringResource = "Mosaic Callback"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Callback Name")
    var callbackName: String

    init() {}

    init(callbackName: String) {
        self.callbackName = callbackName
    }

    func perform() async throws -> some IntentResult {
        // Fetch here AND in the timeline provider, on purpose. Either path can
        // be the one that survives: an intent has a short execution window, and
        // a provider reload can be coalesced by the system. Both write the same
        // keys, so whichever lands first wins and the other is a no-op refresh.
        await MosaicRefreshSources.run(callbackName)

        // Still recorded so the host app can run any app-side work for this
        // callback next time it is foregrounded.
        if let defaults = UserDefaults(suiteName: kMosaicAppGroup) {
            let payload: [String: Any] = [
                "callback": callbackName,
                "timestamp": Date().timeIntervalSince1970,
            ]
            defaults.set(payload, forKey: "mosaic_pending_callback")
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
''');

    await _generateRefreshSources(iosDir);
  }

  /// Generates `MosaicRefreshSources.swift` — the network sources a refresh
  /// button fetches directly from the widget extension.
  ///
  /// Always emitted (with an empty table when nothing is declared) so the
  /// intents above compile unconditionally.
  Future<void> _generateRefreshSources(Directory iosDir) async {
    final entries = config.refresh.entries.map((e) {
      final sources = e.value.map((source) {
        final headers = source.headers.entries
            .map((h) => '"${swiftEscape(h.key)}": "${swiftEscape(h.value)}"')
            .join(', ');
        final map = source.map.entries
            .map((m) => '"${swiftEscape(m.key)}": "${swiftEscape(m.value)}"')
            .join(', ');
        return '''            MosaicRefreshSource(
                url: "${swiftEscape(source.url)}",
                method: "${swiftEscape(source.method)}",
                headers: [${headers.isEmpty ? ':' : headers}],
                map: [${map.isEmpty ? ':' : map}]
            ),''';
      }).join('\n');
      return '''        "${swiftEscape(e.key)}": [
$sources
        ],''';
    }).toList();

    final table = entries.isEmpty
        ? '    static let all: [String: [MosaicRefreshSource]] = [:]'
        : '''    static let all: [String: [MosaicRefreshSource]] = [
${entries.join('\n')}
    ]''';

    final file = File(p.join(iosDir.path, 'MosaicRefreshSources.swift'));
    await file.writeAsString('''$kGeneratedSentinel
import Foundation
import WidgetKit

/// A network source a refresh button fetches directly, declared under the
/// `refresh` key in mosaic.yaml.
struct MosaicRefreshSource {
    let url: String
    let method: String
    let headers: [String: String]
    /// App Group key → path into the JSON response.
    let map: [String: String]
}

/// Resolves a dotted path with optional `[n]` array indices (and an optional
/// leading `\$.`) against parsed JSON, e.g. `articles[0].title`.
func mosaicResolveJSONPath(_ root: Any, _ path: String) -> String? {
    var trimmed = path
    if trimmed.hasPrefix("\$.") { trimmed = String(trimmed.dropFirst(2)) }
    let normalized = trimmed
        .replacingOccurrences(of: "[", with: ".")
        .replacingOccurrences(of: "]", with: "")
    var current: Any? = root
    for segment in normalized.split(separator: ".") {
        let key = String(segment)
        if let index = Int(key) {
            guard let array = current as? [Any], index >= 0, index < array.count
            else { return nil }
            current = array[index]
        } else {
            guard let dict = current as? [String: Any] else { return nil }
            current = dict[key]
        }
    }
    switch current {
    case let string as String: return string
    case let number as NSNumber: return number.stringValue
    case .some(let value): return String(describing: value)
    case .none: return nil
    }
}

/// Fetches declared refresh sources from inside the widget extension.
///
/// AppIntents cannot run the Flutter engine, so without a declared source the
/// extension has no way to obtain new data and [run] reports false, letting the
/// caller fall back to handing the request to the host app.
enum MosaicRefreshSources {
$table

    /// Fetches every source declared for [callback] and stores each mapped
    /// value in the App Group. Returns true when at least one value was
    /// written, so one failing endpoint does not discard the others.
    ///
    /// Discardable: the intents call this for its side effect and reload the
    /// timeline regardless, and an unused-result warning in generated code is
    /// one a developer cannot edit away.
    @discardableResult
    static func run(_ callback: String) async -> Bool {
        guard let sources = all[callback], !sources.isEmpty else { return false }
        var wroteAny = false
        var failure: String?
        for source in sources {
            switch await fetch(source) {
            case .wrote: wroteAny = true
            case .empty: if failure == nil { failure = "no data" }
            case .failed(let reason): failure = reason
            }
        }
        recordStatus(wroteAny ? "ok" : (failure ?? "no data"))
        return wroteAny
    }

    /// Why a single source did or did not store anything.
    private enum FetchOutcome {
        case wrote
        case empty
        case failed(String)
    }

    /// A dedicated ephemeral session rather than `URLSession.shared`.
    ///
    /// `shared` is backed by the app's URL cache and cookie storage, which an
    /// extension sandbox may not be able to reach — and a cache hit would return
    /// identical bytes, which looks exactly like a button that does nothing. The
    /// short timeout keeps a stalled request from outliving the extension's
    /// execution window.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    /// Fetches every source that supplies any of [keys], regardless of which
    /// callback declared it. Timeline providers call this with the keys their
    /// widget binds, so a widget refreshes whatever data it actually shows.
    ///
    /// Sources are de-duplicated by URL, so a key listed under several callbacks
    /// is still fetched once.
    @discardableResult
    static func run(keys: [String]) async -> Bool {
        let wanted = Set(keys)
        var seenURLs = Set<String>()
        var pending: [MosaicRefreshSource] = []
        for (_, sources) in all {
            for source in sources
            where !Set(source.map.keys).isDisjoint(with: wanted) {
                if seenURLs.insert(source.url).inserted { pending.append(source) }
            }
        }
        guard !pending.isEmpty else { return false }

        var wroteAny = false
        var failure: String?
        for source in pending {
            switch await fetch(source) {
            case .wrote: wroteAny = true
            case .empty: if failure == nil { failure = "no data" }
            case .failed(let reason): failure = reason
            }
        }
        // Always stamped, so an identical payload still proves the refresh ran.
        recordStatus(wroteAny ? "ok" : (failure ?? "no data"))
        return wroteAny
    }

    /// Records the outcome of the last refresh under `mosaic_refresh_status`.
    ///
    /// Bind that key in a widget while diagnosing: a refresh that fetches
    /// unchanged data is otherwise indistinguishable from one that never ran.
    private static func recordStatus(_ text: String) {
        guard let defaults = UserDefaults(suiteName: kMosaicAppGroup) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        defaults.set("\\(formatter.string(from: Date())) \\(text)",
                     forKey: "mosaic_refresh_status")
        defaults.synchronize()
    }

    private static func fetch(
        _ source: MosaicRefreshSource
    ) async -> FetchOutcome {
        guard let url = URL(string: source.url),
              let defaults = UserDefaults(suiteName: kMosaicAppGroup)
        else { return .failed("bad url") }

        var request = URLRequest(url: url)
        request.httpMethod = source.method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        for (field, value) in source.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                NSLog("[Mosaic] refresh failed: HTTP \\(http.statusCode) \\(source.url)")
                return .failed("http \\(http.statusCode)")
            }
            let json = try JSONSerialization.jsonObject(with: data)
            var wrote = false
            for (key, path) in source.map {
                if let value = mosaicResolveJSONPath(json, path) {
                    defaults.set(value, forKey: key)
                    wrote = true
                } else {
                    NSLog("[Mosaic] refresh: no value at path \\(path)")
                }
            }
            // Flush to disk. The provider reads through a different
            // UserDefaults instance, which otherwise can serve a snapshot taken
            // before these writes — the fetch succeeds but the widget still
            // renders the old values.
            if wrote { defaults.synchronize() }
            return wrote ? .wrote : .empty
        } catch {
            NSLog("[Mosaic] refresh failed: \\(error) \\(source.url)")
            return .failed("offline")
        }
    }
}
''');
  }

  String _generateWidgetBundle() {
    // Configurable widgets (params.isNotEmpty) are iOS-17 AppIntentConfiguration
    // widgets, so their struct is @available(iOS 17.0, macOS 14.0, watchOS 10.0, *) and must be registered
    // under an `if #available(iOS 17.0, macOS 14.0, watchOS 10.0, *)` gate. Non-configurable widgets stay
    // available on iOS 16 and register unconditionally.
    final lines = <String>[
      ...definitions.map((def) => def.params.isNotEmpty
          ? '''        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, *) {
            ${def.name}Widget()
        }'''
          : '        ${def.name}Widget()'),
    ];

    // Live Activities are iOS 16.1+ Widgets; register each under an
    // availability gate so the bundle still builds when targeting older iOS.
    // `@WidgetBundleBuilder` supports `if #available` blocks.
    for (final la in liveActivities) {
      final name = la['name'] as String;
      // Matches the struct's own availability: an activity that opted into
      // watch presentation is an iOS 18 type, and referencing it from an
      // iOS 16.1 gate would not compile.
      final min = liveActivityWantsWatch(name) ? '18.0' : '16.1';
      // Also fenced on os(iOS): the struct itself is, since ActivityKit has no
      // macOS counterpart, so a bare reference would not resolve there.
      lines.add('''        #if os(iOS)
        if #available(iOS $min, *) {
            ${name}LiveActivity()
        }
        #endif''');
    }

    // iOS 18 Control Widgets are WidgetBundle members; register each under an
    // `if #available(iOS 18.0, *)` gate so the bundle still builds on older iOS.
    for (final c in controls) {
      final name = c['name'] as String;
      lines.add('''        #if os(iOS)
        if #available(iOS 18.0, *) {
            ${name}Control()
        }
        #endif''');
    }

    return '''$kGeneratedSentinel
import SwiftUI
import WidgetKit

@main
struct HomeWidgetBundle: WidgetBundle {
    var body: some Widget {
${lines.join('\n')}
    }
}
''';
  }

  Future<void> generateCore(String projectRoot) async {
    final iosDir = Directory(p.join(projectRoot, 'ios', 'HomeWidgetExtension'));
    if (!iosDir.existsSync()) iosDir.createSync(recursive: true);

    // Only collect the metrics some widget references: battery monitoring has
    // to be switched on, and volume capacity hits the filesystem, so gathering
    // unused values costs on every render.
    final metrics = <MosaicDeviceMetric>{};
    for (final def in definitions) {
      metrics.addAll(deviceMetricsIn(def.root.toJson()));
    }
    final needsBattery = metrics.contains(MosaicDeviceMetric.batteryLevel) ||
        metrics.contains(MosaicDeviceMetric.batteryCharging);
    final needsStorage = metrics.contains(MosaicDeviceMetric.storageFreeGb) ||
        metrics.contains(MosaicDeviceMetric.storageUsedPercent);
    final needsMemory = metrics.contains(MosaicDeviceMetric.memoryFreeMb) ||
        metrics.contains(MosaicDeviceMetric.memoryTotalMb) ||
        metrics.contains(MosaicDeviceMetric.memoryUsedPercent);

    final deviceParts = <String>[];
    if (needsBattery) {
      deviceParts.add('''
        // An extension cannot turn battery monitoring on — `isBatteryMonitoring`
        // is a no-op here, so `batteryLevel` stays -1 even on a real device.
        // The app publishes the real value into this same App Group (see
        // MosaicPlugin.startBatteryPublishing); this only fills in on the
        // chance the extension does have it, and never overwrites a good value
        // with the -1 placeholder.
        //
        // UIDevice is iOS/watchOS only. On macOS the value comes from the host
        // app the same way it does on iOS, so the widget simply reads whatever
        // is in the App Group.
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        if level >= 0 {
            defaults.set(String(Int((level * 100).rounded())),
                         forKey: "${MosaicDeviceMetric.batteryLevel.key}")
            let state = UIDevice.current.batteryState
            defaults.set(state == .charging || state == .full,
                         forKey: "${MosaicDeviceMetric.batteryCharging.key}")
        }
        #endif''');
    }
    if (needsStorage) {
      deviceParts.add('''
        if let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityKey,
                                      .volumeTotalCapacityKey]),
           let free = values.volumeAvailableCapacity,
           let total = values.volumeTotalCapacity, total > 0 {
            defaults.set(String(format: "%.1f", Double(free) / 1_000_000_000.0),
                         forKey: "${MosaicDeviceMetric.storageFreeGb.key}")
            let usedPercent = Double(total - free) * 100.0 / Double(total)
            defaults.set(String(format: "%.0f", usedPercent),
                         forKey: "${MosaicDeviceMetric.storageUsedPercent.key}")
        }''');
    }
    if (needsMemory) {
      // A first pass wrote only per-process headroom (os_proc_available_memory)
      // and skipped total/used entirely, on the belief that a sandboxed app
      // cannot see device RAM. It can: `physicalMemory` is public Foundation,
      // and `host_statistics64` is Mach, not private API. The widget rendered
      // "0 MB free / 0 MB total" until this read them properly.
      deviceParts.add('''
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        defaults.set(String(totalBytes / 1_048_576),
                     forKey: "${MosaicDeviceMetric.memoryTotalMb.key}")

        // Free pages as the OS counts them. `inactive` is reclaimable on
        // demand, so counting it as free matches what a memory panel reports —
        // free_count alone reads far lower than any figure a user recognises.
        var vmStats = vm_statistics64_data_t()
        var vmCount = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let vmResult = withUnsafeMutablePointer(to: &vmStats) {
            \$0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, \$0, &vmCount)
            }
        }
        if vmResult == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let freeBytes =
                (UInt64(vmStats.free_count) + UInt64(vmStats.inactive_count)) * pageSize
            defaults.set(String(freeBytes / 1_048_576),
                         forKey: "${MosaicDeviceMetric.memoryFreeMb.key}")
            if totalBytes > 0 {
                let usedPercent =
                    Double(totalBytes - min(freeBytes, totalBytes)) * 100.0 / Double(totalBytes)
                defaults.set(String(format: "%.0f", usedPercent),
                             forKey: "${MosaicDeviceMetric.memoryUsedPercent.key}")
            }
        } else {
            // Mach call refused: fall back to this process's own headroom, which
            // is a gauge rather than the device figure, but beats showing zero.
            // os_proc_available_memory is iOS-only, so macOS simply reports
            // nothing here rather than a number it cannot obtain.
            #if os(iOS)
            if #available(iOS 13.0, *) {
                defaults.set(String(os_proc_available_memory() / 1_048_576),
                             forKey: "${MosaicDeviceMetric.memoryFreeMb.key}")
            }
            #endif
        }''');
    }
    final deviceBody = deviceParts.isEmpty
        ? '        // No widget references a device metric.'
        : deviceParts.join('\n');

    final coreFile = File(p.join(iosDir.path, 'HomeWidgetCore.swift'));
    await coreFile.writeAsString('''$kGeneratedSentinel
import SwiftUI
import WidgetKit

// WidgetKit is shared across iOS, macOS and watchOS, but the image and device
// types are not: UIKit does not exist on the Mac. Aliasing here keeps every
// generated view free of platform conditionals.
#if canImport(UIKit)
import UIKit
typealias MosaicImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias MosaicImage = NSImage
#endif

extension Image {
    /// Builds an `Image` from whichever native image type this platform has.
    init(mosaic image: MosaicImage) {
        #if canImport(UIKit)
        self.init(uiImage: image)
        #else
        self.init(nsImage: image)
        #endif
    }
}

/// Whether [family] should render a definition's `compactRoot` instead of its
/// main tree.
///
/// systemSmall everywhere, plus the circular and inline lock-screen accessories
/// where they exist — those cases are absent on macOS, so the check is fenced
/// rather than written inline in each view body.
func mosaicPrefersCompact(_ family: WidgetFamily) -> Bool {
    #if os(iOS) || os(watchOS)
    if #available(iOS 16.0, watchOS 9.0, *) {
        if family == .accessoryCircular || family == .accessoryInline { return true }
    }
    #endif
    #if os(watchOS)
    // Every watch family is an accessory, so the compact tree always wins.
    return true
    #else
    return family == .systemSmall
    #endif
}

let kMosaicAppGroup = "${config.app.iosAppGroup}"

/// Resolves a file-image path to a native image. Absolute paths are loaded directly;
/// relative paths are resolved against the App Group container. Returns nil when
/// the path is nil/empty or no image could be loaded.
func resolveFileImage(_ path: String?) -> MosaicImage? {
    guard let path = path, !path.isEmpty else { return nil }
    if path.hasPrefix("/") {
        return MosaicImage(contentsOfFile: path)
    }
    if let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: kMosaicAppGroup) {
        let full = container.appendingPathComponent(path).path
        if let img = MosaicImage(contentsOfFile: full) { return img }
    }
    return MosaicImage(contentsOfFile: path)
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
$deviceBody
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

    static func cached(_ url: String?) -> MosaicImage? {
        guard let url = url, !url.isEmpty, let file = fileURL(for: url) else {
            return nil
        }
        return MosaicImage(contentsOfFile: file.path)
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
                NSLog("[Mosaic] image download failed: \\(url)")
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
        return array.compactMap { mosaicNum(\$0) }
    }
    if let text = value as? String,
       let data = text.data(using: .utf8),
       let decoded = try? JSONSerialization.jsonObject(with: data) as? [Any] {
        return decoded.compactMap { mosaicNum(\$0) }
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
        #if os(iOS) || os(tvOS)
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif os(watchOS)
        // watchOS has no trait-based resolution and is always dark, so the dark
        // value is simply the right one rather than a fallback.
        self = dark
        #else
        // AppKit resolves appearance through NSColor rather than a trait
        // closure; asking the current appearance which of the two names it
        // matches gives the same result without a UIKit type.
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
        #endif
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
        if #available(iOS 18.0, macOS 15.0, watchOS 11.0, *) {
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
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }

    /// iOS 16/17-compatible container background helper.
    /// On iOS 17+ uses .containerBackground(for: .widget); on iOS 16 falls back
    /// to .background(_:) so the widget extension compiles at both targets.
    @ViewBuilder func mosaicContainerBackground<S: ShapeStyle>(_ style: S) -> some View {
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, *) {
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
''');
  }

  /// True when [def] opted into WidgetKit push updates in mosaic.yaml.
  bool _pushEnabled(IRDefinition def) =>
      config.widgets.any((w) => w.name == def.name && w.push);

  /// The widget's `body`, with `.pushHandler(...)` attached when push updates
  /// are enabled.
  ///
  /// `pushHandler` is iOS 26+, so it is applied inside an availability check.
  /// Returning from both branches of `if #available` in a `some
  /// WidgetConfiguration` body compiles — verified against the iOS 26.2 SDK —
  /// so the widget still works on iOS 16 without the handler.
}
