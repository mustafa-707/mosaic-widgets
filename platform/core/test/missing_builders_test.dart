import 'dart:io';

import 'package:mosaic_core/mosaic_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Mosaic derives each builder's name from `mosaic.yaml`, so a rename on one
/// side without the other used to surface as
/// `Error: Method not found: 'buildFoo'` inside `.dart_tool/hw_gen/runner.dart`
/// — generated code the developer never wrote, naming neither the convention
/// nor the file to fix.
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mosaic_runner_');
    await Directory(p.join(root.path, 'lib')).create(recursive: true);
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<void> writeEntry(String name, String body) => File(
        p.join(root.path, 'lib', '$name.dart'),
      ).writeAsString(body);

  MosaicConfig configFor(String widgetName, String entry) =>
      MosaicConfig.fromJson({
        'app': {
          'bundle_id': 'com.acme.app',
          'android_package': 'com.acme.app',
          'ios_app_group': 'group.com.acme.app.widgets',
        },
        'widgets': [
          {
            'name': widgetName,
            'entry': entry,
            'android': {'min_sdk': 21, 'sizes': ['medium']},
            'ios': {'families': ['systemMedium']},
          },
        ],
      });

  List<String> check(String widgetName, String entry) => WidgetRunner(
        config: configFor(widgetName, entry),
        projectRoot: root.path,
      ).missingBuilders();

  test('a matching builder passes', () async {
    await writeEntry('news', 'MosaicDefinition buildNews() => throw 0;');
    expect(check('News', 'lib/news.dart'), isEmpty);
  });

  test('a renamed widget is reported with function, file, and cause', () async {
    await writeEntry('news', 'MosaicDefinition buildNews() => throw 0;');
    final problems = check('SearchPill', 'lib/news.dart');
    expect(problems, hasLength(1));
    expect(problems.single, contains('buildSearchPill()'));
    expect(problems.single, contains('lib/news.dart'));
    expect(problems.single, contains('mosaic.yaml'));
  });

  test('a missing entry file is reported as missing, not as a bad name', () {
    final problems = check('News', 'lib/nope.dart');
    expect(problems, hasLength(1));
    expect(problems.single, contains('does not '));
    expect(problems.single, contains('lib/nope.dart'));
  });

  test('an expression-bodied builder counts as declared', () async {
    await writeEntry('news', '''
import 'x.dart';
MosaicDefinition buildNews() => MosaicDefinition(name: 'News');
''');
    expect(check('News', 'lib/news.dart'), isEmpty);
  });

  test('a block-bodied builder counts as declared', () async {
    await writeEntry('news', '''
MosaicDefinition buildNews() {
  return MosaicDefinition(name: 'News');
}
''');
    expect(check('News', 'lib/news.dart'), isEmpty);
  });

  test('only calling the builder does not count as declaring it', () async {
    // Otherwise a stale invocation left behind by a rename would mask the
    // missing definition and push the failure back into generated code.
    await writeEntry('news', '''
void main() {
  print(buildNews());
}
''');
    expect(check('News', 'lib/news.dart'), hasLength(1));
  });

  test('a similarly-prefixed name is not mistaken for the builder', () async {
    await writeEntry('news', 'MosaicDefinition buildNewsWidget() => throw 0;');
    expect(check('News', 'lib/news.dart'), hasLength(1));
  });
}
