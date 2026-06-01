import Flutter
import UIKit
import WidgetKit
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var mosaicChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "mosaic_bridge",
                                              binaryMessenger: controller.binaryMessenger)
    mosaicChannel = channel

    channel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      
      // Helper to extract App Group ID
      func getGroupId(_ args: [String: Any]) -> String? {
          return args["appGroupId"] as? String
      }

      if call.method == "saveString" {
        guard let args = call.arguments as? [String: Any],
              let key = args["key"] as? String,
              let value = args["value"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Key or value is null", details: nil))
          return
        }
        let groupId = getGroupId(args)
        self.saveToUserDefaults(key: key, value: value, groupId: groupId, result: result)
        
      } else if call.method == "saveBool" { // ADDED SUPPORT
        guard let args = call.arguments as? [String: Any],
              let key = args["key"] as? String,
              let value = args["value"] as? Bool else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Key or value is null", details: nil))
          return
        }
        let groupId = getGroupId(args)
        self.saveToUserDefaults(key: key, value: value, groupId: groupId, result: result)

      } else if call.method == "refresh" {
        guard let args = call.arguments as? [String: Any],
              let widgetName = args["widgetName"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "widgetName is required", details: nil))
          return
        }
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadTimelines(ofKind: widgetName)
        }
        result(nil)

      } else if call.method == "refreshAll" {
        self.refreshAllWidgets()
        result(nil)

      } else if call.method == "startActivity" {
        // Live Activity lifecycle is iOS 16.1+. MosaicActivityController is
        // generated into the widget extension target (gated @available(iOS 16.1)).
        if #available(iOS 16.1, *) {
          guard let args = call.arguments as? [String: Any],
                let type = args["type"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "type is required", details: nil))
            return
          }
          let data = (args["data"] as? [String: String]) ?? [:]
          result(MosaicActivityController.start(type: type, data: data))
        } else {
          result(FlutterError(code: "UNAVAILABLE", message: "Live Activities require iOS 16.1+", details: nil))
        }

      } else if call.method == "updateActivity" {
        if #available(iOS 16.1, *) {
          guard let args = call.arguments as? [String: Any],
                let id = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "id is required", details: nil))
            return
          }
          let data = (args["data"] as? [String: String]) ?? [:]
          MosaicActivityController.update(
            id: id,
            data: data,
            alertTitle: args["alertTitle"] as? String,
            alertBody: args["alertBody"] as? String
          )
          result(nil)
        } else {
          result(FlutterError(code: "UNAVAILABLE", message: "Live Activities require iOS 16.1+", details: nil))
        }

      } else if call.method == "endActivity" {
        if #available(iOS 16.1, *) {
          guard let args = call.arguments as? [String: Any],
                let id = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "id is required", details: nil))
            return
          }
          MosaicActivityController.end(
            id: id,
            data: args["data"] as? [String: String],
            policy: (args["policy"] as? String) ?? "default"
          )
          result(nil)
        } else {
          result(FlutterError(code: "UNAVAILABLE", message: "Live Activities require iOS 16.1+", details: nil))
        }

      } else if call.method == "activitiesEnabled" {
        if #available(iOS 16.1, *) {
          result(MosaicActivityController.enabled())
        } else {
          result(false)
        }

      } else if call.method == "activeActivities" {
        if #available(iOS 16.1, *) {
          result(MosaicActivityController.active())
        } else {
          result([String]())
        }

      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Unified Save Method
  private func saveToUserDefaults(key: String, value: Any, groupId: String?, result: FlutterResult) {
    guard let suiteName = groupId else {
        // Fallback or Error? If no group ID set in Flutter, we can't save to shared.
        // But maybe user didn't call setAppGroupId yet.
        // We return error to encourage correct usage.
        result(FlutterError(code: "NO_APP_GROUP_ID", message: "Call MosaicBridge.setAppGroupId() in Flutter first.", details: nil))
        return
    }

    if let defaults = UserDefaults(suiteName: suiteName) {
        defaults.set(value, forKey: key)
        defaults.synchronize()
        result(nil)
    } else {
         NSLog("Error: Could not access UserDefaults suite: \(suiteName)")
         result(FlutterError(code: "APP_GROUP_ERROR", message: "Could not access App Group: \(suiteName). Check Xcode Capabilities.", details: nil))
    }
  }

  private func refreshAllWidgets() {
    if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadAllTimelines()
    }
  }

  override func application(_ app: UIApplication, open url: URL,
      options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    mosaicChannel?.invokeMethod("onDeepLink", arguments: ["url": url.absoluteString])
    return super.application(app, open: url, options: options)
  }
}
