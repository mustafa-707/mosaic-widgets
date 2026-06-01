import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'config.dart';

class WidgetRunner {
  final MosaicConfig config;
  final String projectRoot;

  WidgetRunner({required this.config, required this.projectRoot});

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

    return '''
import 'dart:convert';
import 'package:mosaic/dsl.dart';
${imports.join('\n')}

void main() {
  final definitions = <MosaicDefinition>[];
  ${calls.join('\n')}
  final liveActivities = <MosaicLiveActivity>[];
  ${laCalls.join('\n')}

  final payload = {
    'widgets': definitions.map((e) => e.toJson()).toList(),
    'liveActivities': liveActivities.map((e) => e.toJson()).toList(),
  };
  print('<<<MOSAIC_IR>>>' + jsonEncode(payload) + '<<<END_MOSAIC_IR>>>');
}
''';
  }

  /// Runs the generated runner script ONCE and returns both the widget IR
  /// and the live-activity IR parsed from its output.
  Future<
      ({
        List<Map<String, dynamic>> widgets,
        List<Map<String, dynamic>> liveActivities
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
    );
  }

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

  static List<Map<String, dynamic>> parseLiveActivities(String stdout) {
    final decoded = _decodePayload(stdout);
    if (decoded is! Map) {
      // Legacy bare-list form has no live activities.
      return const [];
    }
    return List<Map<String, dynamic>>.from(
        decoded['liveActivities'] as List? ?? const []);
  }
}
