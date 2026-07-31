import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// The Android `applicationId` declared by the host project, or null when it
/// cannot be read.
///
/// Both Groovy and Kotlin DSL forms appear in the wild: `applicationId "x"` and
/// `applicationId = "x"`.
String? detectAndroidPackage(String projectRoot) {
  for (final name in ['build.gradle.kts', 'build.gradle']) {
    final f = File(p.join(projectRoot, 'android', 'app', name));
    if (!f.existsSync()) continue;
    final m = RegExp(r'''applicationId\s*=?\s*["']([^"']+)["']''')
        .firstMatch(f.readAsStringSync());
    if (m != null) return m.group(1);
  }
  return null;
}

/// The iOS bundle identifier of the Runner target, or null when it cannot be
/// read.
///
/// `project.pbxproj` also carries `PRODUCT_BUNDLE_IDENTIFIER` entries for the
/// test target, so anything ending in `.RunnerTests` is skipped. Values
/// containing `$(` are build-setting references we cannot resolve statically.
String? detectIosBundleId(String projectRoot) {
  final f = File(
    p.join(projectRoot, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
  );
  if (!f.existsSync()) return null;
  for (final m in RegExp(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);')
      .allMatches(f.readAsStringSync())) {
    final value = m.group(1)!.trim().replaceAll('"', '');
    if (value.endsWith('.RunnerTests') || value.contains(r'$(')) continue;
    return value;
  }
  return null;
}

/// Builds the initial `mosaic.yaml`.
///
/// [androidPackage] and [bundleId] are the detected identifiers; when either is
/// null a placeholder is written and flagged in a comment, so a developer is
/// never left with a config that looks correct but points at `com.example.app`.
String initialConfig({String? androidPackage, String? bundleId}) {
  const placeholder = 'com.example.app';
  final android = androidPackage ?? placeholder;
  final ios = bundleId ?? androidPackage ?? placeholder;
  final detected = androidPackage != null || bundleId != null;

  final header = detected
      ? '# Identifiers detected from your Android and iOS projects.'
      : '# Could not read your project identifiers — replace '
          '$placeholder below.';

  return '''
$header
app:
  bundle_id: $ios
  android_package: $android
  # Create this App Group on both the app and widget-extension targets in
  # Xcode; the widget cannot read the app's data without it.
  ios_app_group: group.$ios.widgets

widgets:
  # Add one entry per widget. `mosaic_cli add widget <Name>` does this for you.
  #
  # - name: Profile
  #   entry: lib/home_widgets/profile.widget.dart
  #   label: Your Profile          # optional — title in the widget picker
  #   ios: { families: [systemSmall, systemMedium] }   # optional
''';
}

class InitCommand extends Command {
  @override
  final name = 'init';
  @override
  final description =
      'Initializes the home widget configuration and scaffolding.';

  @override
  Future<void> run() async {
    final configFile = File('mosaic.yaml');
    if (configFile.existsSync()) {
      print('mosaic.yaml already exists.');
    } else {
      final androidPackage = detectAndroidPackage('.');
      final bundleId = detectIosBundleId('.');
      await configFile.writeAsString(
        initialConfig(androidPackage: androidPackage, bundleId: bundleId),
      );
      print('Created mosaic.yaml');
      if (androidPackage != null) {
        print('  android_package: $androidPackage (from build.gradle)');
      }
      if (bundleId != null) {
        print('  bundle_id: $bundleId (from project.pbxproj)');
      }
      if (androidPackage == null && bundleId == null) {
        print('  Could not detect your identifiers — edit mosaic.yaml before '
            'building.');
      }
    }

    final widgetsDir = Directory('lib/home_widgets');
    if (!widgetsDir.existsSync()) {
      await widgetsDir.create(recursive: true);
      print('Created lib/home_widgets directory');
    }

    print('');
    print('Next: `mosaic_cli add widget <Name>`, then `mosaic_cli build`.');
    print('iOS also needs a Widget Extension target — see docs/IOS_SETUP.md.');
  }
}
