import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'config.dart';

/// Generates and executes a temporary Dart runner script that imports every
/// widget and live-activity entry declared in [config], calls each builder
/// function, and prints the collected IR JSON wrapped in
/// `<<<MOSAIC_IR>>>…<<<END_MOSAIC_IR>>>` sentinels.
///
/// The output is then parsed back into structured maps by [parseIrOutput] and
/// [parseLiveActivities], making [WidgetRunner] the bridge between the Dart
/// DSL and the platform-specific code generators.
class WidgetRunner {
  /// The Mosaic project configuration that describes which widgets and live
  /// activities to build.
  final MosaicConfig config;

  /// Absolute path to the Flutter/Dart project root. Used to resolve relative
  /// [MosaicWidgetConfig.entry] paths and as the working directory when
  /// running the generated script.
  final String projectRoot;

  /// Creates a [WidgetRunner] for the given [config] and [projectRoot].
  WidgetRunner({required this.config, required this.projectRoot});

  /// Builds the source code of the temporary Dart runner script.
  ///
  /// The script imports each widget and live-activity entry file using
  /// `file://` URIs, calls the corresponding `build<Name>()` function, and
  /// prints the collected IR payload between sentinel markers so that
  /// [runAll] can extract it from stdout.
  Future<String> buildRunnerScript() async {
    final imports = <String>[];
    final calls = <String>[];

    for (final widget in config.widgets) {
      final absoluteEntry = p.isAbsolute(widget.entry)
          ? widget.entry
          : p.join(projectRoot, widget.entry);

      // We need a way to import this. For a simple CLI, we can use absolute file paths.
      final importPath = p.absolute(absoluteEntry);
      final alias = 'w${config.widgets.indexOf(widget)}';
      imports.add("import 'file://$importPath' as $alias;");

      // Convention: build[WidgetName]
      final funcName = 'build${widget.name}';
      calls.add("definitions.add($alias.$funcName());");
    }

    final laCalls = <String>[];
    for (final la in config.liveActivities) {
      final absoluteEntry = p.isAbsolute(la.entry)
          ? la.entry
          : p.join(projectRoot, la.entry);

      final importPath = p.absolute(absoluteEntry);
      final alias = 'la${config.liveActivities.indexOf(la)}';
      imports.add("import 'file://$importPath' as $alias;");

      // Convention: build[LiveActivityName]
      final funcName = 'build${la.name}';
      laCalls.add("liveActivities.add($alias.$funcName());");
    }

    final ctlCalls = <String>[];
    for (final ctl in config.controls) {
      final absoluteEntry = p.isAbsolute(ctl.entry)
          ? ctl.entry
          : p.join(projectRoot, ctl.entry);

      final importPath = p.absolute(absoluteEntry);
      final alias = 'ctl${config.controls.indexOf(ctl)}';
      imports.add("import 'file://$importPath' as $alias;");

      // Convention: build[ControlName]
      final funcName = 'build${ctl.name}';
      ctlCalls.add("controls.add($alias.$funcName());");
    }

    return '''
import 'dart:convert';
import 'package:mosaic/dsl.dart';
${imports.join('\n')}

void main() {
  final definitions = <MosaicDefinition>[];
  ${calls.join('\n')}
  final liveActivities = <MosaicLiveActivity>[];
  ${laCalls.join('\n')}
  final controls = <MControl>[];
  ${ctlCalls.join('\n')}

  final payload = {
    'widgets': definitions.map((e) => e.toJson()).toList(),
    'liveActivities': liveActivities.map((e) => e.toJson()).toList(),
    'controls': controls.map((e) => e.toJson()).toList(),
  };
  print('<<<MOSAIC_IR>>>' + jsonEncode(payload) + '<<<END_MOSAIC_IR>>>');
}
''';
  }

  /// Runs the generated runner script ONCE and returns the widget IR,
  /// live-activity IR, and control IR parsed from its output.
  Future<
      ({
        List<Map<String, dynamic>> widgets,
        List<Map<String, dynamic>> liveActivities,
        List<Map<String, dynamic>> controls,
      })> runAll() async {
    final tempDir = Directory(p.join(projectRoot, '.dart_tool', 'hw_gen'));
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }

    final scriptFile = File(p.join(tempDir.path, 'runner.dart'));
    final scriptContent = await buildRunnerScript();
    await scriptFile.writeAsString(scriptContent);

    // We need to make sure the runner can find hw_flutter.
    // If we run this from the project root, and the project has hw_flutter as a dependency, it should work.

    final result = await Process.run('dart', [
      'run',
      scriptFile.path,
    ], workingDirectory: projectRoot);

    if (result.exitCode != 0) {
      throw Exception('Failed to run widget runner: ${result.stderr}');
    }

    final output = result.stdout as String;
    return (
      widgets: parseIrOutput(output),
      liveActivities: parseLiveActivities(output),
      controls: parseControls(output),
    );
  }

  /// Runs the generated runner script and returns only the widget IR maps.
  ///
  /// Convenience wrapper around [runAll] that discards the live-activity
  /// results and returns just the `widgets` list.
  Future<List<Map<String, dynamic>>> run() async {
    return (await runAll()).widgets;
  }

  /// Extracts the sentinel-delimited JSON payload from [stdout].
  static dynamic _decodePayload(String stdout) {
    const start = '<<<MOSAIC_IR>>>';
    const end = '<<<END_MOSAIC_IR>>>';
    final s = stdout.indexOf(start);
    final e = stdout.indexOf(end);
    if (s < 0 || e < 0 || e < s) {
      throw Exception(
          'Could not find Mosaic IR markers in widget runner output.\nOutput was:\n$stdout');
    }
    final jsonStr = stdout.substring(s + start.length, e);
    return jsonDecode(jsonStr);
  }

  /// Extracts the widget IR maps from a runner script's [stdout].
  ///
  /// Handles both the legacy bare-list format (a JSON array of widget maps)
  /// and the current envelope format (`{"widgets": [...], "liveActivities": [...]}`).
  static List<Map<String, dynamic>> parseIrOutput(String stdout) {
    final decoded = _decodePayload(stdout);
    // Legacy form: a bare list of widgets.
    if (decoded is List) {
      return List<Map<String, dynamic>>.from(decoded);
    }
    // New form: an object with a `widgets` array.
    return List<Map<String, dynamic>>.from(
        (decoded as Map)['widgets'] as List? ?? const []);
  }

  /// Extracts the live-activity IR maps from a runner script's [stdout].
  ///
  /// Returns an empty list when the payload uses the legacy bare-list format,
  /// which predates live-activity support.
  static List<Map<String, dynamic>> parseLiveActivities(String stdout) {
    final decoded = _decodePayload(stdout);
    if (decoded is! Map) {
      // Legacy bare-list form has no live activities.
      return const [];
    }
    return List<Map<String, dynamic>>.from(
        decoded['liveActivities'] as List? ?? const []);
  }

  /// Extracts the control IR maps from a runner script's [stdout].
  ///
  /// Returns an empty list when the payload uses the legacy bare-list format
  /// or when the `controls` key is absent (both predate control support).
  static List<Map<String, dynamic>> parseControls(String stdout) {
    final decoded = _decodePayload(stdout);
    if (decoded is! Map) {
      // Legacy bare-list form has no controls.
      return const [];
    }
    return List<Map<String, dynamic>>.from(
        decoded['controls'] as List? ?? const []);
  }
}
