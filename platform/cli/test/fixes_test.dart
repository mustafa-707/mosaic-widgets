import 'dart:io';

import 'package:mosaic_cli/src/fixes.dart';
import 'package:mosaic_core/mosaic_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `doctor --fix` repairs only what has one unambiguous answer. Anything needing
/// a judgement call — or an Xcode project mutation — stays a reported problem,
/// because a wrong guess is worse than a clear message.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('mosaic_fix_'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String rel, String contents) {
    final f = File(p.join(root.path, rel));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(contents);
  }

  String read(String rel) => File(p.join(root.path, rel)).readAsStringSync();
  bool exists(String rel) => File(p.join(root.path, rel)).existsSync();

  void writeConfig({
    String androidPackage = 'com.acme.app',
    String appGroup = 'group.com.acme.app.widgets',
    String extra = '',
  }) =>
      write('mosaic.yaml', '''
app:
  bundle_id: com.acme.app
  android_package: $androidPackage
  ios_app_group: $appGroup
widgets: []
$extra''');

  MosaicConfig config() =>
      MosaicConfig.fromYaml(read('mosaic.yaml'));

  List<AppliedFix> fix() => applyFixes(config(), root.path);

  group('supportsRtl', () {
    test('is added when absent', () {
      writeConfig();
      write('android/app/src/main/AndroidManifest.xml',
          '<manifest>\n    <application android:label="x">\n    </application>\n</manifest>');
      expect(fix().map((f) => f.message).join(), contains('supportsRtl'));
      expect(read('android/app/src/main/AndroidManifest.xml'),
          contains('android:supportsRtl="true"'));
    });

    test('an explicit false is left alone', () {
      // Opting out may be deliberate, so this stays advisory rather than fixed.
      writeConfig();
      write('android/app/src/main/AndroidManifest.xml',
          '<manifest><application android:supportsRtl="false" /></manifest>');
      expect(fix(), isEmpty);
      expect(read('android/app/src/main/AndroidManifest.xml'),
          contains('"false"'));
    });

    test('an existing true is not duplicated', () {
      writeConfig();
      write('android/app/src/main/AndroidManifest.xml',
          '<manifest><application android:supportsRtl="true" /></manifest>');
      expect(fix(), isEmpty);
      expect('supportsRtl'.allMatches(
              read('android/app/src/main/AndroidManifest.xml')).length,
          1);
    });
  });

  group('android_package', () {
    test('is rewritten to match applicationId', () {
      // Gradle decides where Kotlin actually compiles, so the config moves.
      writeConfig(androidPackage: 'com.wrong.pkg');
      write('android/app/build.gradle.kts',
          'defaultConfig {\n  applicationId = "com.real.app"\n}');
      expect(fix().map((f) => f.message).join(), contains('com.real.app'));
      expect(read('mosaic.yaml'), contains('android_package: com.real.app'));
    });

    test('a match is left alone', () {
      writeConfig();
      write('android/app/build.gradle.kts',
          'defaultConfig {\n  applicationId = "com.acme.app"\n}');
      expect(fix(), isEmpty);
    });
  });

  group('ios_app_group', () {
    test('gains the required group. prefix', () {
      writeConfig(appGroup: 'com.acme.app.widgets');
      final applied = fix();
      expect(applied.map((f) => f.message).join(), contains('group.'));
      expect(read('mosaic.yaml'),
          contains('ios_app_group: group.com.acme.app.widgets'));
    });

    test('entitlements written in the same pass use the corrected group', () {
      // The prefix fix rewrites mosaic.yaml, so later fixes must re-read it —
      // otherwise the entitlements got the invalid group and --fix needed
      // running twice.
      writeConfig(appGroup: 'com.acme.app.widgets');
      Directory(p.join(root.path, 'ios/Runner')).createSync(recursive: true);
      fix();
      expect(read('ios/Runner/Runner.entitlements'),
          contains('<string>group.com.acme.app.widgets</string>'));
    });
  });

  group('entitlements', () {
    test('are created for targets that exist', () {
      writeConfig();
      Directory(p.join(root.path, 'ios/Runner')).createSync(recursive: true);
      Directory(p.join(root.path, 'ios/HomeWidgetExtension'))
          .createSync(recursive: true);
      fix();
      expect(exists('ios/Runner/Runner.entitlements'), isTrue);
      expect(
          exists('ios/HomeWidgetExtension/HomeWidgetExtension.entitlements'),
          isTrue);
    });

    test('are not created for a target that does not exist', () {
      writeConfig();
      Directory(p.join(root.path, 'ios/Runner')).createSync(recursive: true);
      fix();
      expect(exists('ios/Runner/Runner.entitlements'), isTrue);
      expect(
          exists('ios/HomeWidgetExtension/HomeWidgetExtension.entitlements'),
          isFalse);
    });

    test('the group is added to an existing plist without one', () {
      writeConfig();
      write('ios/Runner/Runner.entitlements',
          '<plist version="1.0">\n<dict>\n\t<key>other</key>\n\t<true/>\n</dict>\n</plist>');
      fix();
      final out = read('ios/Runner/Runner.entitlements');
      expect(out, contains('com.apple.security.application-groups'));
      expect(out, contains('group.com.acme.app.widgets'));
      expect(out, contains('<key>other</key>'));
    });

    test('the group joins an existing groups array', () {
      writeConfig();
      write('ios/Runner/Runner.entitlements', '''<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.other.existing</string>
	</array>
</dict>
</plist>''');
      fix();
      final out = read('ios/Runner/Runner.entitlements');
      expect(out, contains('group.other.existing'));
      expect(out, contains('group.com.acme.app.widgets'));
    });

    test('a correct plist is not rewritten', () {
      writeConfig();
      write('ios/Runner/Runner.entitlements',
          '<plist><dict><array><string>group.com.acme.app.widgets</string></array></dict></plist>');
      expect(fix(), isEmpty);
    });
  });

  group('live activities plist key', () {
    test('is added when live activities are declared', () {
      writeConfig(extra: '''live_activities:
  - name: Order
    entry: lib/order.live.dart
''');
      write('ios/Runner/Info.plist',
          '<plist version="1.0">\n<dict>\n\t<key>x</key>\n\t<true/>\n</dict>\n</plist>');
      fix();
      expect(read('ios/Runner/Info.plist'),
          contains('NSSupportsLiveActivities'));
    });

    test('is not added when none are declared', () {
      writeConfig();
      write('ios/Runner/Info.plist',
          '<plist version="1.0">\n<dict>\n</dict>\n</plist>');
      fix();
      expect(read('ios/Runner/Info.plist'),
          isNot(contains('NSSupportsLiveActivities')));
    });
  });

  test('running twice changes nothing the second time', () {
    writeConfig(androidPackage: 'com.wrong.pkg', appGroup: 'bad.group');
    write('android/app/build.gradle.kts',
        'defaultConfig {\n  applicationId = "com.real.app"\n}');
    write('android/app/src/main/AndroidManifest.xml',
        '<manifest><application /></manifest>');
    Directory(p.join(root.path, 'ios/Runner')).createSync(recursive: true);

    expect(fix(), isNotEmpty);
    expect(fix(), isEmpty, reason: 'second pass should be a no-op');
  });

  test('an Xcode target is never mutated', () {
    // Editing project.pbxproj by hand is how projects get corrupted.
    writeConfig();
    write('ios/Runner.xcodeproj/project.pbxproj', 'ORIGINAL');
    fix();
    expect(read('ios/Runner.xcodeproj/project.pbxproj'), 'ORIGINAL');
  });
}
