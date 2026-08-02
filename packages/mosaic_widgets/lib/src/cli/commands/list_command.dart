// A command-line tool: stdout is its user interface, so `print` is the
// intended output mechanism rather than a stray debug statement.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mosaic_widgets/src/core/core.dart';
import 'package:path/path.dart' as p;

import 'build_command.dart' show resolveConfigFile;

/// Shows everything the project declares and whether it is wired up.
///
/// Answers the questions `mosaic.yaml` alone does not: is the builder function
/// actually there, has native code been generated for it, and which refresh
/// sources feed it.
class ListCommand extends Command {
  @override
  final name = 'list';
  @override
  final description =
      'Lists declared widgets, live activities and controls, with their status.';

  @override
  String get invocation => 'dart run mosaic_widgets:mosaic list';

  ListCommand() {
    argParser.addFlag('paths',
        negatable: false,
        help: 'Show the generated file paths for each entry.');
  }

  @override
  Future<void> run() async {
    final configFile = resolveConfigFile();
    if (configFile == null) {
      print(
          'No mosaic.yaml found. Run `dart run mosaic_widgets:mosaic init` first.');
      return;
    }

    final MosaicConfig config;
    try {
      config = MosaicConfig.fromYaml(await configFile.readAsString());
    } catch (e) {
      print('Could not read ${configFile.path}: $e');
      exitCode = 1;
      return;
    }

    final showPaths = argResults!['paths'] as bool;
    final root = Directory.current.path;
    final pkgPath = config.app.androidPackage.replaceAll('.', '/');

    void section(String title, List<({String name, String entry})> items,
        {required String Function(String name) androidArtifact,
        required String Function(String name) iosArtifact}) {
      if (items.isEmpty) return;
      print('');
      print('$title (${items.length})');
      for (final item in items) {
        final safe = sanitizeIdentifier(item.name);
        final entry = File(p.join(root, item.entry));
        final hasEntry = entry.existsSync();
        // The builder name is derived from the config name, so a mismatch here
        // is the single most common reason a build fails.
        final hasBuilder = hasEntry &&
            RegExp(r'(?:^|\n)\s*(?:[\w<>,\s?]+\s+)?build' +
                    RegExp.escape(item.name) +
                    r'\s*\(')
                .hasMatch(entry.readAsStringSync());
        final android = File(p.join(root, androidArtifact(safe)));
        final ios = File(p.join(root, iosArtifact(safe)));

        final flags = [
          if (!hasEntry) 'entry missing',
          if (hasEntry && !hasBuilder) 'build${item.name}() missing',
          if (!android.existsSync()) 'android not generated',
          if (!ios.existsSync()) 'ios not generated',
        ];
        final status = flags.isEmpty ? '✓' : '✗';
        print('  $status ${item.name}'
            '${flags.isEmpty ? '' : '  — ${flags.join(', ')}'}');
        if (showPaths) {
          print('      entry:   ${item.entry}');
          print('      android: ${androidArtifact(safe)}');
          print('      ios:     ${iosArtifact(safe)}');
        }
      }
    }

    print('${configFile.path} — ${config.app.androidPackage}');

    section(
      'Widgets',
      [for (final w in config.widgets) (name: w.name, entry: w.entry)],
      androidArtifact: (s) =>
          'android/app/src/main/kotlin/$pkgPath/mosaic_generated/${s}Provider.kt',
      iosArtifact: (s) => 'ios/HomeWidgetExtension/$s.swift',
    );

    section(
      'Live activities',
      [
        for (final la in config.liveActivities) (name: la.name, entry: la.entry)
      ],
      androidArtifact: (s) =>
          'android/app/src/main/res/layout/hw_la_${s.toLowerCase()}.xml',
      iosArtifact: (s) => 'ios/HomeWidgetExtension/${s}LiveActivity.swift',
    );

    section(
      'Controls',
      [for (final c in config.controls) (name: c.name, entry: c.entry)],
      androidArtifact: (s) =>
          'android/app/src/main/kotlin/$pkgPath/mosaic_generated/${s}TileService.kt',
      iosArtifact: (s) => 'ios/HomeWidgetExtension/${s}Control.swift',
    );

    if (config.refresh.isNotEmpty) {
      print('');
      print('Refresh callbacks (${config.refresh.length})');
      for (final entry in config.refresh.entries) {
        final count = entry.value.length;
        print('  • ${entry.key} — $count '
            'source${count == 1 ? '' : 's'}');
      }
    }

    if (config.strings.isNotEmpty) {
      print('');
      final locales = config.strings.keys.toList();
      print('Locales (${locales.length}): ${locales.join(', ')}'
          '  — default "${locales.first}", ${config.stringKeys.length} key(s)');
    }

    if (config.widgets.isEmpty &&
        config.liveActivities.isEmpty &&
        config.controls.isEmpty) {
      print('');
      print(
          'Nothing declared yet. Try `dart run mosaic_widgets:mosaic add widget <Name>`.');
    }
  }
}
