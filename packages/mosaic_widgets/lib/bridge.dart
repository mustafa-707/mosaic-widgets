import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
/// A widget the user has placed on their home screen.
class MosaicWidgetInfo {
  /// The widget's declared name in `mosaic.yaml`.
  final String name;

  /// Platform id: the AppWidget id on Android, the WidgetKit configuration id
  /// on iOS. Null where the platform does not expose one.
  final String? id;

  /// The size family, on iOS (`systemSmall`, …). Null on Android, which has no
  /// equivalent concept.
  final String? family;

  /// Creates a [MosaicWidgetInfo].
  const MosaicWidgetInfo({required this.name, this.id, this.family});

  @override
  String toString() => 'MosaicWidgetInfo($name, id: $id, family: $family)';
}

/// One card in an Android TV home-screen channel.
class MosaicTvProgram {
  /// The card's title. Required — a program without one is skipped.
  final String title;

  /// Secondary line under the title.
  final String? description;

  /// Poster artwork. Any URI the system can read: an `https://` URL, or a
  /// `file://` path — including one produced by
  /// [MosaicBridge.renderFlutterWidget].
  final String? poster;

  /// Deep link opened when the card is selected.
  final String? link;

  /// Creates a [MosaicTvProgram].
  const MosaicTvProgram({
    required this.title,
    this.description,
    this.poster,
    this.link,
  });

  /// The wire form the platform expects.
  Map<String, String> toMap() => {
        'title': title,
        if (description != null) 'description': description!,
        if (poster != null) 'poster': poster!,
        if (link != null) 'link': link!,
      };
}

/// Android TV / Google TV home-screen channels.
///
/// **Not widgets.** The TV launchers host no AppWidgets at all, so a Mosaic
/// widget never appears on a TV home screen however it is declared. What the TV
/// home screen shows is channels of preview programs, and the launcher draws
/// those cards itself — so there is no layout to write, only content.
///
/// Declare the channel in `mosaic.yaml` under `tv_channels:`, then fill it:
///
/// ```dart
/// await MosaicTv.publish('featured', [
///   MosaicTvProgram(title: 'Episode 1', poster: url, link: 'myapp://ep/1'),
/// ]);
/// ```
///
/// Android only. Every call is a no-op elsewhere.
class MosaicTv {
  MosaicTv._();

  static const MethodChannel _channel = MethodChannel('mosaic_bridge');

