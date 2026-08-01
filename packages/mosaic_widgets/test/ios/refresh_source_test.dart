import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Widget-extension AppIntents cannot run Dart, so a refresh button could only
/// re-render stored data and defer the real work to the host app's next
/// foreground. A declared `refresh:` source lets the generated intent fetch and
/// store the data itself, so the button works while the app is closed.
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
        'refresh_news': {
          'url': 'https://api.example.com/news',
          'headers': {'Accept': 'application/json'},
          'map': {'news_title': r'articles[0].title'},
        },
      },
    });

void main() {
  const sourcesPath = 'ios/HomeWidgetExtension/MosaicRefreshSources.swift';

  test('emits the refresh sources file with the declared source', () async {
    final r = await runIos([irDef(text('hi'))], config: configWithRefresh());
    expect(r.exists(sourcesPath), isTrue);
    final swift = readFile(r.file(sourcesPath));
    expect(swift, contains('"refresh_news"'));
    expect(swift, contains('https://api.example.com/news'));
    expect(swift, contains('"Accept": "application/json"'));
    expect(swift, contains(r'"news_title": "articles[0].title"'));
    expect(swift, contains('method: "GET"'));
  });

  test(
      'emits the file with no sources when none are declared, so the '
      'intents still compile', () async {
    final r = await runIos([irDef(text('hi'))]);
    expect(r.exists(sourcesPath), isTrue);
    final swift = readFile(r.file(sourcesPath));
    expect(swift,
        contains('static let all: [String: [MosaicRefreshSource]] = [:]'));
  });

  test('a callback may fetch several sources, e.g. two units', () async {
    final config = MosaicConfig.fromJson({
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
        'refresh_weather': [
          {
            'url': 'https://api.example.com/w?unit=c',
            'map': {'temp_c': 'current.temperature_2m'},
          },
          {
            'url': 'https://api.example.com/w?unit=f',
            'map': {'temp_f': 'current.temperature_2m'},
          },
        ],
      },
    });
    final r = await runIos([irDef(text('hi'))], config: config);
    final swift = readFile(r.file(sourcesPath));
    expect(swift, contains('unit=c'));
    expect(swift, contains('unit=f'));
    expect(swift, contains('"temp_c"'));
    expect(swift, contains('"temp_f"'));
    // One failing endpoint must not discard the other's values.
    expect(swift, contains('case .wrote: wroteAny = true'));
  });

  // Writes and reads go through different UserDefaults instances, which can
  // otherwise serve a snapshot taken before the fetch — the fetch succeeds but
  // the widget still renders the old values.
  test('flushes writes and re-reads before rendering', () async {
    final r = await runIos([irDef(text(bind('news_title')))],
        config: configWithRefresh());
    final sources = readFile(r.file(sourcesPath));
    expect(sources, contains('if wrote { defaults.synchronize() }'));

    final provider = r.swiftForTestW();
    final load = provider.substring(provider.indexOf('private func loadData'));
    expect(load.indexOf('defaults.synchronize()'),
        lessThan(load.indexOf('for k in [')));
  });

  group('diagnostics', () {
    test(
        'stamps a status on every attempt, so an unchanged payload is still '
        'distinguishable from a refresh that never ran', () async {
      final r = await runIos([irDef(text('hi'))], config: configWithRefresh());
      final swift = readFile(r.file(sourcesPath));
      expect(swift, contains('forKey: "mosaic_refresh_status"'));
      expect(swift,
          contains('recordStatus(wroteAny ? "ok" : (failure ?? "no data"))'));
    });

    test('reports the HTTP status when a source rejects the request', () async {
      final r = await runIos([irDef(text('hi'))], config: configWithRefresh());
      final swift = readFile(r.file(sourcesPath));
      expect(swift, contains(r'return .failed("http \(http.statusCode)")'));
      expect(swift, contains('.failed("offline")'));
    });

    test(
        'bypasses the URL cache, which would otherwise return an identical '
        'response and look like a dead button', () async {
      final r = await runIos([irDef(text('hi'))], config: configWithRefresh());
      final swift = readFile(r.file(sourcesPath));
      expect(swift,
          contains('request.cachePolicy = .reloadIgnoringLocalCacheData'));
    });
  });

  test('emits a JSON path resolver supporting dots and array indices',
      () async {
    final r = await runIos([irDef(text('hi'))], config: configWithRefresh());
    final swift = readFile(r.file(sourcesPath));
    expect(swift, contains('func mosaicResolveJSONPath'));
  });

  // Both the intent and the timeline provider fetch. Either can be the path
  // that survives — an intent has a short execution window, and a provider
  // reload can be coalesced — and both write the same keys, so the second is
  // just a no-op refresh.
  test('the callback intent fetches, then reloads', () async {
    final r = await runIos([irDef(text('hi'))], config: configWithRefresh());
    final intents =
        readFile(r.file('ios/HomeWidgetExtension/MosaicIntents.swift'));
    // Scope to this struct — the refresh intent above it also reloads.
    final body =
        intents.substring(intents.indexOf('struct MosaicCallbackIntent'));
    final fetch = body.indexOf('await MosaicRefreshSources.run(callbackName)');
    final reload = body.indexOf('WidgetCenter.shared.reloadAllTimelines()');
    expect(fetch, greaterThan(-1));
    expect(fetch, lessThan(reload));
  });

  // WidgetKit waits for `completion`, so fetching first makes the fresh values
  // render on this pass. Completing first and reloading afterwards would depend
  // on a second reload, which the system may throttle away.
  test('the timeline provider fetches before completing', () async {
    final r = await runIos([irDef(text(bind('news_title')))],
        config: configWithRefresh());
    final swift = r.swiftForTestW();
    // Scope to getTimeline — getSnapshot also calls loadData().
    final body = swift.substring(swift.indexOf('func getTimeline'));
    final fetch = body.indexOf('await MosaicRefreshSources.run(keys:');
    final load = body.indexOf('data: loadData()');
    final complete = body.indexOf('completion(timeline)');
    expect(fetch, greaterThan(-1));
    expect(fetch, lessThan(load));
    expect(load, lessThan(complete));
    expect(swift, contains('"news_title"'));
  });

  test(
      'uses an ephemeral session, not URLSession.shared, which an extension '
      'may not be able to reach', () async {
    final r = await runIos([irDef(text('hi'))], config: configWithRefresh());
    final swift = readFile(r.file(sourcesPath));
    expect(swift, contains('URLSessionConfiguration.ephemeral'));
    // No *usage* of the shared session (the comment may name it).
    expect(swift, isNot(contains('URLSession.shared.')));
    expect(swift, contains('try await session.data(for: request)'));
    expect(swift, contains('config.timeoutIntervalForRequest = 10'));
  });

  test('sources feeding the same key across callbacks are fetched once',
      () async {
    final r = await runIos([irDef(text('hi'))], config: configWithRefresh());
    final swift = readFile(r.file(sourcesPath));
    expect(swift, contains('static func run(keys: [String]) async -> Bool'));
    expect(swift, contains('seenURLs.insert(source.url).inserted'));
  });

  test(
      'falls back to the pending-callback handoff when the fetch does not '
      'handle the callback', () async {
    final r = await runIos([irDef(text('hi'))], config: configWithRefresh());
    final intents =
        readFile(r.file('ios/HomeWidgetExtension/MosaicIntents.swift'));
    expect(intents, contains('mosaic_pending_callback'));
  });
}
