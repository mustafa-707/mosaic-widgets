import 'dart:io';
import 'package:mosaic_core/mosaic_core.dart';
import 'package:mosaic_android/mosaic_android.dart';
import 'package:path/path.dart' as p;

class GenResult {
  final Directory root;

  GenResult(this.root);

  /// Returns the **contents** of the file at [rel] (relative to the temp root).
  String file(String rel) => File(p.join(root.path, rel)).readAsStringSync();

  bool exists(String rel) => File(p.join(root.path, rel)).existsSync();

  /// All generated resource XML files under `res/` (layout, xml, drawable).
  List<File> resXmlFiles() {
    final resDir = Directory(
      p.join(root.path, 'android', 'app', 'src', 'main', 'res'),
    );
    if (!resDir.existsSync()) return const [];
    return resDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.xml'))
        .toList();
  }

  /// Asserts (returns the offending path, or null) that every generated res
  /// XML file's FIRST line is the XML declaration — AAPT rejects any file
  /// whose declaration is not the first bytes.
  String? firstNonXmlDeclFile() {
    for (final f in resXmlFiles()) {
      final firstLine = f.readAsStringSync().split('\n').first.trimRight();
      if (!firstLine.startsWith('<?xml')) return f.path;
    }
    return null;
  }
}

Future<GenResult> runAndroid(
  List<IRDefinition> defs, {
  MosaicConfig? config,
}) async {
  final dir = await Directory.systemTemp.createTemp('hw_android_test_');

  // Pre-create the res directory so the generator can find it.
  await Directory(
    p.join(dir.path, 'android', 'app', 'src', 'main', 'res'),
  ).create(recursive: true);

  final cfg = config ??
      MosaicConfig.fromJson({
        'app': {
          'bundle_id': 'com.acme.app',
          'android_package': 'com.acme.app',
          'ios_app_group': 'group.com.acme.app.widgets',
        },
        'widgets': [
          {
            'name': defs.first.name,
            'entry': defs.first.name,
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

  await AndroidGenerator(config: cfg, definitions: defs).generate(dir.path);

  return GenResult(dir);
}
