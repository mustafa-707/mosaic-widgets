// A command-line tool: stdout is its user interface, so `print` is the
// intended output mechanism rather than a stray debug statement.
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mosaic_widgets/src/core/core.dart';
import 'package:mosaic_widgets/src/android/android.dart';
import 'package:mosaic_widgets/src/ios/ios.dart';
import 'package:path/path.dart' as p;

import '../validate.dart';

/// Deletes generated files left behind by a widget that is no longer declared.
///
/// Renaming or removing a widget in `mosaic.yaml` regenerates the manifest
/// without its receiver, so the old provider, layout, and Swift view become
/// unreferenced — but `build` never removed them, so they accumulated in the
/// repo and the APK until someone ran `clean`.
///
/// Only files that carry a generated sentinel on their first line are
/// considered, so a hand-written file that happens to match the naming pattern
/// is never deleted. Returns the project-relative paths removed.
List<String> pruneOrphanedGeneratedFiles(
  String projectRoot,
  MosaicConfig config,
) {
  String safe(String n) => sanitizeIdentifier(n);

  // Every basename the current config legitimately generates.
  final liveNames = <String>{
    for (final w in config.widgets) safe(w.name),
    for (final la in config.liveActivities) safe(la.name),
    for (final c in config.controls) safe(c.name),
  };

  final removed = <String>[];

  bool isGenerated(File f) {
    try {
      // Not just the first line: AAPT requires the XML declaration to be the
      // very first bytes, so generated resource files carry the sentinel on
      // line 2. Kotlin and Swift carry it on line 1.
      return f
          .readAsLinesSync()
          .take(3)
          .any((l) => l.contains('MOSAIC-GENERATED'));
    } on FileSystemException {
      return false;
    }
  }

  /// [nameOf] extracts the widget name a file belongs to, or null when the file
  /// is shared runtime rather than per-widget.
  void sweep(String dir, String? Function(String basename) nameOf) {
    final d = Directory(p.join(projectRoot, dir));
    if (!d.existsSync()) return;
    for (final f in d.listSync().whereType<File>()) {
      final owner = nameOf(p.basename(f.path));
      if (owner == null || liveNames.contains(owner)) continue;
      if (!isGenerated(f)) continue;
      f.deleteSync();
      removed.add(p.join(dir, p.basename(f.path)));
    }
  }

  final pkgPath = config.app.androidPackage.replaceAll('.', '/');
  sweep('android/app/src/main/kotlin/$pkgPath/mosaic_generated', (b) {
    for (final suffix in [
      'Provider.kt',
      'ConfigActivity.kt',
      'TileService.kt'
    ]) {
      if (b.endsWith(suffix)) return b.substring(0, b.length - suffix.length);
    }
    return null; // MosaicData.kt, MosaicPlugin.kt, … are shared runtime.
  });

  sweep('android/app/src/main/res/layout', (b) {
    if (!b.startsWith('hw_') || !b.endsWith('.xml')) return null;
    final stem = b.substring(3, b.length - 4);
    // hw_la_<name> belongs to a live activity; both are matched
    // case-insensitively because layout names are lowercased.
    var bare = stem.startsWith('la_') ? stem.substring(3) : stem;
    // hw_<name>_compact is the small-size tree of <name>, not a widget of its
    // own. Without this it is classified as an orphan on every build; that
    // happens to be survivable only because pruning runs before generation
    // rewrites it, which is not a property worth depending on.
    if (bare.endsWith('_compact')) {
      bare = bare.substring(0, bare.length - '_compact'.length);
    }
    for (final n in liveNames) {
      if (n.toLowerCase() == bare) return n;
    }
    return bare; // Unmatched: nothing live owns it.
  });

  sweep('android/app/src/main/res/xml', (b) {
    if (!b.startsWith('hw_') || !b.endsWith('_info.xml')) return null;
    final bare = b.substring(3, b.length - '_info.xml'.length);
    for (final n in liveNames) {
      if (n.toLowerCase() == bare) return n;
    }
    return bare;
  });

  sweep('ios/HomeWidgetExtension', (b) {
    if (!b.endsWith('.swift')) return null;
    final stem = b.substring(0, b.length - 6);
    // Shared runtime files are named Mosaic*/HomeWidget*; per-widget views are
    // named exactly after the definition.
    if (stem.startsWith('Mosaic') || stem.startsWith('HomeWidget')) return null;
    if (liveNames.contains(stem)) return null;
    // Live activities and controls add their own suffixes.
    for (final suffix in ['LiveActivity', 'Control']) {
      if (stem.endsWith(suffix)) {
        return stem.substring(0, stem.length - suffix.length);
      }
    }
    return stem;
  });

  return removed;
}

