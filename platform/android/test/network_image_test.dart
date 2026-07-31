import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// RemoteViews cannot reference a file path and a layout pass cannot wait on the
/// network, so the layout only reserves an ImageView and the provider sets the
/// bitmap from the on-disk cache at update time.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  test('emits an ImageView with the requested scale type', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWNetworkImage',
        'url': 'https://cdn.example.com/a.jpg',
        'fit': 'cover',
      })
    ]);
    final xml = layout(r);
    expect(xml, contains('<ImageView'));
    expect(xml, contains('android:scaleType="centerCrop"'));
    expect(xml, contains('hw_netimg_'));
  });

  test('the placeholder colour backs the view until the download lands',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWNetworkImage',
        'url': 'https://cdn.example.com/a.jpg',
        'placeholder': {'hex': '#123456', 'opacity': 1.0},
      })
    ]);
    expect(layout(r), contains('android:background='));
  });

  test('provider shows the cached bitmap and downloads off the main thread',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWNetworkImage',
        'url': 'https://cdn.example.com/a.jpg',
      })
    ]);
    final kt = provider(r);
    expect(kt, contains('MosaicRefreshSources.cachedImage(context,'));
    expect(kt, contains('setImageViewBitmap'));
    // Downloading inline would block the update; it must be threaded and then
    // trigger another redraw.
    expect(kt, contains('Thread {'));
    expect(kt, contains('MosaicRefreshSources.cacheImage(context,'));
    final download = kt.indexOf('cacheImage(context,');
    expect(kt.substring(download), contains('HomeWidgetBridgeHelper.refreshAll(context)'));
  });

  test('a bound url resolves from stored data, so a refreshed url is used',
      () async {
    final r = await runAndroid([
      irDef({'__type': 'HWNetworkImage', 'url': bind('news_image')})
    ]);
    expect(provider(r),
        contains('MosaicData.resolveString(context, "news_image")'));
  });

  test('the cache writes under filesDir and is keyed by url hash', () async {
    final r = await runAndroid([
      irDef({'__type': 'HWNetworkImage', 'url': 'https://a/b.jpg'})
    ]);
    final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicRefreshSources.kt');
    expect(kt, contains('java.io.File(context.filesDir, "mosaic_images")'));
    expect(kt, contains('kotlin.math.abs(url.hashCode())'));
    // A failed download must not leave a truncated file behind.
    expect(kt, contains('target.delete()'));
  });

  test('the ImageView is inflatable by RemoteViews', () async {
    final r = await runAndroid([
      irDef({'__type': 'HWNetworkImage', 'url': 'https://a/b.jpg'})
    ]);
    expect(layout(r), isNot(contains('<View ')));
  });

  group('fetching a URL the developer does not control', () {
    Future<String> sources() async {
      final r = await runAndroid([
        irDef({'__type': 'HWNetworkImage', 'url': 'https://a/b.jpg'})
      ]);
      return r.file(
          'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicRefreshSources.kt');
    }

    test('redirects are followed manually, across protocols', () async {
      // HttpURLConnection drops a redirect that changes protocol, and APIs
      // commonly hand out http URLs that 301 to https — so the image silently
      // never appears unless the hop is followed by hand.
      final kt = await sources();
      expect(kt, contains('instanceFollowRedirects = false'));
      expect(kt, contains('code in 300..399'));
      expect(kt, contains('getHeaderField("Location")'));
      // Resolved against the original so a relative Location still works.
      expect(kt, contains('URL(URL(url), location)'));
    });

    test('redirect following is depth-limited', () async {
      final kt = await sources();
      expect(kt, contains('depth > 4'));
    });

    test('a failed http URL is retried over https', () async {
      // Cleartext is blocked by default from API 28, and a release build has
      // none of the debug manifest's allowances.
      final kt = await sources();
      expect(kt, contains('url.startsWith("http://")'));
      expect(kt, contains(r'"https://" + url.removePrefix("http://")'));
    });

    test('every failure path logs, so a blank image is diagnosable', () async {
      final kt = await sources();
      expect(kt, contains('private const val TAG = "Mosaic"'));
      expect(kt, contains('Image fetch failed HTTP'));
      expect(kt, contains('Image fetch failed for'));
      // The exception type is what distinguishes a cleartext block from a 404.
      expect(kt, contains('e.javaClass.simpleName'));
    });
  });
}
