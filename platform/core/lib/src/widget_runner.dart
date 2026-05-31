import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'config.dart';

class WidgetRunner {
  final HWConfig config;
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

    return '''
import 'dart:convert';
import 'package:hw_flutter/hw_dsl.dart';
${imports.join('\n')}

void main() {
  final definitions = <HWDefinition>[];
  ${calls.join('\n')}
  
  print(jsonEncode(definitions.map((e) => e.toJson()).toList()));
}
''';
  }

  Future<List<Map<String, dynamic>>> run() async {
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
    // The output might contain logs from other things, so we should look for the JSON.
    // For now, assume the last line is the JSON if it starts with [.
    final lines = output.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw Exception('No output from widget runner');

    final jsonStr = lines.last;
    return List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
  }
}
