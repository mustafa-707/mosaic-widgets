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

/// A per-activity APNs push token surfaced from iOS ActivityKit.
///
/// When a Live Activity is started with `push: true`, iOS issues (and may
/// later rotate) a push token for that specific activity. The token is
/// delivered to Flutter as a lowercase hex string; forward it to your server
/// so the server can push updates / end the activity via APNs. See
/// `docs/LIVE_ACTIVITIES.md` → "Push updates".
class MosaicPushToken {
  /// The activity id this token belongs to (matches the id returned by
  /// [MosaicLiveActivities.start]).
  final String id;

  /// The APNs push token for the activity, hex-encoded.
  final String token;

  const MosaicPushToken({required this.id, required this.token});

  @override
  String toString() => 'MosaicPushToken(id: $id, token: $token)';
}

/// Flutter-side API for the iOS Live Activities lifecycle.
///
/// All methods communicate with the native side over the shared
/// `mosaic_bridge` [MethodChannel].
class MosaicLiveActivities {
  static const MethodChannel _channel = MethodChannel('mosaic_bridge');

  static final StreamController<MosaicPushToken> _onPushTokenController =
      StreamController<MosaicPushToken>.broadcast();

  /// Broadcast stream of per-activity APNs push tokens.
  ///
  /// Emits whenever iOS issues or rotates the push token for an activity that
  /// was started with `push: true`. The incoming native call is
  /// `liveActivityPushToken` with `{id, token}` (token = hex string), routed
  /// through the shared `mosaic_bridge` handler owned by [MosaicBridge].
  ///
  /// Forward each token to your server so it can push updates via APNs (the
  /// server / APNs side is the app's responsibility).
  static Stream<MosaicPushToken> get onPushToken {
    MosaicBridge._ensureInitialized();
    return _onPushTokenController.stream;
  }

  /// Dispatches an incoming `liveActivityPushToken` channel call onto
  /// [onPushToken]. Called from [MosaicBridge]'s shared method-call handler so
  /// we never double-set a handler on the `mosaic_bridge` channel.
  static void _dispatchPushToken(Map? args) {
    final id = args?['id'] as String?;
    final token = args?['token'] as String?;
    if (id != null && token != null) {
      _onPushTokenController.add(MosaicPushToken(id: id, token: token));
    }
  }

  /// Starts a Live Activity of [activityType] with [initialState].
  ///
  /// Returns the activity id assigned by the OS, or `null` when Live
  /// Activities are not available on the current device / OS version.
  ///
  /// Set [push] to `true` to request remote push updates: iOS will issue a
  /// per-activity APNs push token delivered via [onPushToken]. Register that
  /// token with your server so the server can push updates / end the activity
  /// through APNs. Has no effect on Android (updates are local-only there).
  static Future<String?> start(
    String activityType,
    Map<String, String> initialState, {
    bool push = false,
  }) async {
    return await _channel.invokeMethod<String>('startActivity', {
      'activityType': activityType,
      'state': initialState,
      'push': push,
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
      } else if (call.method == 'liveActivityPushToken') {
        // Per-activity APNs push token from iOS ActivityKit. The shared
        // 'mosaic_bridge' handler is owned here, so we forward to
        // MosaicLiveActivities rather than setting a second handler.
        MosaicLiveActivities._dispatchPushToken(call.arguments as Map?);
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

  /// The APNs push tokens WidgetKit issued for widgets declaring `push: true`,
  /// keyed by widget name.
  ///
  /// Only the widget extension is told these tokens, and it cannot reach your
  /// server — it stores them for the app to collect. Read this on launch and on
  /// resume, and register whatever it returns:
  ///
  /// ```dart
  /// final tokens = await MosaicBridge.widgetPushTokens();
  /// for (final entry in tokens.entries) {
  ///   await myApi.registerWidgetToken(widget: entry.key, token: entry.value);
  /// }
  /// ```
  ///
  /// Your server then pushes `{"aps":{"content-changed":true}}` to a token with
  /// `apns-push-type: widgets` and topic `<bundle-id>.push-type.widgets`, which
  /// reloads that widget's timeline while the app is closed.
  ///
  /// Empty until WidgetKit issues a token — it does so once a widget is placed,
  /// and not at all in the simulator. **iOS 26+ only**; returns empty on
  /// Android, which has no widget-push equivalent.
  static Future<Map<String, String>> widgetPushTokens() async {
    try {
      final tokens = await _channel.invokeMapMethod<String, String>(
        'widgetPushTokens',
        {'appGroupId': _appGroupId},
      );
      return tokens ?? const {};
    } on MissingPluginException {
      // Android has no widget-push equivalent, so its host may not implement
      // this at all. Absence of tokens is the correct answer, not an error.
      return const {};
    } on PlatformException {
      return const {};
    }
  }

  /// Whether [requestPinWidget] can do anything on this device.
  ///
  /// False on iOS (no such API exists) and on Android launchers that do not
  /// implement widget pinning. Use it to decide between showing an "Add to
  /// Home Screen" button and showing manual instructions.
  static Future<bool> canRequestPinWidget() async {
    try {
      return await _channel.invokeMethod<bool>('canRequestPinWidget') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Asks the launcher to show its "add widget" dialog for [widgetName],
  /// letting a user place a widget without leaving your app.
  ///
  /// This is the single biggest lever on widget adoption: most users never
  /// discover the launcher's widget picker on their own.
  ///
  /// Returns whether the dialog was shown — **not** whether the user accepted;
  /// Android does not report the outcome. Detect actual placement by watching
  /// for the widget's first update.
  ///
  /// **Android only** (API 26+, and only on launchers that support pinning).
  /// iOS exposes no equivalent — Apple requires the user to go through the
  /// widget gallery — so this returns false there and you should fall back to
  /// on-screen instructions. Check [canRequestPinWidget] first.
  ///
  /// ```dart
  /// if (await MosaicBridge.canRequestPinWidget()) {
  ///   await MosaicBridge.requestPinWidget('News');
  /// } else {
  ///   showDialog(...); // "Long-press the home screen, tap Widgets…"
  /// }
  /// ```
  static Future<bool> requestPinWidget(String widgetName) async {
    try {
      return await _channel.invokeMethod<bool>(
            'requestPinWidget',
            {'widgetName': widgetName},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}
