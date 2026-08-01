import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Bars are rasterised for the same reason sparklines are: RemoteViews has no
/// vector drawing at all.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  Map<String, dynamic> bars() => {
        '__type': 'HWBarChart',
        'bind': bind('week'),
        'color': {'hex': '#22C55E'},
        'spacing': 3,
        'radius': 2,
      };

  test('the layout only reserves an ImageView', () async {
    final r = await runAndroid([irDef(bars())]);
    expect(layout(r), contains('hw_bars_week'));
    expect(layout(r), contains('<ImageView'));
  });

  test('the provider rasterises rounded bars', () async {
    final r = await runAndroid([irDef(bars())]);
    final kt = provider(r);
    expect(kt, contains('drawRoundRect'));
    expect(kt, contains('setImageViewBitmap(R.id.hw_bars_week'));
    expect(kt, contains('resolveDoubleList(context, "week")'));
  });

  test('bars scale from zero, not from the series minimum', () async {
    // A bar's length is read as its magnitude, so starting the axis at the
    // smallest value would overstate small differences.
    final kt = provider(await runAndroid([irDef(bars())]));
    expect(kt, contains('v / top'));
    expect(kt, isNot(contains('v - lo')));
  });

  test('a series with nothing positive draws nothing', () async {
    final kt = provider(await runAndroid([irDef(bars())]));
    expect(kt, contains('top > 0.0'));
  });

  test('a zero bucket still reads as a bucket', () async {
    // Collapsing it to nothing would look like a gap in the axis.
    final kt = provider(await runAndroid([irDef(bars())]));
    expect(kt, contains('coerceAtLeast(1f)'));
  });

  test('a widget without a chart gets no rasterising code', () async {
    final r = await runAndroid([irDef(text('plain'))]);
    expect(provider(r), isNot(contains('setImageViewBitmap(R.id.hw_bars')));
  });
}
