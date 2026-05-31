import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

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
