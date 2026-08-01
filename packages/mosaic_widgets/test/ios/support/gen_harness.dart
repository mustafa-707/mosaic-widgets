import 'dart:io';
import 'package:mosaic_widgets/src/core/core.dart';
import 'package:mosaic_widgets/src/ios/ios.dart';
import 'package:path/path.dart' as p;

class GenResult {
  final Directory root;

  GenResult(this.root);

  /// Returns the absolute path to [rel] inside the temp root.
  String file(String rel) => p.join(root.path, rel);

  /// Returns true if [rel] exists as a file inside the temp root.
  bool exists(String rel) => File(p.join(root.path, rel)).existsSync();

  /// Convenience: reads the generated .swift file for a definition named 'TestW'.
  /// The generator writes: `ios/HomeWidgetExtension/<name>.swift`
  /// → ios/HomeWidgetExtension/TestW.swift
  String swiftForTestW() =>
      File(p.join(root.path, 'ios', 'HomeWidgetExtension', 'TestW.swift'))
          .readAsStringSync();
}

/// Reads the first line of the file at the given absolute [path].
String readFirstLine(String path) =>
    File(path).readAsStringSync().split('\n').first;

/// Reads the entire contents of the file at the given absolute [path].
String readFile(String path) => File(path).readAsStringSync();

Future<GenResult> runIos(
  List<IRDefinition> defs, {
  MosaicConfig? config,
  bool skipConfigWidget = false,
  List<Map<String, dynamic>> liveActivities = const [],
  List<Map<String, dynamic>> controls = const [],
}) async {
  final dir = await Directory.systemTemp.createTemp('hw_ios_test_');

  // Pre-create the extension directory so the generator can find it.
  await Directory(
    p.join(dir.path, 'ios', 'HomeWidgetExtension'),
  ).create(recursive: true);

  // Real projects always have ios/Runner; the host-side plugin is emitted there.
  await Directory(p.join(dir.path, 'ios', 'Runner')).create(recursive: true);

  // When skipConfigWidget == true, use a non-matching widget name so the
  // generator's firstWhere lookup (config.widgets.firstWhere((w) => w.name == def.name))
  // throws a StateError — this exercises the missing-entry error path.
  // For live-activity-only runs (no widget defs) there is no name to derive.
  final widgetName = skipConfigWidget
      ? '__none__'
      : (defs.isNotEmpty ? defs.first.name : '__none__');

  final cfg = config ??
      MosaicConfig.fromJson({
        'app': {
          'bundle_id': 'com.acme.app',
          'android_package': 'com.acme.app',
          'ios_app_group': 'group.com.acme.app.widgets',
        },
        'widgets': [
          {
            'name': widgetName,
            'entry': widgetName,
            'android': {
              'min_sdk': 21,
              'sizes': ['medium'],
            },
            'ios': {
              'families': ['systemMedium'],
            },
          },
        ],
      });

  await IosGenerator(
    config: cfg,
    definitions: defs,
    liveActivities: liveActivities,
    controls: controls,
  ).generate(dir.path);

  return GenResult(dir);
}
