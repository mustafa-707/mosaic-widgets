import 'dart:io';

import 'package:mosaic_widgets/src/core/core.dart';
import 'package:mosaic_widgets/src/ios/ios.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A widget's `Link`/`widgetURL` on a custom scheme opens nothing unless the
/// host app declares it under `CFBundleURLTypes`. Mosaic injects the equivalent
/// Android intent-filter, so leaving iOS unregistered made the same deep link
/// work on one platform and silently die on the other.
const _basePlist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>demo</string>
</dict>
</plist>
''';

MosaicConfig configWithScheme(String? scheme) => MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
        if (scheme != null) 'deep_link_scheme': scheme,
      },
      'widgets': [
        {
          'name': 'TestW',
          'entry': 'TestW',
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

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mosaic_plist_');
    final runner = Directory(p.join(root.path, 'ios', 'Runner'));
    await runner.create(recursive: true);
    await File(p.join(runner.path, 'Info.plist')).writeAsString(_basePlist);
  });

  tearDown(() => root.deleteSync(recursive: true));

  String plist() =>
      File(p.join(root.path, 'ios', 'Runner', 'Info.plist')).readAsStringSync();

  Future<void> run(String? scheme) => IosGenerator(
        config: configWithScheme(scheme),
        definitions: const [],
      ).registerUrlScheme(root.path);

  test('the declared scheme is registered', () async {
    await run('hwdemo');
    final out = plist();
    expect(out, contains('<key>CFBundleURLSchemes</key>'));
    expect(out, contains('<string>hwdemo</string>'));
    expect(out, contains('<string>com.acme.app</string>'));
    // Must stay inside the root dict.
    expect(out.indexOf('CFBundleURLTypes'), lessThan(out.indexOf('</dict>')));
  });

  test('the default scheme is used when none is declared', () async {
    await run(null);
    expect(plist(), contains('<string>mosaic</string>'));
  });

  /// `plutil` is macOS-only. On Linux CI these assertions cannot run at all, so
  /// they are skipped there rather than failing a job that has nothing wrong
  /// with it — the plist-shape assertions above still run everywhere.
  Future<void> expectValidPlist() async {
    if (!Platform.isMacOS) return;
    final r = await Process.run('plutil', [
      '-lint',
      p.join(root.path, 'ios', 'Runner', 'Info.plist'),
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}\n${plist()}');
  }

  test('re-running does not duplicate the block', () async {
    await run('hwdemo');
    await run('hwdemo');
    expect('CFBundleURLTypes'.allMatches(plist()).length, 1);
  });

  test('repeated builds keep the plist valid', () async {
    // Counting keys is not enough: stripping only up to the first </array>
    // removed the inner schemes array and orphaned the outer one, so the key
    // count stayed at 1 while the plist decayed on every build until Xcode
    // refused to read it.
    for (var i = 0; i < 4; i++) {
      await run('hwdemo');
      await expectValidPlist();
    }
    expect('</array>'.allMatches(plist()).length,
        '<array>'.allMatches(plist()).length);
  });

  test('alternating schemes keep the plist valid', () async {
    for (final s in ['mosaic', 'hwdemo', 'mosaic', 'hwdemo']) {
      await run(s);
      await expectValidPlist();
    }
    expect(plist(), contains('<string>hwdemo</string>'));
    expect('CFBundleURLTypes'.allMatches(plist()).length, 1);
  });

  test('changing the scheme replaces rather than accumulates', () async {
    await run('mosaic');
    await run('hwdemo');
    final out = plist();
    expect('CFBundleURLTypes'.allMatches(out).length, 1);
    expect(out, contains('<string>hwdemo</string>'));
    expect(out, isNot(contains('<string>mosaic</string>')));
  });

  test('a hand-written CFBundleURLTypes is left alone', () async {
    final f = File(p.join(root.path, 'ios', 'Runner', 'Info.plist'));
    await f.writeAsString(
        _basePlist.replaceFirst('</dict>', '''	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>myown</string>
			</array>
		</dict>
	</array>
</dict>'''));
    await run('hwdemo');
    final out = plist();
    expect(out, contains('<string>myown</string>'));
    expect(out, isNot(contains('<string>hwdemo</string>')));
    expect('CFBundleURLTypes'.allMatches(out).length, 1);
  });

  test('a missing Info.plist is not an error', () async {
    File(p.join(root.path, 'ios', 'Runner', 'Info.plist')).deleteSync();
    await expectLater(run('hwdemo'), completes);
  });

  test('the scheme and bundle id are XML-escaped', () {
    final entry = IosGenerator.urlTypesEntry('a&b', 'c<d');
    expect(entry, contains('a&amp;b'));
    expect(entry, contains('c&lt;d'));
  });

  test('the plist stays parseable by plutil', skip: !Platform.isMacOS,
      () async {
    await run('hwdemo');
    final r = await Process.run('plutil', [
      '-lint',
      p.join(root.path, 'ios', 'Runner', 'Info.plist'),
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });
}
