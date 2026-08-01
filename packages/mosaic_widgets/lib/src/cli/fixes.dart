import 'dart:io';

import 'package:mosaic_widgets/src/core/core.dart';
import 'package:path/path.dart' as p;

/// One repair `doctor --fix` applied, for reporting back to the developer.
class AppliedFix {
  /// What changed, phrased as a completed action.
  final String message;

  /// Project-relative path that was written, when a file changed.
  final String? path;

  const AppliedFix(this.message, {this.path});

  @override
  String toString() => message;
}

/// Repairs the setup problems that have a single unambiguous correct answer.
///
/// Deliberately narrow: anything needing a judgement call, or an Xcode project
/// mutation (adding a target, adding a file to a target), is left to `doctor` to
/// report. Editing `project.pbxproj` by hand is how projects get corrupted, and
/// a wrong guess about a developer's identifiers is worse than a clear message.
///
/// Returns the fixes applied, in the order applied.
List<AppliedFix> applyFixes(MosaicConfig config, String projectRoot) {
  final applied = <AppliedFix>[];

  String path(String rel) => p.join(projectRoot, rel);

  applied.addAll(
      _fixSupportsRtl(path('android/app/src/main/AndroidManifest.xml')));

  // These two rewrite mosaic.yaml, so everything after them must see the
  // corrected values — otherwise the entitlements below would be written with
  // the old, invalid App Group and `--fix` would need running twice.
  applied.addAll(_fixAndroidPackage(config, projectRoot));
  applied.addAll(_fixAppGroupPrefix(config, projectRoot));
  final reloaded = _reload(projectRoot) ?? config;

  applied.addAll(_fixEntitlements(reloaded, projectRoot));
  applied.addAll(_fixLiveActivityPlist(reloaded, projectRoot));

  return applied;
}

/// Adds `android:supportsRtl="true"` so generated start/end gravity mirrors.
List<AppliedFix> _fixSupportsRtl(String manifestPath) {
  final file = File(manifestPath);
  if (!file.existsSync()) return const [];
  var xml = file.readAsStringSync();

  if (RegExp(r'android:supportsRtl\s*=\s*"true"').hasMatch(xml)) {
    return const [];
  }
  if (RegExp(r'android:supportsRtl\s*=\s*"false"').hasMatch(xml)) {
    // Explicitly disabled: that may be deliberate, so leave it and let doctor
    // keep advising.
    return const [];
  }

  // Insert on the <application> tag, matching its existing indentation.
  final m =
      RegExp(r'(<application\b)([^>]*?)(/?>)', dotAll: true).firstMatch(xml);
  if (m == null) return const [];
  xml = xml.replaceRange(
    m.start,
    m.end,
    '${m.group(1)}${m.group(2)}\n        android:supportsRtl="true"${m.group(3)}',
  );
  file.writeAsStringSync(xml);
  return [
    const AppliedFix(
      'Added android:supportsRtl="true" so layouts mirror in RTL locales',
      path: 'android/app/src/main/AndroidManifest.xml',
    ),
  ];
}

/// Rewrites `android_package` to the project's real `applicationId`.
///
/// The gradle file is the source of truth: it decides where Kotlin actually
/// compiles to, so the config is what has to move.
List<AppliedFix> _fixAndroidPackage(MosaicConfig config, String projectRoot) {
  for (final name in const ['build.gradle.kts', 'build.gradle']) {
    final gradle = File(p.join(projectRoot, 'android/app', name));
    if (!gradle.existsSync()) continue;
    final m = RegExp(r'''applicationId\s*=?\s*["']([^"']+)["']''')
        .firstMatch(gradle.readAsStringSync());
    final actual = m?.group(1);
    if (actual == null || actual == config.app.androidPackage) return const [];

    final configFile = _configFile(projectRoot);
    if (configFile == null) return const [];
    final yaml = configFile.readAsStringSync();
    final rewritten = yaml.replaceFirstMapped(
      RegExp(r'(android_package:\s*)(\S+)'),
      (m) => '${m.group(1)}$actual',
    );
    if (rewritten == yaml) return const [];
    configFile.writeAsStringSync(rewritten);
    return [
      AppliedFix(
        'Set android_package to "$actual" to match applicationId in $name',
        path: p.relative(configFile.path, from: projectRoot),
      ),
    ];
  }
  return const [];
}