  /// Replaces the contents of [channel] with [programs].
  ///
  /// Replaces rather than merges, so the row always matches what the app just
  /// published. Returns false when the platform has no TV channel support —
  /// iOS, or an Android project that declared none.
  static Future<bool> publish(
    String channel,
    List<MosaicTvProgram> programs,
  ) async {
    try {
      // The platform's own answer, not an assumption: a phone has no TV
      // provider, and returning true there told the caller a row exists when
      // none does.
      final ok = await _channel.invokeMethod<bool>('publishTvChannel', {
        'channel': channel,
        'programs': programs.map((p) => p.toMap()).toList(),
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

class MosaicBridge {
  static const MethodChannel _channel = MethodChannel('mosaic_bridge');
  static final _onDeepLinkController = StreamController<String>.broadcast();

  /// The last deep link that arrived with nobody listening.
  ///
  /// A broadcast stream drops events that have no subscriber, and the native
  /// side delivers a cold-launch tap during plugin registration — before
  /// `runApp` has run, let alone before anything subscribed. Without holding
  /// it, opening the app *from a widget* lost the route that made it open.
  static String? _pendingDeepLink;
  static String? _appGroupId;

  static bool _initialized = false;

  /// Sets the App Group ID for iOS data sharing.
  static Future<void> setAppGroupId(String groupId) async {
    // Arms the method-call handler as early as possible: apps set the group in
    // main(), which is well before anything subscribes to onDeepLink.
    _ensureInitialized();
    _appGroupId = groupId;
  }

  /// Stream of deep links received from widgets.
  ///
  /// Replays a link that arrived before anyone was listening, so a tap that
  /// cold-launched the app is not lost between registration and `runApp`.
  static Stream<String> get onDeepLink {
    _ensureInitialized();
    final pending = _pendingDeepLink;
    if (pending == null) return _onDeepLinkController.stream;
    _pendingDeepLink = null;
    return _onDeepLinkController.stream.transform(_prependTransformer(pending));
  }

  static StreamTransformer<String, String> _prependTransformer(String first) =>
      StreamTransformer<String, String>.fromBind(
        (source) async* {
          yield first;
          yield* source;
        },
      );

  /// The deep link that launched the app, if a widget tap did.
  ///
  /// A pull alternative to [onDeepLink] for routing at startup: read it once
  /// in `main` before deciding the initial route. Returns null when the app
  /// was opened normally, and clears itself so a later read does not re-route.
  static Future<String?> initialDeepLink() async {
    _ensureInitialized();
    final pending = _pendingDeepLink;
    _pendingDeepLink = null;
    return pending;
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final args = call.arguments as Map?;
        final url = (args?['url'] as String?) ?? '';
        if (!_onDeepLinkController.hasListener) {
          _pendingDeepLink = url;
        }
        _onDeepLinkController.add(url);
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

  /// Reads a value back out of shared storage.
  ///
  /// The store is not write-only: the *widget* writes to it too. An
  /// `MToggleAction` flips its bool on-device with the app closed, and a
  /// declared `refresh:` source stores what it fetched — neither is visible to
  /// the app without reading it back.
  ///
  /// [T] may be `String`, `bool`, `int`, `double`, or `List<dynamic>` /
  /// `Map<String, dynamic>` for values written with [saveList] / [saveJson].
  /// Returns [defaultValue] when the key is absent or holds another type.
  static Future<T?> getValue<T>(String key, {T? defaultValue}) async {
    try {
      final raw = await _channel.invokeMethod<Object?>('getValue', {
        'key': key,
        'appGroupId': _appGroupId,
      });
      if (raw == null) return defaultValue;
      if (raw is T) return raw as T;

      // Android keeps everything as strings, so coerce rather than fail.
      final text = raw.toString();
      if (T == String) return text as T;
      if (T == bool) {
        return (text == 'true' || text == '1') as T;
      }
      if (T == int) return (int.tryParse(text) ?? defaultValue) as T?;
      if (T == double) return (double.tryParse(text) ?? defaultValue) as T?;
      // Parenthesised: bare `T == List<dynamic>` parses the angle bracket as a
      // comparison operator.
      if (T == (List<dynamic>) || T == (Map<String, dynamic>)) {
        return jsonDecode(text) as T;
      }
      return defaultValue;
    } on PlatformException {
      return defaultValue;
    } on FormatException {
      return defaultValue;
    }
  }

  /// Writes [bytes] into shared storage and returns the absolute path.
  ///
  /// That path is what `MFileImage` expects. Without this the DSL could name a
  /// file the app had no supported way to put there.
  static Future<String?> saveFile(
    String key,
    Uint8List bytes, {
    String extension = 'png',
  }) async {
    return _channel.invokeMethod<String>('saveFile', {
      'key': key,
      'bytes': bytes,
      'extension': extension,
      'appGroupId': _appGroupId,
    });
  }

  /// Encodes [provider] as a PNG in shared storage and returns its path.
  static Future<String?> saveImage(
    String key,
    ImageProvider provider, {
    ImageConfiguration configuration = ImageConfiguration.empty,
  }) async {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(configuration);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      completer.complete(info.image);
    }, onError: (error, stack) {
      stream.removeListener(listener);
      completer.completeError(error, stack);
    });
    stream.addListener(listener);

    final image = await completer.future;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    return saveFile(key, data.buffer.asUint8List());
  }

  /// Rasterises an arbitrary Flutter [widget] to a PNG in shared storage and
  /// returns its path, for display through `MFileImage`.
  ///
  /// The escape hatch for anything the DSL cannot express — a chart, a
  /// `CustomPaint`, a layout with no widget-safe equivalent. The cost is that
  /// the result is a **static bitmap**: it does not adapt to light/dark or to
  /// the widget's real size, and it has to be re-rendered whenever the content
  /// changes. Prefer real DSL nodes where they exist, and reach for this when
  /// they do not.
  ///
  /// [logicalSize] is in logical pixels and should match the space the image
  /// occupies. Keep it modest on Android: a RemoteViews update carries the
  /// bitmap across a Binder transaction, and an oversized one silently drops
  /// the entire update.
  static Future<String?> renderFlutterWidget(
    Widget widget, {
    required String key,
    Size logicalSize = const Size(300, 300),
    double? pixelRatio,
  }) async {
    final repaint = RenderRepaintBoundary();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final ratio = pixelRatio ?? view.devicePixelRatio;

    final renderView = RenderView(
      view: view,
      child: RenderPositionedBox(child: repaint),
      configuration: ViewConfiguration(
        physicalConstraints: BoxConstraints.tight(logicalSize) * ratio,
        logicalConstraints: BoxConstraints.tight(logicalSize),
        devicePixelRatio: ratio,
      ),
    );

    final pipeline = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());
    final element = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaint,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData.fromView(view),
          child: widget,
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner
      ..buildScope(element)
      ..finalizeTree();
    pipeline
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();

    final image = await repaint.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    return saveFile(key, data.buffer.asUint8List());
  }

  /// The widgets the user has actually placed, so an onboarding prompt can stop
  /// nagging once one exists.
  ///
  /// Returns an empty list where the platform cannot enumerate them.
  static Future<List<MosaicWidgetInfo>> installedWidgets() async {
    try {
      final raw = await _channel
          .invokeListMethod<Map<Object?, Object?>>('installedWidgets', {
        'appGroupId': _appGroupId,
      });
      if (raw == null) return const [];
      return raw
          .map((m) => MosaicWidgetInfo(
                name: m['name']?.toString() ?? '',
                id: m['id']?.toString(),
                family: m['family']?.toString(),
              ))
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
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
