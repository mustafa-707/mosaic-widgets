// MOSAIC-GENERATED — do not edit
import Flutter
import UIKit
import WidgetKit

/// Host-app side of the Mosaic bridge.
///
/// Register it once from your AppDelegate:
///
///     MosaicPlugin.register(with: self)
///
/// That is the whole integration — the channel, App Group writes, widget
/// reloads, Live Activity lifecycle, deep links and pending-callback draining
/// are all handled here.
public class MosaicPlugin: NSObject, FlutterPlugin {
    /// The App Group from mosaic.yaml. Used when Dart has not called
    /// `MosaicBridge.setAppGroupId(...)`, so that call is optional.
    public static let appGroup = "group.com.example.demo_app.widgets"

    private static let pendingCallbackKey = "mosaic_pending_callback"

    private var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "mosaic_bridge", binaryMessenger: registrar.messenger())
        let instance = MosaicPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        // Publish battery from the app process and keep it current: the widget
        // extension cannot enable monitoring, so this is the only place the
        // value can come from.
        instance.startBatteryPublishing()
        // Forward per-activity APNs push tokens (Live Activities started with
        // push: true) to Dart, where they surface on
        // MosaicLiveActivities.onPushToken.
        if #available(iOS 16.1, *) {
            MosaicActivityController.onPushToken = { [weak channel] id, token in
                channel?.invokeMethod(
                    "liveActivityPushToken", arguments: ["id": id, "token": token])
            }
        }
    }
    /// Enables battery monitoring and mirrors it into the App Group.
    ///
    /// Runs in the app because an extension cannot turn monitoring on. The
    /// first read right after enabling is often still -1 — the value is
    /// populated asynchronously — so this also observes the change
    /// notifications rather than sampling once and giving up.
    private func startBatteryPublishing() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        publishBattery()
        for name in [UIDevice.batteryLevelDidChangeNotification,
                     UIDevice.batteryStateDidChangeNotification] {
            NotificationCenter.default.addObserver(
                self, selector: #selector(batteryChanged),
                name: name, object: nil)
        }
        // Re-read when the app comes forward; the level moves while it is away.
        NotificationCenter.default.addObserver(
            self, selector: #selector(batteryChanged),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func batteryChanged() { publishBattery() }

    private func publishBattery() {
        guard let defaults = UserDefaults(suiteName: MosaicPlugin.appGroup) else { return }
        let level = UIDevice.current.batteryLevel
        // A negative level means "not known yet". Writing it would replace a
        // good value with a placeholder every time monitoring is restarted.
        guard level >= 0 else { return }
        defaults.set(String(Int((level * 100).rounded())),
                     forKey: "mosaic_battery_level")
        let state = UIDevice.current.batteryState
        defaults.set(state == .charging || state == .full,
                     forKey: "mosaic_battery_charging")
        // Matches the rest of the plugin: WidgetCenter is iOS 14+, and the
        // Runner's deployment target can be lower.
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }


    /// Convenience for `FlutterAppDelegate`, which is a `FlutterPluginRegistry`.
    public static func register(with registry: FlutterPluginRegistry) {
        guard let registrar = registry.registrar(forPlugin: "MosaicPlugin") else {
            NSLog("[Mosaic] could not obtain a plugin registrar; bridge inactive")
            return
        }
        register(with: registrar)
    }

    // MARK: - Method channel

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "saveString", "saveBool":
            guard let args = call.arguments as? [String: Any],
                  let key = args["key"] as? String,
                  let value = args["value"] else {
                result(Self.badArguments("key and value are required"))
                return
            }
            save(key: key, value: value, groupId: args["appGroupId"] as? String,
                 result: result)

        case "refresh":
            guard let args = call.arguments as? [String: Any],
                  let widgetName = args["widgetName"] as? String else {
                result(Self.badArguments("widgetName is required"))
                return
            }
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadTimelines(ofKind: widgetName)
            }
            result(nil)

        case "refreshAll":
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
            result(nil)

        case "widgetPushTokens":
            // WidgetKit hands each widget kind its own APNs token, and only the
            // extension sees it. It stores them in the App Group; this is how
            // the app collects them to register with a server.
            guard let defaults = UserDefaults(suiteName: Self.appGroup) else {
                result([String: String]())
                return
            }
            let prefix = "mosaic_widget_push_token_"
            var tokens: [String: String] = [:]
            for (key, value) in defaults.dictionaryRepresentation()
            where key.hasPrefix(prefix) {
                if let token = value as? String, !token.isEmpty {
                    tokens[String(key.dropFirst(prefix.count))] = token
                }
            }
            result(tokens)

        // iOS has no API to place a widget for the user — Apple routes that
        // through the widget gallery only. Answering false rather than
        // notImplemented lets Dart branch to manual instructions.
        case "canRequestPinWidget", "requestPinWidget":
            result(false)

        // MosaicActivityController is @MainActor (ActivityKit's Activity type is
        // not Sendable), so these hop to the main actor and answer from there.
        case "startActivity":
            if #available(iOS 16.1, *) {
                guard let args = call.arguments as? [String: Any],
                      let type = args["activityType"] as? String else {
                    result(Self.badArguments("activityType is required"))
                    return
                }
                Task { @MainActor in
                    result(MosaicActivityController.start(
                        type: type,
                        data: (args["state"] as? [String: String]) ?? [:],
                        push: (args["push"] as? Bool) ?? false))
                }
            } else {
                result(Self.unavailable())
            }

        case "updateActivity":
            if #available(iOS 16.1, *) {
                guard let args = call.arguments as? [String: Any],
                      let id = args["id"] as? String else {
                    result(Self.badArguments("id is required"))
                    return
                }
                let alert = args["alert"] as? [String: Any]
                Task { @MainActor in
                    MosaicActivityController.update(
                        id: id,
                        data: (args["state"] as? [String: String]) ?? [:],
                        alertTitle: alert?["title"] as? String,
                        alertBody: alert?["body"] as? String)
                    result(nil)
                }
            } else {
                result(Self.unavailable())
            }

        case "endActivity":
            if #available(iOS 16.1, *) {
                guard let args = call.arguments as? [String: Any],
                      let id = args["id"] as? String else {
                    result(Self.badArguments("id is required"))
                    return
                }
                Task { @MainActor in
                    MosaicActivityController.end(
                        id: id,
                        data: args["state"] as? [String: String],
                        policy: (args["policy"] as? String) ?? "afterDefault")
                    result(nil)
                }
            } else {
                result(Self.unavailable())
            }

        case "activitiesEnabled":
            if #available(iOS 16.1, *) {
                Task { @MainActor in result(MosaicActivityController.enabled()) }
            } else {
                result(false)
            }

        case "activeActivities":
            if #available(iOS 16.1, *) {
                Task { @MainActor in result(MosaicActivityController.active()) }
            } else {
                result([String]())
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func save(
        key: String, value: Any, groupId: String?, result: FlutterResult
    ) {
        let suiteName = groupId ?? Self.appGroup
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            result(FlutterError(
                code: "APP_GROUP_ERROR",
                message: "Could not access App Group \(suiteName). "
                    + "Check the App Groups capability on the Runner target.",
                details: nil))
            return
        }
        defaults.set(value, forKey: key)
        result(nil)
    }

    private static func badArguments(_ message: String) -> FlutterError {
        FlutterError(code: "INVALID_ARGUMENTS", message: message, details: nil)
    }

    private static func unavailable() -> FlutterError {
        FlutterError(
            code: "UNAVAILABLE",
            message: "Live Activities require iOS 16.1+ and a live_activities "
                + "entry in mosaic.yaml.",
            details: nil)
    }

    // MARK: - Pending callbacks

    /// Drains the callback the widget extension recorded when its AppIntent
    /// could not do the work itself, and dispatches it to Dart.
    private func drainPendingCallback() {
        guard let defaults = UserDefaults(suiteName: Self.appGroup) else { return }
        guard let payload = defaults.dictionary(forKey: Self.pendingCallbackKey),
              let callback = payload["callback"] as? String else { return }
        defaults.removeObject(forKey: Self.pendingCallbackKey)
        channel?.invokeMethod("backgroundCallback",
                              arguments: ["callbackName": callback])
    }

    // MARK: - UIApplicationDelegate

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any] = [:]
    ) -> Bool {
        drainPendingCallback()
        return true
    }

    public func applicationWillEnterForeground(_ application: UIApplication) {
        drainPendingCallback()
    }

    public func applicationDidBecomeActive(_ application: UIApplication) {
        drainPendingCallback()
    }

    public func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        channel?.invokeMethod("onDeepLink", arguments: ["url": url.absoluteString])
        return false
    }
}
