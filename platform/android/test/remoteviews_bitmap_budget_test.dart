import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// RemoteViews travels over a Binder transaction with a hard size limit. Exceed
/// it and the launcher drops the **entire** update: the widget renders only its
/// static layout, every bound value disappears at once, and nothing is logged.
///
/// This actually happened — a 4.3 MB news photo decoded at full resolution
/// blanked the whole News widget, which looked for all the world like a data
/// problem. Every path that hands a bitmap to RemoteViews is pinned here.
void main() {
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');
  String core(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicRefreshSources.kt');

  group('network images', () {
    test('are decoded downsampled, never at full resolution', () async {
      final r = await runAndroid([
        irDef({'__type': 'HWNetworkImage', 'url': bind('photo')})
      ]);
      expect(provider(r), contains('decodeSampled'));
      // The naive call is what blew the budget.
      expect(provider(r), isNot(contains('BitmapFactory.decodeFile(netFile')));
    });

    test('bounds are read before the pixels', () async {
      // Decoding to measure would allocate the very bitmap we are avoiding.
      final r = await runAndroid([
        irDef({'__type': 'HWNetworkImage', 'url': bind('photo')})
      ]);
      expect(core(r), contains('inJustDecodeBounds = true'));
      expect(core(r), contains('inSampleSize'));
    });

    test('a failed decode is skipped rather than set as null', () async {
      final r = await runAndroid([
        irDef({'__type': 'HWNetworkImage', 'url': bind('photo')})
      ]);
      expect(provider(r), contains('?.let { views.setImageViewBitmap'));
    });
  });

  group('charts', () {
    test('both chart kinds go through the clamped size helper', () async {
      // dp * 3 unclamped is ~5.8 MB on a 5x5 tile — the same failure, waiting.
      for (final node in [
        {
          '__type': 'HWSparkline',
          'bind': bind('series'),
          'strokeWidth': 2,
          'fill': false,
        },
        {
          '__type': 'HWBarChart',
          'bind': bind('series'),
          'spacing': 3,
          'radius': 2,
        },
      ]) {
        final r = await runAndroid([irDef(node)]);
        expect(provider(r), contains('chartBitmapSize'),
            reason: '${node['__type']} bypasses the budget');
        expect(provider(r), isNot(contains('.coerceAtLeast(40) * 3')));
      }
    });

    test('the budget preserves aspect ratio', () async {
      // Clamping one axis only would stretch the chart.
      final r = await runAndroid([
        irDef({'__type': 'HWSparkline', 'bind': bind('series')})
      ]);
      expect(core(r), contains('kotlin.math.sqrt'));
    });

    test('the budget leaves room for more than one bitmap', () async {
      final r = await runAndroid([
        irDef({'__type': 'HWSparkline', 'bind': bind('series')})
      ]);
      expect(core(r), contains('maxPx = 60_000'));
    });
  });
}
