import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_widgets/bridge.dart';

/// Only the widget extension is told a widget's APNs token, and it cannot reach
/// a server — it stores tokens for the app to collect. Without this the push
/// feature cannot complete its loop.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mosaic_bridge');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('returns the tokens keyed by widget name', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'widgetPushTokens') return null;
      return <String, String>{'CryptoWidget': 'abc123', 'Weather': 'def456'};
    });

    expect(await MosaicBridge.widgetPushTokens(),
        {'CryptoWidget': 'abc123', 'Weather': 'def456'});
  });

  test('an empty result is empty, not null', () async {
    messenger.setMockMethodCallHandler(
        channel, (call) async => <String, String>{});
    expect(await MosaicBridge.widgetPushTokens(), isEmpty);
  });

  test('a null result is empty', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await MosaicBridge.widgetPushTokens(), isEmpty);
  });

  // Android has no widget-push equivalent, so its host may not implement the
  // method. No tokens is the correct answer there, not a crash.
  test('an unimplemented host yields empty rather than throwing', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException('not implemented');
    });
    expect(await MosaicBridge.widgetPushTokens(), isEmpty);
  });

  test('a platform error yields empty rather than throwing', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'APP_GROUP_ERROR');
    });
    expect(await MosaicBridge.widgetPushTokens(), isEmpty);
  });
}
