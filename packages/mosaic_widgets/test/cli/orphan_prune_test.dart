import 'dart:io';

import 'package:mosaic_widgets/src/cli/commands/build_command.dart';
import 'package:mosaic_widgets/src/core/core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Renaming or removing a widget regenerates the manifest without its receiver,
/// so its provider, layout, info XML, and Swift view become unreferenced. They
/// used to stay in the repo and the APK forever.
MosaicConfig configWith(List<String> widgets) => MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
      },
      'widgets': [
        for (final w in widgets)
          {
            'name': w,
            'entry': 'lib/$w.dart',
            'android': {
              'min_sdk': 21,
              'sizes': ['medium']
            },
            'ios': {
              'families': ['systemMedium']
            },
          },
      ],
    });

void main() {
  late Directory root;
  const kotlinDir = 'android/app/src/main/kotlin/com/acme/app/mosaic_generated';
  const layoutDir = 'android/app/src/main/res/layout';
  const xmlDir = 'android/app/src/main/res/xml';
  const iosDir = 'ios/HomeWidgetExtension';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mosaic_prune_');
    for (final d in [kotlinDir, layoutDir, xmlDir, iosDir]) {
      await Directory(p.join(root.path, d)).create(recursive: true);
    }
  });

  tearDown(() => root.deleteSync(recursive: true));

  void write(String rel, String content) =>
      File(p.join(root.path, rel))..writeAsStringSync(content);

  void writeKotlin(String rel) =>
      write(rel, '// MOSAIC-GENERATED — do not edit\nclass X\n');

  /// AAPT demands the declaration first, so the sentinel lands on line 2.
  void writeResXml(String rel) => write(rel,
      '<?xml version="1.0" encoding="utf-8"?>\n<!-- MOSAIC-GENERATED -->\n<x/>\n');

  bool exists(String rel) => File(p.join(root.path, rel)).existsSync();

  List<String> prune(List<String> widgets) =>
      pruneOrphanedGeneratedFiles(root.path, configWith(widgets));

  test('a live widget keeps its compact tree', () {
    // hw_<name>_compact is the small-size variant of <name>. Treating it as a
    // widget of its own made it an orphan on every single build — survivable
    // only because pruning happens to run before generation rewrites it.
    writeKotlin('$kotlinDir/NewsProvider.kt');
    writeResXml('$layoutDir/hw_news.xml');
    writeResXml('$layoutDir/hw_news_compact.xml');

    expect(prune(['News']), isEmpty);
    expect(exists('$layoutDir/hw_news_compact.xml'), isTrue);
  });

  test('a removed widget takes its compact tree with it', () {
    writeResXml('$layoutDir/hw_news.xml');
    writeResXml('$layoutDir/hw_news_compact.xml');

    final removed = prune(['Weather']);
    expect(removed, contains('$layoutDir/hw_news_compact.xml'));
    expect(exists('$layoutDir/hw_news_compact.xml'), isFalse);
  });

  test('a still-declared widget keeps all of its files', () {
    writeKotlin('$kotlinDir/NewsProvider.kt');
    writeResXml('$layoutDir/hw_news.xml');
    writeResXml('$xmlDir/hw_news_info.xml');
    write('$iosDir/News.swift', '// MOSAIC-GENERATED — do not edit\n');

    expect(prune(['News']), isEmpty);
    expect(exists('$kotlinDir/NewsProvider.kt'), isTrue);
    expect(exists('$layoutDir/hw_news.xml'), isTrue);
    expect(exists('$xmlDir/hw_news_info.xml'), isTrue);
    expect(exists('$iosDir/News.swift'), isTrue);
  });

  test('every artefact of a removed widget goes', () {
    writeKotlin('$kotlinDir/OldProvider.kt');
    writeKotlin('$kotlinDir/OldConfigActivity.kt');
    writeResXml('$layoutDir/hw_old.xml');
    writeResXml('$xmlDir/hw_old_info.xml');
    write('$iosDir/Old.swift', '// MOSAIC-GENERATED — do not edit\n');

    final removed = prune(['News']);
    expect(removed, hasLength(5));
    expect(exists('$kotlinDir/OldProvider.kt'), isFalse);
    expect(exists('$kotlinDir/OldConfigActivity.kt'), isFalse);
    expect(exists('$layoutDir/hw_old.xml'), isFalse);
    expect(exists('$xmlDir/hw_old_info.xml'), isFalse);
    expect(exists('$iosDir/Old.swift'), isFalse);
  });

  test('a resource file whose sentinel is on line 2 is still recognised', () {
    // Checking only line 1 left every generated layout and info XML behind.
    writeResXml('$layoutDir/hw_old.xml');
    expect(prune(['News']), contains('$layoutDir/hw_old.xml'));
  });

  test('shared Android runtime is never treated as per-widget', () {
    for (final f in [
      'MosaicData.kt',
      'MosaicPlugin.kt',
      'MosaicRefreshSources.kt',
      'MosaicDevice.kt',
      'HomeWidgetBridgeHelper.kt',
    ]) {
      writeKotlin('$kotlinDir/$f');
    }
    expect(prune(['News']), isEmpty);
    expect(exists('$kotlinDir/MosaicPlugin.kt'), isTrue);
  });

  test('shared iOS runtime is never treated as per-widget', () {
    for (final f in [
      'MosaicIntents.swift',
      'MosaicRefreshSources.swift',
      'HomeWidgetCore.swift',
      'HomeWidgetBundle.swift',
    ]) {
      write('$iosDir/$f', '// MOSAIC-GENERATED — do not edit\n');
    }
    expect(prune(['News']), isEmpty);
    expect(exists('$iosDir/HomeWidgetBundle.swift'), isTrue);
  });

  test('a hand-written file matching the pattern is never deleted', () {
    // No sentinel: the developer wrote this, whatever it is called.
    write('$kotlinDir/OldProvider.kt', 'class OldProvider\n');
    write('$layoutDir/hw_old.xml', '<?xml version="1.0"?>\n<x/>\n');
    expect(prune(['News']), isEmpty);
    expect(exists('$kotlinDir/OldProvider.kt'), isTrue);
    expect(exists('$layoutDir/hw_old.xml'), isTrue);
  });

  test('layout matching is case-insensitive against the declared name', () {
    // Layout basenames are lowercased; the config name is not.
    writeResXml('$layoutDir/hw_newswidget.xml');
    expect(prune(['NewsWidget']), isEmpty);
    expect(exists('$layoutDir/hw_newswidget.xml'), isTrue);
  });

  test('a live activity keeps its la_ layout and suffixed Swift', () {
    final config = MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
      },
      'widgets': const [],
      'live_activities': [
        {'name': 'OrderTracker', 'entry': 'lib/order.dart'},
      ],
    });
    writeResXml('$layoutDir/hw_la_ordertracker.xml');
    write('$iosDir/OrderTrackerLiveActivity.swift',
        '// MOSAIC-GENERATED — do not edit\n');
    expect(pruneOrphanedGeneratedFiles(root.path, config), isEmpty);
  });

  test('missing directories are not an error', () {
    root.listSync().forEach((e) => e.deleteSync(recursive: true));
    expect(() => prune(['News']), returnsNormally);
  });
}
