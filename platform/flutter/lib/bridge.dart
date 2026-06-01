import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

// ─── Live Activity types ───────────────────────────────────────────────────

/// Controls when the Live Activity UI is dismissed after [MosaicLiveActivities.end] is called.
enum MEndPolicy {
  /// Dismiss the Live Activity immediately.
  immediate,

  /// Dismiss the Live Activity after the system default delay.
  afterDefault,
}

/// An optional alert shown on the Lock Screen and Dynamic Island when a Live
/// Activity is updated.
class MActivityAlert {
  final String title;
  final String body;
  const MActivityAlert({required this.title, required this.body});
  Map<String, dynamic> toJson() => {'title': title, 'body': body};
}

/// Flutter-side API for the iOS Live Activities lifecycle.
///
/// All methods communicate with the native side over the shared
/// `mosaic_bridge` [MethodChannel].
class MosaicLiveActivities {
  static const MethodChannel _channel = MethodChannel('mosaic_bridge');

  /// Starts a Live Activity of [activityType] with [initialState].
  ///
  /// Returns the activity id assigned by the OS, or `null` when Live
  /// Activities are not available on the current device / OS version.
  static Future<String?> start(
    String activityType,
    Map<String, String> initialState,
  ) async {
    return await _channel.invokeMethod<String>('startActivity', {
      'activityType': activityType,
      'state': initialState,
    });
  }

  /// Pushes a new [state] to an existing Live Activity identified by [id].
  ///
  /// Provide an [alert] to show a Lock Screen / Dynamic Island notification
  /// alongside the state update.
  static Future<void> update(
    String id,
    Map<String, String> state, {
    MActivityAlert? alert,
  }) async {
    await _channel.invokeMethod('updateActivity', {
      'id': id,
      'state': state,
      'alert': alert?.toJson(),
    });
  }

  /// Ends the Live Activity identified by [id].
  ///
  /// Optionally supply a [finalState] to display before dismissal and a
  /// [policy] controlling when the UI is removed.
  static Future<void> end(
    String id, {
    Map<String, String>? finalState,
    MEndPolicy policy = MEndPolicy.afterDefault,
  }) async {
    await _channel.invokeMethod('endActivity', {
      'id': id,
      'state': finalState,
      'policy': policy.name,
    });
  }

  /// Returns `true` when Live Activities are enabled on this device.
  static Future<bool> areEnabled() async =>
      (await _channel.invokeMethod<bool>('activitiesEnabled')) ?? false;

  /// Returns the ids of all currently active Live Activities managed by this
  /// app.
  static Future<List<String>> active() async =>
      (await _channel.invokeMethod<List<dynamic>>('activeActivities'))
          ?.cast<String>() ??
      <String>[];
}

/// A bridge to communicate with native home widgets.
class MosaicBridge {
  static const MethodChannel _channel = MethodChannel('mosaic_bridge');
  static final _onDeepLinkController = StreamController<String>.broadcast();
  static String? _appGroupId;

  static bool _initialized = false;

  /// Sets the App Group ID for iOS data sharing.
  static Future<void> setAppGroupId(String groupId) async {
    _appGroupId = groupId;
  }

  /// Stream of deep links received from widgets.
  static Stream<String> get onDeepLink {
    _ensureInitialized();
    return _onDeepLinkController.stream;
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final args = call.arguments as Map?;
        _onDeepLinkController.add(args?['url'] ?? '');
      } else if (call.method == 'backgroundCallback') {
        final args = call.arguments as Map?;
        final callbackName = args?['callbackName'] as String?;
        if (callbackName != null && _backgroundCallback != null) {
          await _backgroundCallback!(callbackName);
        }
      }
    });
  }

  static Future<void> Function(String)? _backgroundCallback;

  /// Registers a top-level function to handle background events from widgets.
  static void registerBackgroundCallback(
    Future<void> Function(String) callback,
  ) {
    _ensureInitialized();
    _backgroundCallback = callback;
    // Map to HomeWidget background if needed in future
  }

  /// Saves a string value to shared storage.
  static Future<void> saveString(String key, String value) async {
    await _channel.invokeMethod('saveString', {
      'key': key,
      'value': value,
      'appGroupId': _appGroupId,
    });
  }

  /// Saves a JSON map to shared storage.
  static Future<void> saveJson(String key, Map<String, dynamic> value) async {
    await _channel.invokeMethod('saveString', {
      'key': key,
      'value': jsonEncode(value),
      'appGroupId': _appGroupId,
    });
  }

  /// Saves a list to shared storage.
  static Future<void> saveList(String key, List<dynamic> value) async {
    await _channel.invokeMethod('saveString', {
      'key': key,
      'value': jsonEncode(value),
      'appGroupId': _appGroupId,
    });
  }

  /// Saves a boolean value to shared storage.
  static Future<void> saveBool(String key, bool value) async {
    await _channel.invokeMethod('saveBool', {
      'key': key,
      'value': value,
      'appGroupId': _appGroupId,
    });
  }

  /// Triggers a refresh of all home widgets.
  static Future<void> refreshAll() async {
    await _channel.invokeMethod('refreshAll', {'appGroupId': _appGroupId});
  }

  /// Triggers a refresh of a specific home widget.
  static Future<void> refresh(String widgetName) async {
    await _channel.invokeMethod('refresh', {
      'widgetName': widgetName,
      'appGroupId': _appGroupId,
    });
  }
}
