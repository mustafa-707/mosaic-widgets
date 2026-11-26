import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';

import 'support/gen_harness.dart';

IRDefinition _def({int? minutes}) => IRDefinition(
  name: 'TestW',
  root: IRNode.fromJson({
    '__type': 'HWNetworkImage',
    'url': {'__type': 'HWBind', 'key': 'img'},
    'fit': 'cover',
    'circle': false,
    'accentedMode': 'fullColor',
  }),
  updateInterval: minutes == null ? null : minutes * 60 * 1000,
  resizeMode: 'both',
);

void main() {
  test('a cached picture is scaled down so the extension stays under its memory limit', () async {
    final r = await runIos([_def()]);
    final core = readFile(
      r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift'),
    );
    expect(core, contains('kCGImageSourceThumbnailMaxPixelSize'));
    expect(core, contains('CGImageSourceCreateThumbnailAtIndex'));
    expect(core, contains('.t640'));
  });

  test(
    'a logo with transparency is stored as PNG, anything else as JPEG',
    () async {
      final r = await runIos([_def()]);
      final core = readFile(
        r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift'),
      );
      expect(core, contains('public.png'));
      expect(core, contains('public.jpeg'));
    },
  );

  test('downloads run together on a short-timeout session', () async {
    final r = await runIos([_def()]);
    final core = readFile(
      r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift'),
    );
    expect(core, contains('withTaskGroup'));
    expect(core, contains('timeoutIntervalForRequest = 6'));
    expect(core, isNot(contains('URLSession.shared')));
  });

  test('a picture that is not ready brings the next pass forward', () async {
    final s = (await runIos([_def(minutes: 5)])).swiftForTestW();
    expect(s, contains('let imagesReady = await MosaicImageCache.prefetch('));
    expect(s, contains('imagesReady ? interval : min(interval, 60)'));
  });

  test(
    'without an interval a missing picture still asks for a retry',
    () async {
      final s = (await runIos([_def()])).swiftForTestW();
      expect(s, contains('imagesReady ? .atEnd : .after('));
    },
  );
}
