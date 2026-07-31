import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// A render pass cannot wait on the network, so the view reads an on-disk cache
/// and the timeline provider does the downloading.
void main() {
  test('renders from the cache with a placeholder fallback', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWNetworkImage',
        'url': 'https://cdn.example.com/a.jpg',
        'fit': 'cover',
        'placeholder': {'hex': '#123456', 'opacity': 1.0},
      })
    ]);
    final swift = r.swiftForTestW();
    expect(swift, contains('MosaicImageCache.cached("https://cdn.example.com/a.jpg")'));
    expect(swift, contains('.aspectRatio(contentMode: .fill)'));
    // Falls back to the placeholder rather than an empty frame.
    expect(swift, contains('} else {'));
    expect(swift, contains('Color('));
  });

  test('the provider prefetches literal urls', () async {
    final r = await runIos([
      irDef({'__type': 'HWNetworkImage', 'url': 'https://cdn.example.com/a.jpg'})
    ]);
    final body = r.swiftForTestW();
    final timeline = body.substring(body.indexOf('func getTimeline'));
    expect(timeline, contains('await MosaicImageCache.prefetch('));
    expect(timeline, contains('https://cdn.example.com/a.jpg'));
  });

  test('a bound url is prefetched from stored data, so a url that arrived in '
      'this pass is downloaded immediately', () async {
    final r = await runIos([
      irDef({'__type': 'HWNetworkImage', 'url': bind('news_image')})
    ]);
    final body = r.swiftForTestW();
    final timeline = body.substring(body.indexOf('func getTimeline'));
    expect(timeline, contains('mosaicStr(loadData()["news_image"])'));
    // Prefetch runs after the refresh so a freshly fetched url is picked up.
    expect(timeline.indexOf('MosaicRefreshSources.run'),
        lessThan(timeline.indexOf('MosaicImageCache.prefetch')));
  });

  test('widgets with no network image prefetch nothing', () async {
    final r = await runIos([irDef(text('hi'))]);
    final body = r.swiftForTestW();
    final timeline = body.substring(body.indexOf('func getTimeline'));
    expect(timeline, contains('MosaicImageCache.prefetch([])'));
  });

  test('the cache lives in the App Group and is keyed by url hash', () async {
    final r = await runIos([irDef(text('hi'))]);
    final core = readFile(r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));
    expect(core, contains('enum MosaicImageCache'));
    expect(core, contains('containerURL(forSecurityApplicationGroupIdentifier: kMosaicAppGroup)'));
    expect(core, contains('String(abs(url.hashValue))'));
  });
}