/// Removes AndroidManifest entries Mosaic generated previously that no longer
/// correspond to generated classes, returning the cleaned manifest.
///
/// Manifest automation only ever appended, so renaming a widget — or the
/// `hw_generated` → `mosaic_generated` package move — left receivers pointing
/// at classes that no longer exist. Android still registers those providers,
/// and the launcher fails to instantiate them, which surfaces to the user as
/// "Can't load widget" on every widget in the app.
///
/// Only entries under Mosaic's own generated packages are considered, so
/// hand-written components are never touched.
String pruneStaleMosaicManifestEntries(
  String content,
  String androidPackage, {
  required Set<String> keepClasses,
}) {
  final generatedPackages = [
    '$androidPackage.mosaic_generated.',
    // Pre-rename package: its classes are never generated again.
    '$androidPackage.hw_generated.',
  ];

  bool isStale(String className) {
    if (!generatedPackages.any(className.startsWith)) return false;
    return !keepClasses.contains(className);
  }

  for (final tag in ['receiver', 'activity', 'service']) {
    final pattern = RegExp(
      '\\s*<$tag\\s+android:name="([^"]+)"[\\s\\S]*?</$tag>',
    );
    content = content.replaceAllMapped(pattern, (match) {
      final className = match.group(1)!;
      return isStale(className) ? '' : match.group(0)!;
    });
  }
  return content;
}

/// Builds the `<receiver>` AndroidManifest entry for a widget.
///
/// The class name and the `@xml/...` resource reference are derived with
/// [sanitizeIdentifier] so they match exactly what the Android generator
/// emits: the provider class `${sanitizeIdentifier(name)}Provider` and the
/// info file `hw_${sanitizeIdentifier(name).toLowerCase()}_info.xml`. Using
/// the raw name here would, for a name like "My Widget", produce a dangling
/// `@xml/hw_my widget_info` reference (with a space) and a non-existent
/// `My WidgetProvider` class, silently breaking the widget.
String receiverTag(String androidPackage, String widgetName, {String? label}) {
  final safe = sanitizeIdentifier(widgetName);
  final receiverName = '$androidPackage.mosaic_generated.${safe}Provider';
  final infoRes = 'hw_${safe.toLowerCase()}_info';
  // Without android:label the widget picker falls back to the application
  // label, so every widget appears under the app's name (and Flutter's icon).
  final labelAttr = ' android:label="${_xmlAttr(label ?? widgetName)}"';
  return '''
        <receiver android:name="$receiverName" android:exported="true"$labelAttr>
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/$infoRes" />
        </receiver>''';
}

