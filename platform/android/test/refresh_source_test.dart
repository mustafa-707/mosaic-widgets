import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Android parity with iOS: a widget's refresh button cannot run Dart, so
/// without a declared source it can only redraw stored data and wait for the
/// app. With one, the widget process fetches and stores the values itself.
MosaicConfig configWithRefresh() => MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
      },
      'widgets': [
        {
          'name': 'TestW',
          'entry': 'TestW',
          'android': {
            'min_sdk': 21,
            'sizes': ['medium'],
          },
          'ios': {
            'families': ['systemMedium'],
          },
        },
      ],
      'refresh': {
        'refresh_news': [
          {
            'url': 'https://api.example.com/news',
            'headers': {'Accept': 'application/json'},
            'map': {'news_title': r'results[0].title'},
          },
          {
            'url': 'https://api.example.com/extra',
            'map': {'news_extra': 'meta.total'},
          },
        ],
      },
    });

void main() {
  const sourcesPath =
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicRefreshSources.kt';

  test('emits the sources table with every declared source', () async {
    final r = await runAndroid([irDef(text('hi'))], config: configWithRefresh());
    expect(r.exists(sourcesPath), isTrue);
    final kt = r.file(sourcesPath);
    expect(kt, contains('"refresh_news" to listOf('));
    expect(kt, contains('https://api.example.com/news'));
    expect(kt, contains('https://api.example.com/extra'));
    expect(kt, contains('"Accept" to "application/json"'));
    expect(kt, contains(r'"news_title" to "results[0].title"'));
  });

  test('emits the file with no sources when none declared, so providers still '
      'compile', () async {
    final r = await runAndroid([irDef(text('hi'))]);
    expect(r.exists(sourcesPath), isTrue);
    expect(r.file(sourcesPath),
        contains('val all: Map<String, List<Source>> = emptyMap()'));
  });

  test('writes to widget_data, the store MosaicData reads', () async {
    final kt = (await runAndroid([irDef(text('hi'))], config: configWithRefresh()))
        .file(sourcesPath);
    expect(kt, contains('getSharedPreferences("widget_data"'));
    expect(kt, contains('putString(key, value)'));
  });

  test('stamps a status so an unchanged payload is distinguishable from a '
      'refresh that never ran', () async {
    final kt = (await runAndroid([irDef(text('hi'))], config: configWithRefresh()))
        .file(sourcesPath);
    expect(kt, contains('"mosaic_refresh_status"'));
    expect(kt, contains('"http \$code"'));
    expect(kt, contains('"offline"'));
  });

  test('bypasses the HTTP cache, which would return identical bytes', () async {
    final kt = (await runAndroid([irDef(text('hi'))], config: configWithRefresh()))
        .file(sourcesPath);
    expect(kt, contains('useCaches = false'));
  });

  group('provider wiring', () {
    test('the callback broadcast fetches off the main thread and keeps the '
        'receiver alive', () async {
      final r = await runAndroid([
        irDef(container({
          '__type': 'HWButton',
          'child': text('refresh'),
          'action': {'__type': 'HWActionCallback', 'callbackName': 'refresh_news'},
        }))
      ], config: configWithRefresh());
      final kt = r.file(
          'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');
      // goAsync keeps the broadcast alive; a plain Thread avoids
      // NetworkOnMainThreadException.
      expect(kt, contains('val pending = goAsync()'));
      expect(kt, contains('MosaicRefreshSources.run(context, callbackName)'));
      expect(kt, contains('pending.finish()'));
      // Widgets are redrawn with the result regardless of whether the fetch
      // succeeded. Scope to the callback branch — the toggle branch above also
      // refreshes — and check the LAST redraw, since a first one happens before
      // the request to reveal the spinner.
      final branch = kt.substring(kt.indexOf('intent.action == mosaicCallbackAction'));
      expect(branch.lastIndexOf('HomeWidgetBridgeHelper.refreshAll(context)'),
          greaterThan(branch.indexOf('MosaicRefreshSources.run')));
    });
  });
}
