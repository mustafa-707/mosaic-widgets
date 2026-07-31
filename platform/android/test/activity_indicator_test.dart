import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// An indeterminate ProgressBar is the one genuinely animating element a widget
/// can show: it is `@RemoteView`, and the system drives the spin without the
/// app running.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  test('renders an indeterminate ProgressBar', () async {
    final r = await runAndroid([
      irDef({'__type': 'HWActivityIndicator', 'size': 20.0})
    ]);
    final xml = layout(r);
    expect(xml, contains('<ProgressBar'));
    expect(xml, contains('android:indeterminate="true"'));
    expect(xml, contains('style="?android:attr/progressBarStyleSmall"'));
  });

  test('honours size and colour', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWActivityIndicator',
        'size': 32.0,
        'color': {'hex': '#FF0000', 'opacity': 1.0},
      })
    ]);
    final xml = layout(r);
    expect(xml, contains('android:layout_width="32.0dp"'));
    expect(xml, contains('android:indeterminateTint='));
  });

  test('the spinner view is inflatable by RemoteViews', () async {
    // ProgressBar is whitelisted; a non-whitelisted view would fail the whole
    // layout with "Can't load widget".
    final r = await runAndroid([
      irDef({'__type': 'HWActivityIndicator'})
    ]);
    expect(layout(r), isNot(contains('<Space')));
    expect(layout(r), isNot(contains('<View ')));
  });

  group('refresh flag', () {
    test('provider publishes mosaic_refreshing around the fetch', () async {
      final r = await runAndroid([
        irDef(container({
          '__type': 'HWButton',
          'child': text('go'),
          'action': {'__type': 'HWActionCallback', 'callbackName': 'refresh_news'},
        }))
      ]);
      final kt = r.file(
          'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');
      final setTrue = kt.indexOf('setRefreshing(context, true)');
      final fetch = kt.indexOf('MosaicRefreshSources.run(');
      final setFalse = kt.indexOf('setRefreshing(context, false)');
      expect(setTrue, greaterThan(-1));
      // Flag on and redrawn BEFORE the request, cleared after — otherwise the
      // spinner would never be visible.
      expect(setTrue, lessThan(fetch));
      expect(fetch, lessThan(setFalse));
      expect(kt.substring(setTrue, fetch),
          contains('HomeWidgetBridgeHelper.refreshAll(context)'));
    });

    test('the flag lives in widget_data, where bindings read it', () async {
      final r = await runAndroid([irDef(text('hi'))]);
      final kt = r.file(
          'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicRefreshSources.kt');
      expect(kt, contains('putBoolean("mosaic_refreshing", value)'));
      expect(kt, contains('getSharedPreferences("widget_data"'));
    });
  });
}