/// Escapes a value for use inside a double-quoted XML attribute.
String _xmlAttr(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Builds the `<activity>` AndroidManifest entry for a configurable widget's
/// configuration Activity. Mirrors [receiverTag]: the class name is derived
/// with [sanitizeIdentifier] so it matches the Android generator's emitted
/// `${sanitizeIdentifier(name)}ConfigActivity`. The activity declares the
/// `APPWIDGET_CONFIGURE` action so the OS launches it after the widget is
/// placed, and must be exported so the launcher can start it.
String configActivityTag(String androidPackage, String widgetName) {
  final safe = sanitizeIdentifier(widgetName);
  final activityName = '$androidPackage.mosaic_generated.${safe}ConfigActivity';
  return '''
        <activity android:name="$activityName" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_CONFIGURE" />
            </intent-filter>
        </activity>''';
}

/// Builds the `<service>` AndroidManifest entry for the shared Mosaic
/// RemoteViewsService that backs every HWListView. A collection RemoteViews
/// service MUST declare `android:permission="android.permission.BIND_REMOTEVIEWS"`
/// (and be exported) or the system refuses to bind it and the list renders
/// empty. Mirrors [receiverTag]: the class name is the generator's fixed
/// `MosaicListService` under `mosaic_generated`.
String listServiceTag(String androidPackage) {
  final serviceName = '$androidPackage.mosaic_generated.MosaicListService';
  return '''
        <service
            android:name="$serviceName"
            android:exported="false"
            android:permission="android.permission.BIND_REMOTEVIEWS" />''';
}

/// Builds the `<service>` AndroidManifest entry for a Mosaic control's Quick
/// Settings tile. A [TileService] (API 24+) MUST be exported and guarded with
/// `android.permission.BIND_QUICK_SETTINGS_TILE`, expose the `QS_TILE`
/// intent-filter and carry the `ACTIVE_TILE` meta-data, or the system refuses
/// to surface it. The class name is derived with [sanitizeIdentifier] so it
/// matches the generator's emitted `${sanitizeIdentifier(name)}TileService`.
///
/// NOTE: Quick Settings tiles are USER-ADDED — Android does not auto-place
/// them. The `android:label` is the name the user sees in the QS edit screen.
String tileServiceTag(
  String androidPackage,
  String controlName,
  String label,
) {
  final safe = sanitizeIdentifier(controlName);
  final serviceName = '$androidPackage.mosaic_generated.${safe}TileService';
  final safeLabel = xmlEscape(label);
  return '''
        <service
            android:name="$serviceName"
            android:exported="true"
            android:label="$safeLabel"
            android:permission="android.permission.BIND_QUICK_SETTINGS_TILE">
            <intent-filter>
                <action android:name="android.service.quicksettings.action.QS_TILE" />
            </intent-filter>
            <meta-data
                android:name="android.service.quicksettings.ACTIVE_TILE"
                android:value="false" />
        </service>''';
}

/// True when any [definitions] node tree contains an `HWListView`, gating
/// declaration of the [listServiceTag] in the manifest.
bool definitionsUseListView(List<IRDefinition> definitions) {
  bool walk(IRNode node) {
    if (node.type == 'HWListView') return true;
    for (final value in node.data.values) {
      if (value is Map && value['__type'] is String) {
        if (walk(IRNode.fromJson(value.cast<String, dynamic>()))) return true;
      } else if (value is List) {
        for (final e in value) {
          if (e is Map && e['__type'] is String) {
            if (walk(IRNode.fromJson(e.cast<String, dynamic>()))) return true;
          }
        }
      }
    }
    return false;
  }

  return definitions.any((d) => walk(d.root));
}

/// Builds the deep-link `<intent-filter>` for MainActivity. The [scheme] is
/// [xmlEscape]d so a value containing XML metacharacters (e.g. `&`) cannot
/// corrupt the manifest.
String deepLinkFilter(String scheme) {
  final safeScheme = xmlEscape(scheme);
  return '''
            <intent-filter>$deepLinkFilterMarker
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="$safeScheme" />
            </intent-filter>''';
}

/// Marks the deep-link filter as ours, so changing `deep_link_scheme` replaces
/// it instead of leaving the previous scheme registered alongside the new one.
const deepLinkFilterMarker = ' <!-- MOSAIC-GENERATED -->';

/// Strips any previously generated deep-link `<intent-filter>` from [manifest].
///
/// Only filters carrying [deepLinkFilterMarker] are touched — a hand-written
/// filter for an app's own https links or a second custom scheme is left alone.
String stripGeneratedDeepLinkFilters(String manifest) => manifest.replaceAll(
      RegExp(
        r'[ \t]*<intent-filter>[ \t]*<!--\s*MOSAIC-GENERATED\s*-->'
        r'.*?</intent-filter>\n?',
        dotAll: true,
      ),
      '',
    );

/// Resolves the Mosaic config file. Prefers `mosaic.yaml`; falls back to the
/// deprecated `home_widget.yaml` (with a warning) when only that exists.
/// Returns null when neither is present.
File? resolveConfigFile() {
  final mosaic = File('mosaic.yaml');
  if (mosaic.existsSync()) return mosaic;
  final legacy = File('home_widget.yaml');
  if (legacy.existsSync()) {
    print('home_widget.yaml is deprecated; rename to mosaic.yaml');
    return legacy;
  }
  return null;
}

/// Returns a progress message for [count] controls, or null when there are none.
///
/// Used by [BuildCommand.run] to conditionally print the controls count.
String? controlsProgressMessage(int count) {
  if (count == 0) return null;
  return 'Generating $count controls...';
}

class BuildCommand extends Command {
  @override
  final name = 'build';
  @override
  final description = 'Generates native code for home widgets.';

  @override
  Future<void> run() async {
    final configFile = resolveConfigFile();
    if (configFile == null) {
      throw Exception(
          'mosaic.yaml not found. Run "dart run mosaic_widgets:mosaic init" first.');
    }

    print('Loading configuration...');
    final config = MosaicConfig.fromYaml(await configFile.readAsString());

    print('Executing widget definitions...');
    final runner = WidgetRunner(
      config: config,
      projectRoot: Directory.current.path,
    );
    final ir = await runner.runAll();

    final irDefinitions =
        ir.widgets.map((e) => IRDefinition.fromJson(e)).toList();
    final liveActivities = ir.liveActivities;
    final controls = ir.controls;

    // Fail here rather than let Gradle discover a missing drawable minutes into
    // a native build.
    final assetProblems = [
      ...validateDrawables(irDefinitions, Directory.current.path,
          controls: controls),
      ...validateStringKeys(irDefinitions, config),
      ...validateLaunchUrls(irDefinitions, config),
      ...validateControls(controls),
    ];
    final fatalAssets = assetProblems.where((e) => e.fatal).toList();
    if (fatalAssets.isNotEmpty) {
      throw Exception(
        'Widget assets are missing:\n'
        '${fatalAssets.map((e) => '  - ${e.message}').join('\n')}',
      );
    }
    for (final advisory in assetProblems.where((e) => !e.fatal)) {
      print('⚠️  ${advisory.message}');
    }

    if (liveActivities.isNotEmpty) {
      print('Generating ${liveActivities.length} live activities...');
    }

    final ctlMsg = controlsProgressMessage(controls.length);
    if (ctlMsg != null) print(ctlMsg);

    // Before regenerating, drop files belonging to widgets that are no longer
    // declared — otherwise a rename leaves the old provider and layout behind
    // for good. Named explicitly rather than silently, since this deletes.
    final orphans = pruneOrphanedGeneratedFiles(runner.projectRoot, config);
    for (final path in orphans) {
      print('Removed orphaned generated file: $path');
    }

    print('Generating Android code...');
    final androidGenerator = AndroidGenerator(
      config: config,
      definitions: irDefinitions,
      liveActivities: liveActivities,
      controls: controls,
    );
    await androidGenerator.generate(runner.projectRoot);

    print('Generating iOS code...');
    final iosGenerator = IosGenerator(
      config: config,
      definitions: irDefinitions,
      liveActivities: liveActivities,
      controls: controls,
    );
    await iosGenerator.generate(runner.projectRoot);

    print('Automating Android configuration...');
    await _automateAndroidManifest(
        runner.projectRoot, config, irDefinitions, controls);

    print('Syncing assets...');
    await _syncAssets(runner.projectRoot, config);

    print('Build complete!');
    print('\n🚀 NEXT STEPS FOR iOS:');
    print(
      '1. Open Xcode and add the generated .swift files to your Widget Extension target.',
    );
    print(
      '2. Ensure App Groups are configured for both the app and the extension.',
    );
    print('3. See docs/IOS_SETUP.md for detailed instructions.');
  }

  Future<void> _syncAssets(String projectRoot, MosaicConfig config) async {
    final assetsDir = Directory(p.join(projectRoot, 'assets', 'widgets'));
    if (!assetsDir.existsSync()) return;

    final entities = assetsDir.listSync();
    if (entities.isEmpty) return;

    // Android
    final androidResDir = Directory(
      p.join(projectRoot, 'android', 'app', 'src', 'main', 'res', 'drawable'),
    );
    if (!androidResDir.existsSync()) androidResDir.createSync(recursive: true);

    // iOS (Simplified for now, just copying to Runner folder. Real iOS might need xcassets)
    final iosRunnerDir = Directory(p.join(projectRoot, 'ios', 'Runner'));

    for (final entity in entities) {
      if (entity is File) {
        final fileName =
            p.basename(entity.path).toLowerCase().replaceAll('-', '_');

        // Copy to Android
        await entity.copy(p.join(androidResDir.path, fileName));

        // Copy to iOS
        if (iosRunnerDir.existsSync()) {
          await entity.copy(p.join(iosRunnerDir.path, fileName));
        }

        print('Synced asset: $fileName');
      }
    }
  }

  Future<void> _automateAndroidManifest(
    String projectRoot,
    MosaicConfig config,
    List<IRDefinition> definitions,
    List<Map<String, dynamic>> controls,
  ) async {
    final manifestFile = File(
      p.join(
        projectRoot,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    );
    if (!manifestFile.existsSync()) {
      print(
        'Warning: AndroidManifest.xml not found at ${manifestFile.path}. Skipping automation.',
      );
      return;
    }

    var content = await manifestFile.readAsString();
    final androidPackage = config.app.androidPackage;

    // Mosaic owns its generated entries, so drop them all and re-add them
    // below. Keeping existing ones meant metadata changes — a new picker label
    // or description — never reached a manifest that already had the receiver.
    // It also clears entries left by a renamed or removed widget, or by the old
    // hw_generated package, which Android reports as "Can't load widget".
    final pruned = pruneStaleMosaicManifestEntries(
      content,
      androidPackage,
      keepClasses: const {},
    );
    if (pruned != content) {
      print('Refreshed Mosaic entries in AndroidManifest.xml');
      content = pruned;
    }

    for (final def in definitions) {
      final safe = sanitizeIdentifier(def.name);
      final receiverName = '$androidPackage.mosaic_generated.${safe}Provider';
      final widgetConfig = config.widgets
          .where((w) => w.name == def.name)
          .cast<MosaicWidgetConfig?>()
          .firstWhere((w) => true, orElse: () => null);
      final tag = receiverTag(
        androidPackage,
        def.name,
        label: widgetConfig?.displayName,
      );

      if (!content.contains(receiverName)) {
        if (content.contains('</application>')) {
          content = content.replaceFirst(
            '</application>',
            '$tag\n    </application>',
          );
          print('Added receiver for ${def.name} to AndroidManifest.xml');
        }
      }

      // Configurable widgets (definition carries params) also declare a
      // configuration Activity with the APPWIDGET_CONFIGURE intent filter.
      if (def.params.isNotEmpty) {
        final configName =
            '$androidPackage.mosaic_generated.${safe}ConfigActivity';
        if (!content.contains(configName) &&
            content.contains('</application>')) {
          content = content.replaceFirst(
            '</application>',
            '${configActivityTag(androidPackage, def.name)}\n    </application>',
          );
          print('Added config activity for ${def.name} to AndroidManifest.xml');
        }
      }
    }

    // Declaring refresh sources means the widget process makes network calls.
    // Flutter injects INTERNET into the debug manifest only, so without this a
    // release build silently fetches nothing.
    if (config.refresh.isNotEmpty &&
        !content.contains('android.permission.INTERNET')) {
      final manifestOpen = RegExp(r'<manifest[^>]*>');
      final match = manifestOpen.firstMatch(content);
      if (match != null) {
        content = content.replaceFirst(
          match.group(0)!,
          '${match.group(0)!}\n'
          '    <uses-permission android:name="android.permission.INTERNET" />',
        );
        print('Added INTERNET permission to AndroidManifest.xml '
            '(required by refresh: sources)');
      }
    }

    // Android TV channels need a provider permission and an install receiver.
    // Only for projects that declared a channel: WRITE_EPG_DATA on a phone-only
    // app is a permission the developer never asked for.
    if (config.tvChannels.isNotEmpty) {
      const perm = 'com.android.providers.tv.permission.WRITE_EPG_DATA';
      if (!content.contains(perm)) {
        final manifestOpen = RegExp(r'<manifest[^>]*>');
        final match = manifestOpen.firstMatch(content);
        if (match != null) {
          content = content.replaceFirst(
            match.group(0)!,
            '${match.group(0)!}\n'
            '    <uses-permission android:name="$perm" />',
          );
          print('Added WRITE_EPG_DATA permission to AndroidManifest.xml '
              '(required by tv_channels:)');
        }
      }

      final receiver = '$androidPackage.mosaic_generated.MosaicTvInitReceiver';
      if (!content.contains(receiver) && content.contains('</application>')) {
        content = content.replaceFirst(
          '</application>',
          '        <receiver\n'
              '            android:name="$receiver"\n'
              '            android:exported="true"> <!-- MOSAIC-GENERATED -->\n'
              '            <intent-filter>\n'
              '                <action android:name="android.media.tv.action.INITIALIZE_PROGRAMS" />\n'
              '                <category android:name="android.intent.category.DEFAULT" />\n'
              '            </intent-filter>\n'
              '        </receiver>\n'
              '    </application>',
        );
        print('Registered MosaicTvInitReceiver in AndroidManifest.xml');
      }
    }

    // Declare the shared RemoteViews collection service when any widget uses a
    // list. It needs BIND_REMOTEVIEWS or the system will not bind it.
    if (definitionsUseListView(definitions)) {
      final serviceName = '$androidPackage.mosaic_generated.MosaicListService';
      if (!content.contains(serviceName) &&
          content.contains('</application>')) {
        content = content.replaceFirst(
          '</application>',
          '${listServiceTag(androidPackage)}\n    </application>',
        );
        print('Added MosaicListService to AndroidManifest.xml');
      }
    }

    // Declare one Quick Settings <service> per Mosaic control. A TileService
    // (API 24+) must be exported and guarded by BIND_QUICK_SETTINGS_TILE. Tiles
    // are user-added; the OS will not auto-place them.
    for (final control in controls) {
      final name = (control['name'] as String?) ?? 'Control';
      final label = (control['label'] as String?) ?? name;
      final safe = sanitizeIdentifier(name);
      final serviceName = '$androidPackage.mosaic_generated.${safe}TileService';
      if (!content.contains(serviceName) &&
          content.contains('</application>')) {
        content = content.replaceFirst(
          '</application>',
          '${tileServiceTag(androidPackage, name, label)}\n    </application>',
        );
        print('Added Quick Settings tile for $name to AndroidManifest.xml');
      }
    }

    // Add Deep Link intent filter to MainActivity
    final scheme = config.app.deepLinkScheme;
    final safeScheme = xmlEscape(scheme);
    final intentFilter = deepLinkFilter(scheme);

    // Drop our previous filter first, so a changed scheme replaces rather than
    // accumulates. A hand-written filter for the same scheme still counts as
    // already-present and is left as the developer wrote it.
    content = stripGeneratedDeepLinkFilters(content);

    if (!content.contains('android:scheme="$safeScheme"')) {
      // Find MainActivity
      final activityPattern = RegExp(
        r'<activity[^>]*android:name="\.MainActivity"[^>]*>',
      );
      final match = activityPattern.firstMatch(content);
      if (match != null) {
        final activityTag = match.group(0)!;
        content = content.replaceFirst(
          activityTag,
          '$activityTag\n$intentFilter',
        );
        print('Added deep link intent filter to MainActivity');
      }
    }

    await manifestFile.writeAsString(content);
  }
}
