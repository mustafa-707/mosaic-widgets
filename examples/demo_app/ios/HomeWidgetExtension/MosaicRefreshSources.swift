// MOSAIC-GENERATED — do not edit
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
/// leading `$.`) against parsed JSON, e.g. `articles[0].title`.
func mosaicResolveJSONPath(_ root: Any, _ path: String) -> String? {
    var trimmed = path
    if trimmed.hasPrefix("$.") { trimmed = String(trimmed.dropFirst(2)) }
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
    static let all: [String: [MosaicRefreshSource]] = [
        "refresh_crypto": [
            MosaicRefreshSource(
                url: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true",
                method: "GET",
                headers: ["Accept": "application/json"],
                map: ["btc_price": "bitcoin.usd", "btc_change": "bitcoin.usd_24h_change"]
            ),
        ],
        "refresh_news": [
            MosaicRefreshSource(
                url: "https://api.spaceflightnewsapi.net/v4/articles/?limit=2",
                method: "GET",
                headers: ["Accept": "application/json"],
                map: ["news_title": "results[0].title", "news_image": "results[0].image_url", "news_title_2": "results[1].title", "news_source": "results[0].news_site"]
            ),
        ],
        "refresh_weather": [
            MosaicRefreshSource(
                url: "https://api.open-meteo.com/v1/forecast?latitude=37.77&longitude=-122.42&current=temperature_2m&daily=temperature_2m_max,temperature_2m_min&forecast_days=1",
                method: "GET",
                headers: [:],
                map: ["temp_c": "current.temperature_2m", "hi_c": "daily.temperature_2m_max[0]", "lo_c": "daily.temperature_2m_min[0]"]
            ),
            MosaicRefreshSource(
                url: "https://api.open-meteo.com/v1/forecast?latitude=37.77&longitude=-122.42&current=temperature_2m&daily=temperature_2m_max,temperature_2m_min&forecast_days=1&temperature_unit=fahrenheit",
                method: "GET",
                headers: [:],
                map: ["temp_f": "current.temperature_2m", "hi_f": "daily.temperature_2m_max[0]", "lo_f": "daily.temperature_2m_min[0]"]
            ),
        ],
        "refresh_all": [
            MosaicRefreshSource(
                url: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true",
                method: "GET",
                headers: [:],
                map: ["btc_price": "bitcoin.usd", "btc_change": "bitcoin.usd_24h_change"]
            ),
            MosaicRefreshSource(
                url: "https://api.spaceflightnewsapi.net/v4/articles/?limit=2",
                method: "GET",
                headers: [:],
                map: ["news_title": "results[0].title"]
            ),
            MosaicRefreshSource(
                url: "https://api.open-meteo.com/v1/forecast?latitude=37.77&longitude=-122.42&current=temperature_2m&daily=temperature_2m_max,temperature_2m_min&forecast_days=1",
                method: "GET",
                headers: [:],
                map: ["temp_c": "current.temperature_2m", "hi_c": "daily.temperature_2m_max[0]", "lo_c": "daily.temperature_2m_min[0]"]
            ),
            MosaicRefreshSource(
                url: "https://api.open-meteo.com/v1/forecast?latitude=37.77&longitude=-122.42&current=temperature_2m&daily=temperature_2m_max,temperature_2m_min&forecast_days=1&temperature_unit=fahrenheit",
                method: "GET",
                headers: [:],
                map: ["temp_f": "current.temperature_2m", "hi_f": "daily.temperature_2m_max[0]", "lo_f": "daily.temperature_2m_min[0]"]
            ),
        ],
    ]

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
        defaults.set("\(formatter.string(from: Date())) \(text)",
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
                NSLog("[Mosaic] refresh failed: HTTP \(http.statusCode) \(source.url)")
                return .failed("http \(http.statusCode)")
            }
            let json = try JSONSerialization.jsonObject(with: data)
            var wrote = false
            for (key, path) in source.map {
                if let value = mosaicResolveJSONPath(json, path) {
                    defaults.set(value, forKey: key)
                    wrote = true
                } else {
                    NSLog("[Mosaic] refresh: no value at path \(path)")
                }
            }
            // Flush to disk. The provider reads through a different
            // UserDefaults instance, which otherwise can serve a snapshot taken
            // before these writes — the fetch succeeds but the widget still
            // renders the old values.
            if wrote { defaults.synchronize() }
            return wrote ? .wrote : .empty
        } catch {
            NSLog("[Mosaic] refresh failed: \(error) \(source.url)")
            return .failed("offline")
        }
    }
}
