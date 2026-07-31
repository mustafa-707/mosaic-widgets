import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// RemoteViews cannot draw vectors at all, so unlike iOS the chart cannot live
/// in the layout — the provider rasterises it with Canvas at update time.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  Map<String, dynamic> spark({bool fill = false}) => {
        '__type': 'HWSparkline',
        'bind': bind('series'),
        'color': {'hex': '#38BDF8'},
        'strokeWidth': 2,
        'fill': fill,
      };

  test('the layout only reserves an ImageView', () async {
    final r = await runAndroid([irDef(spark())]);
    expect(layout(r), contains('<ImageView'));
    expect(layout(r), contains('hw_spark_series'));
  });

  test('the provider rasterises and sets a bitmap', () async {
    final r = await runAndroid([irDef(spark())]);
    final kt = provider(r);
    expect(kt, contains('android.graphics.Canvas'));
    expect(kt, contains('setImageViewBitmap(R.id.hw_spark_series'));
    expect(kt, contains('resolveDoubleList(context, "series")'));
  });

  test('a series shorter than two points draws nothing', () async {
    // One point is not a line; drawing a dot would imply data that is not there.
    final r = await runAndroid([irDef(spark())]);
    expect(provider(r), contains('series.size > 1'));
  });

  test('a flat series does not divide by zero', () async {
    final r = await runAndroid([irDef(spark())]);
    expect(provider(r), contains('if (hi - lo == 0.0) 1.0'));
  });

  test('fill adds a closed path under the line', () async {
    final withFill = await runAndroid([irDef(spark(fill: true))]);
    expect(provider(withFill), contains('fillPath'));
    final without = await runAndroid([irDef(spark())]);
    expect(provider(without), isNot(contains('fillPath')));
  });

  test('a widget without a sparkline gets no rasterising code', () async {
    // Generator state is per-widget; leaking it emitted dead Kotlin — and an
    // unresolved reference — into every other provider.
    final r = await runAndroid([irDef(text('plain'))]);
    expect(provider(r), isNot(contains('setImageViewBitmap(R.id.hw_spark')));
  });

  test('the bitmap is sized from the live widget options', () async {
    final r = await runAndroid([irDef(spark())]);
    expect(provider(r), contains('getAppWidgetOptions(appWidgetId)'));
  });
}