/// Prefixes `ios_app_group` with `group.`, which iOS requires.
List<AppliedFix> _fixAppGroupPrefix(MosaicConfig config, String projectRoot) {
  final group = config.app.iosAppGroup;
  if (group.startsWith('group.')) return const [];

  final configFile = _configFile(projectRoot);
  if (configFile == null) return const [];
  final yaml = configFile.readAsStringSync();
  final rewritten = yaml.replaceFirstMapped(
    RegExp(r'(ios_app_group:\s*)(\S+)'),
    (m) => '${m.group(1)}group.${m.group(2)}',
  );
  if (rewritten == yaml) return const [];
  configFile.writeAsStringSync(rewritten);
  return [
    AppliedFix(
      'Prefixed ios_app_group with "group." → group.$group',
      path: p.relative(configFile.path, from: projectRoot),
    ),
  ];
}

/// Creates or repairs the two entitlements files so both list the App Group.
///
/// Xcode still has to enable the capability for signing, but having the file
/// with the right group is the half that silently breaks data sharing.
List<AppliedFix> _fixEntitlements(MosaicConfig config, String projectRoot) {
  final group = config.app.iosAppGroup;
  if (!group.startsWith('group.')) return const []; // Fixed on the next run.

  final targets = {
    'ios/Runner/Runner.entitlements': 'ios/Runner',
    'ios/HomeWidgetExtension/HomeWidgetExtension.entitlements':
        'ios/HomeWidgetExtension',
  };

  final applied = <AppliedFix>[];
  for (final entry in targets.entries) {
    final dir = Directory(p.join(projectRoot, entry.value));
    if (!dir.existsSync()) continue;

    final file = File(p.join(projectRoot, entry.key));
    if (!file.existsSync()) {
      file.writeAsStringSync(_entitlementsPlist(group));
      applied.add(AppliedFix(
        'Created ${entry.key} listing App Group "$group"',
        path: entry.key,
      ));
      continue;
    }

    final content = file.readAsStringSync();
    if (content.contains(group)) continue;

    final injected = _addGroupToEntitlements(content, group);
    if (injected == null) continue; // Unrecognised shape: leave it alone.
    file.writeAsStringSync(injected);
    applied.add(AppliedFix(
      'Added App Group "$group" to ${entry.key}',
      path: entry.key,
    ));
  }
  return applied;
}

/// Adds `NSSupportsLiveActivities` when the project declares live activities.
List<AppliedFix> _fixLiveActivityPlist(
    MosaicConfig config, String projectRoot) {
  if (config.liveActivities.isEmpty) return const [];
  final file = File(p.join(projectRoot, 'ios/Runner/Info.plist'));
  if (!file.existsSync()) return const [];
  final content = file.readAsStringSync();
  if (content.contains('NSSupportsLiveActivities')) return const [];

  final closing = content.lastIndexOf('</dict>');
  if (closing < 0) return const [];
  file.writeAsStringSync(content.replaceRange(
    closing,
    closing,
    '\t<key>NSSupportsLiveActivities</key>\n\t<true/>\n',
  ));
  return const [
    AppliedFix(
      'Added NSSupportsLiveActivities so Live Activities can start',
      path: 'ios/Runner/Info.plist',
    ),
  ];
}

String _entitlementsPlist(String group) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>$group</string>
	</array>
</dict>
</plist>
''';

/// Inserts [group] into an existing entitlements plist.
///
/// Returns null when the file's shape is not recognised, so an unusual
/// hand-rolled plist is reported by doctor rather than rewritten badly.
String? _addGroupToEntitlements(String content, String group) {
  const key = '<key>com.apple.security.application-groups</key>';
  final keyAt = content.indexOf(key);
  if (keyAt >= 0) {
    final arrayAt = content.indexOf('<array>', keyAt);
    if (arrayAt < 0) return null;
    final insertAt = arrayAt + '<array>'.length;
    return content.replaceRange(
        insertAt, insertAt, '\n\t\t<string>$group</string>');
  }

  final closing = content.lastIndexOf('</dict>');
  if (closing < 0) return null;
  return content.replaceRange(
    closing,
    closing,
    '\t$key\n\t<array>\n\t\t<string>$group</string>\n\t</array>\n',
  );
}

File? _configFile(String projectRoot) {
  for (final name in const ['mosaic.yaml', 'home_widget.yaml']) {
    final f = File(p.join(projectRoot, name));
    if (f.existsSync()) return f;
  }
  return null;
}

/// Re-reads `mosaic.yaml` after a fix rewrote it. Returns null when it is
/// absent or no longer parses, so callers fall back to the config they have.
MosaicConfig? _reload(String projectRoot) {
  final f = _configFile(projectRoot);
  if (f == null) return null;
  try {
    return MosaicConfig.fromYaml(f.readAsStringSync());
  } catch (_) {
    return null;
  }
}
