import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_widgets/mosaic_widgets.dart';

/// Opening the app *from a widget* could lose the route that opened it.
///
/// `onDeepLink` is a broadcast stream, and broadcast streams drop events with
/// no subscriber. The native side delivers a cold-launch tap during plugin
/// registration — before `runApp`, let alone before any widget subscribed — so
/// the link went nowhere and the app opened on its default screen.
///
/// This is the gap `home_widget` covers with `initiallyLaunchedFromHomeWidget()`:
/// a pull API, because a push stream cannot be subscribed to early enough.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mosaic_bridge');

  /// Simulates the native side delivering a tap.
  Future<void> deliver(String url) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onDeepLink', {'url': url}),
      ),
      (_) {},
    );
  }

  setUp(() async {
    // Drain anything a previous test left pending — the buffer is static.
    await MosaicBridge.initialDeepLink();
  });

  test('a link arriving before anyone listens is not lost', () async {
    await MosaicBridge.setAppGroupId('group.test');
    await deliver('myapp://from/widget');

    expect(
      await MosaicBridge.initialDeepLink(),
      'myapp://from/widget',
      reason: 'this is the cold-launch case: the tap arrives during '
          'registration, long before a StreamBuilder exists',
    );
  });

  test('reading it twice does not re-route', () async {
    await MosaicBridge.setAppGroupId('group.test');
    await deliver('myapp://once');

    expect(await MosaicBridge.initialDeepLink(), 'myapp://once');
    expect(await MosaicBridge.initialDeepLink(), isNull,
        reason: 'a second read must not send the user somewhere again');
  });

  test('a normal launch reports nothing', () async {
    expect(await MosaicBridge.initialDeepLink(), isNull);
  });

  test('the stream replays a link that arrived early', () async {
    await MosaicBridge.setAppGroupId('group.test');
    await deliver('myapp://replayed');

    // Subscribing late still sees it, so an app that only uses the stream is
    // not forced to also call initialDeepLink.
    expect(await MosaicBridge.onDeepLink.first, 'myapp://replayed');
  });

  test('live links still flow once subscribed', () async {
    await MosaicBridge.setAppGroupId('group.test');
    final seen = <String>[];
    final sub = MosaicBridge.onDeepLink.listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    await deliver('myapp://warm');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, contains('myapp://warm'));
  });
}
