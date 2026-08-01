import 'dart:io';

import 'package:mosaic_widgets/src/cli/commands/init_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `init` used to hard-code `com.example.app` for all three identifiers, so
/// every new project started with a config that looked complete but pointed at
/// the wrong package — and a widget that silently reads nothing, because the App
/// Group is derived from the bundle id.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('mosaic_init_'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String rel, String contents) {
    final f = File(p.join(root.path, rel));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(contents);
  }

  group('android package detection', () {
    test('reads applicationId from the Kotlin DSL', () {
      write('android/app/build.gradle.kts', '''
android {
    namespace = "com.acme.greenfield"
    defaultConfig {
        applicationId = "com.acme.greenfield"
    }
}
''');
      expect(detectAndroidPackage(root.path), 'com.acme.greenfield');
    });

    test('reads applicationId from the Groovy DSL', () {
      // Older projects have no `=` and use single quotes.
      write('android/app/build.gradle', '''
android {
    defaultConfig {
        applicationId 'com.legacy.app'
    }
}
''');
      expect(detectAndroidPackage(root.path), 'com.legacy.app');
    });

    test('returns null when there is no gradle file', () {
      expect(detectAndroidPackage(root.path), isNull);
    });
  });

  group('ios bundle id detection', () {
    test('reads the Runner target and skips RunnerTests', () {
      write('ios/Runner.xcodeproj/project.pbxproj', '''
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.acme.greenfield.RunnerTests;
};
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.acme.greenfield;
};
''');
      expect(detectIosBundleId(root.path), 'com.acme.greenfield');
    });

    test('skips unresolvable build-setting references', () {
      write('ios/Runner.xcodeproj/project.pbxproj', r'''
PRODUCT_BUNDLE_IDENTIFIER = $(BUNDLE_ID_PREFIX).app;
PRODUCT_BUNDLE_IDENTIFIER = com.real.app;
''');
      expect(detectIosBundleId(root.path), 'com.real.app');
    });

    test('returns null when there is no pbxproj', () {
      expect(detectIosBundleId(root.path), isNull);
    });
  });

  group('the generated config', () {
    test('uses the detected identifiers and derives the App Group', () {
      final yaml = initialConfig(
        androidPackage: 'com.acme.greenfield',
        bundleId: 'com.acme.greenfield',
      );
      expect(yaml, contains('android_package: com.acme.greenfield'));
      expect(yaml, contains('bundle_id: com.acme.greenfield'));
      expect(
          yaml, contains('ios_app_group: group.com.acme.greenfield.widgets'));
      expect(yaml, isNot(contains('com.example.app')));
    });

    test('falls back to the Android package when only it is known', () {
      // A project without an ios/ directory still gets a coherent config.
      final yaml = initialConfig(androidPackage: 'com.acme.only');
      expect(yaml, contains('bundle_id: com.acme.only'));
    });

    test('says so when nothing could be detected', () {
      final yaml = initialConfig();
      expect(yaml, contains('com.example.app'));
      expect(yaml, contains('Could not read'));
    });

    test('does not advertise the reserved android keys', () {
      // min_sdk/sizes reach no generated output, so the template must not
      // suggest they are needed.
      final yaml = initialConfig(androidPackage: 'com.acme.app');
      expect(yaml, isNot(contains('min_sdk')));
      expect(yaml, isNot(contains('sizes:')));
    });

    test('points at the command that adds widgets', () {
      expect(initialConfig(), contains('add widget'));
    });
  });
}
