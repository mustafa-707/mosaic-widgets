import 'dart:io';

import 'package:mosaic_cli/src/validate.dart';
import 'package:mosaic_core/mosaic_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Without `MosaicPlugin` registered, every `MosaicBridge` call throws
/// `MissingPluginException` at runtime. Only the iOS side of that was checked,
/// so a project could pass `doctor` with a completely dead bridge on Android.
MosaicConfig configFor(String androidPackage) => MosaicConfig.fromYaml('''
app:
  bundle_id: com.acme.app
  android_package: $androidPackage
  ios_app_group: group.com.acme.app.widgets
widgets: []
''');

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('mosaic_wiring_'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String rel, String contents) {
    final f = File(p.join(root.path, rel));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(contents);
  }

  List<Problem> run({String androidPackage = 'com.acme.app'}) =>
      validateProject(configFor(androidPackage), root.path);

  Iterable<Problem> mainActivityProblems(List<Problem> ps) =>
      ps.where((e) => e.message.contains('MainActivity'));

  const wired = '''
package com.acme.app

import io.flutter.embedding.android.FlutterActivity
import com.acme.app.mosaic_generated.MosaicPlugin

class MainActivity : FlutterActivity() {
    private val mosaic = MosaicPlugin()
}
''';

  const unwired = '''
package com.acme.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
''';

  test('an unwired MainActivity is fatal and names the file', () {
    write('android/app/src/main/kotlin/com/acme/app/MainActivity.kt', unwired);
    final problems = mainActivityProblems(run()).toList();
    expect(problems, hasLength(1));
    expect(problems.single.fatal, isTrue);
    expect(problems.single.message, contains('MainActivity.kt'));
    expect(problems.single.message, contains('MissingPluginException'));
    expect(problems.single.message, contains('ANDROID_SETUP.md'));
  });

  test('a wired MainActivity produces no problem', () {
    write('android/app/src/main/kotlin/com/acme/app/MainActivity.kt', wired);
    expect(mainActivityProblems(run()), isEmpty);
  });

  test('a MainActivity moved off the package path is still checked', () {
    // Found by search rather than only by package path, so relocating the file
    // cannot silently skip the check.
    write(
        'android/app/src/main/kotlin/com/other/place/MainActivity.kt', unwired);
    expect(mainActivityProblems(run()), hasLength(1));
  });

  test('a Java MainActivity is checked too', () {
    write('android/app/src/main/java/com/acme/app/MainActivity.java',
        'class MainActivity {}');
    expect(mainActivityProblems(run()), hasLength(1));
  });

  test('a project with no MainActivity is skipped, not failed', () {
    // A package may legitimately have no Android host at all.
    expect(mainActivityProblems(run()), isEmpty);
  });

  test('the package from mosaic.yaml is used to locate the file', () {
    write('android/app/src/main/kotlin/com/other/id/MainActivity.kt', wired);
    expect(mainActivityProblems(run(androidPackage: 'com.other.id')), isEmpty);
  });

  group('iOS widget extension target', () {
    Iterable<Problem> targetProblems(List<Problem> ps) =>
        ps.where((e) => e.message.contains('app-extension') ||
            e.message.contains('nothing named HomeWidgetExtension'));

    test('generated Swift with no extension target is fatal', () {
      // `build` creates this directory, so its presence proved nothing — the
      // app compiled, shipped no .appex, and no widget ever appeared.
      write('ios/HomeWidgetExtension/Profile.swift', '// generated\n');
      write('ios/Runner.xcodeproj/project.pbxproj',
          'productType = "com.apple.product-type.application";');
      final problems = targetProblems(run()).toList();
      expect(problems, hasLength(1));
      expect(problems.single.fatal, isTrue);
      expect(problems.single.message, contains('no .appex'));
      expect(problems.single.message, contains('IOS_SETUP.md'));
    });

    test('a real extension target satisfies the check', () {
      write('ios/HomeWidgetExtension/Profile.swift', '// generated\n');
      write('ios/Runner.xcodeproj/project.pbxproj', '''
productType = "com.apple.product-type.application";
productType = "com.apple.product-type.app-extension";
name = HomeWidgetExtension;
''');
      expect(targetProblems(run()), isEmpty);
    });

    test('an extension target under another name is reported', () {
      // A target compiling some other folder leaves Mosaic's Swift orphaned.
      write('ios/HomeWidgetExtension/Profile.swift', '// generated\n');
      write('ios/Runner.xcodeproj/project.pbxproj', '''
productType = "com.apple.product-type.app-extension";
name = SomeOtherExtension;
''');
      final problems = targetProblems(run()).toList();
      expect(problems, hasLength(1));
      expect(problems.single.message, contains('must use that folder'));
    });

    test('no iOS project at all is skipped', () {
      expect(targetProblems(run()), isEmpty);
    });
  });

  group('identifiers', () {
    MosaicConfig configWith({String? appGroup, String? androidPackage}) =>
        MosaicConfig.fromYaml('''
app:
  bundle_id: com.acme.app
  android_package: ${androidPackage ?? 'com.acme.app'}
  ios_app_group: ${appGroup ?? 'group.com.acme.app.widgets'}
widgets: []
''');

    test('an App Group without the group. prefix is fatal', () {
      // iOS rejects any other form: UserDefaults(suiteName:) returns nil and
      // every read yields nothing, with no error on either side.
      final problems = validateProject(
          configWith(appGroup: 'com.acme.app.widgets'), root.path);
      final hit = problems.where((e) => e.message.contains('must start with'));
      expect(hit, hasLength(1));
      expect(hit.single.fatal, isTrue);
      expect(hit.single.message, contains('group.com.acme.app.widgets'));
    });

    test('a correctly prefixed App Group passes', () {
      expect(
        validateProject(configWith(), root.path)
            .where((e) => e.message.contains('must start with')),
        isEmpty,
      );
    });

    test('a package that disagrees with applicationId is fatal', () {
      // The manifest would point at a package holding no generated classes,
      // which the launcher reports as "Can't load widget" on every widget.
      write('android/app/build.gradle.kts',
          'defaultConfig {\n  applicationId = "com.real.app"\n}');
      final problems = validateProject(
          configWith(androidPackage: 'com.wrong.pkg'), root.path);
      final hit = problems.where((e) => e.message.contains('applicationId'));
      expect(hit, hasLength(1));
      expect(hit.single.fatal, isTrue);
      expect(hit.single.message, contains('com.real.app'));
    });

    test('a matching package passes', () {
      write('android/app/build.gradle.kts',
          'defaultConfig {\n  applicationId = "com.acme.app"\n}');
      expect(
        validateProject(configWith(), root.path)
            .where((e) => e.message.contains('applicationId')),
        isEmpty,
      );
    });

    test('the Groovy DSL form is read too', () {
      write('android/app/build.gradle',
          "defaultConfig {\n  applicationId 'com.real.app'\n}");
      expect(
        validateProject(configWith(androidPackage: 'com.wrong.pkg'), root.path)
            .where((e) => e.message.contains('applicationId')),
        hasLength(1),
      );
    });

    test('no gradle file means no package claim to check', () {
      expect(
        validateProject(configWith(androidPackage: 'com.anything'), root.path)
            .where((e) => e.message.contains('applicationId')),
        isEmpty,
      );
    });
  });

  group('RTL support', () {
    Iterable<Problem> rtl(List<Problem> ps) =>
        ps.where((e) => e.message.contains('supportsRtl'));

    test('supportsRtl="false" is advisory, not fatal', () {
      // An LTR-only app is a legitimate choice.
      write('android/app/src/main/AndroidManifest.xml',
          '<manifest><application android:supportsRtl="false" /></manifest>');
      final problems = rtl(run()).toList();
      expect(problems, hasLength(1));
      expect(problems.single.fatal, isFalse);
    });

    test('an absent supportsRtl is reported', () {
      // Generated layouts use start/end gravity, which Android ignores without
      // the opt-in — and ANDROID_SETUP.md already promised doctor warned here.
      write('android/app/src/main/AndroidManifest.xml',
          '<manifest><application /></manifest>');
      expect(rtl(run()), hasLength(1));
    });

    test('supportsRtl="true" passes', () {
      write('android/app/src/main/AndroidManifest.xml',
          '<manifest><application android:supportsRtl="true" /></manifest>');
      expect(rtl(run()), isEmpty);
    });

    test('no manifest means nothing to check', () {
      expect(rtl(run()), isEmpty);
    });
  });

  group('App Group entitlements', () {
    Iterable<Problem> groupProblems(List<Problem> ps) =>
        ps.where((e) => e.message.contains('App Group'));

    test('a missing entitlements file is fatal, not skipped', () {
      // Skipping absent files hid the commonest state: never configured. The
      // widget then reads an empty suite and renders blank, silently.
      write('ios/Runner/AppDelegate.swift', 'MosaicPlugin.register');
      final problems = groupProblems(run()).toList();
      expect(problems, isNotEmpty);
      expect(problems.first.fatal, isTrue);
      expect(problems.first.message, contains('not '));
    });

    test('an entitlements file omitting the group is fatal', () {
      write('ios/Runner/AppDelegate.swift', 'MosaicPlugin.register');
      write('ios/Runner/Runner.entitlements', '<plist><dict/></plist>');
      write('ios/HomeWidgetExtension/HomeWidgetExtension.entitlements',
          '<plist><dict/></plist>');
      expect(groupProblems(run()).length, 2);
    });

    test('both sides listing the group passes', () {
      const ent = '''
<plist><dict>
<key>com.apple.security.application-groups</key>
<array><string>group.com.acme.app.widgets</string></array>
</dict></plist>''';
      write('ios/Runner/AppDelegate.swift', 'MosaicPlugin.register');
      write('ios/Runner/Runner.entitlements', ent);
      write('ios/HomeWidgetExtension/HomeWidgetExtension.entitlements', ent);
      expect(groupProblems(run()), isEmpty);
    });

    test('a project with no ios/Runner is skipped', () {
      // A Dart-only package has no Runner to configure.
      expect(groupProblems(run()), isEmpty);
    });
  });
}
