// A command-line tool: stdout is its user interface, so `print` is the
// intended output mechanism rather than a stray debug statement.
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'build_command.dart' show resolveConfigFile;

String widgetTemplate(String name) => '''
import 'package:mosaic_widgets/dsl.dart';

MosaicDefinition build$name() {
  return MosaicDefinition(
    name: "$name",
    width: 2,
    height: 2,
    root: MContainer(
      background: const MColor.hex("#111111"),
      radius: 16,
      padding: const MInsets.all(12),
      child: MColumn([
        const MText("$name Widget", style: MTextStyle(bold: true, size: 16)),
        // Push a value for this key from the app with
        // MosaicBridge.saveString('subtitle', ...).
        MText(MBind("subtitle"), style: const MTextStyle(size: 12, opacity: 0.7)),
      ]),
    ),
  );
}
''';

/// The YAML block to add under `widgets:` for [name] at [entry].
String widgetConfigSnippet(String name, String entry) => '''
  - name: $name
    entry: $entry
''';

/// Mosaic derives the builder name as `build<Name>`, so the widget name has to
/// be usable as the tail of a Dart identifier. Returns null when [name] is fine.
String? widgetNameProblem(String name) {
  if (name.isEmpty) return 'Widget name is required.';
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(name)) {
    return 'Widget name "$name" is not usable: Mosaic generates '
        '`build$name()`, so the name must start with a letter and contain '
        'only letters, digits, and underscores. Try PascalCase, e.g. '
        '"${_toPascal(name)}".';
  }
  if (name[0].toUpperCase() != name[0]) {
    return 'Widget name "$name" should be PascalCase so the generated '
        '`build$name()` reads as a function name — try '
        '"${name[0].toUpperCase()}${name.substring(1)}".';
  }
  return null;
}

String _toPascal(String s) {
  final parts =
      s.split(RegExp(r'[^A-Za-z0-9]+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'MyWidget';
  return parts.map((w) => w[0].toUpperCase() + w.substring(1)).join();
}

/// Picks the directory for a new widget from where existing entries live, so a
/// project that keeps widgets somewhere other than `lib/home_widgets` gets its
/// new file alongside the others.
String widgetsDirFor(String? configContent) {
  const fallback = 'lib/home_widgets';
  if (configContent == null) return fallback;
  final entries = RegExp(r'^\s*entry:\s*(\S+)', multiLine: true)
      .allMatches(configContent)
      .map((m) => m.group(1)!)
      .where((e) => e.endsWith('.dart'))
      .toList();
  if (entries.isEmpty) return fallback;
  // Most common parent wins, so one oddly-placed entry does not decide it.
  final counts = <String, int>{};
  for (final e in entries) {
    final dir = p.dirname(e);
    counts[dir] = (counts[dir] ?? 0) + 1;
  }
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

/// A Live Activity scaffold: lock-screen presentation plus Dynamic Island.
String liveActivityTemplate(String name) => '''
import 'package:mosaic_widgets/dsl.dart';

/// Android has no Dynamic Island, so `dynamicIsland` is ignored there and the
/// `lockScreen` tree is rendered as an ongoing notification instead.
MosaicLiveActivity build$name() {
  return MosaicLiveActivity(
    name: "$name",
    lockScreen: MContainer(
      background: const MColor.hex("#111111"),
      padding: const MInsets.all(12),
      child: MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
        const MText("$name", style: MTextStyle(bold: true, size: 14)),
        MText(MBind("status"), style: const MTextStyle(size: 12)),
        MProgressBar(value: MBind("progress"), max: 100),
      ]),
    ),
    dynamicIsland: MDynamicIsland(
      compactLeading: const MText("●", style: MTextStyle(size: 12)),
      compactTrailing: MText(MBind("progress"), style: const MTextStyle(size: 12)),
      // Shown when another activity shares the island, so keep it to a glyph.
      minimal: const MText("●", style: MTextStyle(size: 12)),
      expanded: MExpanded(
        center: MText(MBind("status"), style: const MTextStyle(size: 14)),
      ),
    ),
  );
}
''';

/// A Control scaffold — iOS 18 Control Center / Android Quick Settings tile.
String controlTemplate(String name) => '''
import 'package:mosaic_widgets/dsl.dart';

MControl build$name() {
  return MControl(
    name: "$name",
    kind: MControlKind.toggle,
    label: "$name",
    sfSymbol: "power",
    // Add androidIcon once you have a drawable for it — it must live in
    // res/drawable*, not res/mipmap (where the launcher icon is).
    // androidIcon: "ic_flashlight",
    // A toggle reflects this bound bool; it must match the action's key.
    valueKey: "${name.toLowerCase()}_on",
    // Flipped entirely on-device, so it works with the app closed.
    action: const MToggleAction("${name.toLowerCase()}_on"),
  );
}
''';

/// The YAML block for a live activity or control at [entry].
String namedEntrySnippet(String name, String entry) => '''
  - name: $name
    entry: $entry
''';

class AddWidgetCommand extends Command {
  @override
  final name = 'add';
  @override
  final description = 'Adds a widget, live activity or control definition.';

  AddWidgetCommand() {
    addSubcommand(AddWidgetSubCommand());
    addSubcommand(AddLiveActivitySubCommand());
    addSubcommand(AddControlSubCommand());
  }
}

/// Shared behaviour for the non-widget scaffolds.
abstract class _AddNamedCommand extends Command {
  /// Top-level key in `mosaic.yaml` this entry belongs under.
  String get configKey;

  /// Suffix for the created file, e.g. `.live.dart`.
  String get fileSuffix;

  /// Default directory when no sibling entries exist to follow.
  String get defaultDir;

  /// Human name used in messages, e.g. `live activity`.
  String get label;

  String template(String name);

  _AddNamedCommand() {
    argParser.addOption('dir', help: 'Directory for the new file.');
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) throw UsageException('A name is required.', usage);
    final entryName = rest.first;
    final problem = widgetNameProblem(entryName);
    if (problem != null) throw UsageException(problem, usage);

    final configFile = resolveConfigFile();
    final configContent = (configFile?.existsSync() ?? false)
        ? configFile!.readAsStringSync()
        : null;

    final dir = (argResults!['dir'] as String?) ?? defaultDir;
    final filePath = p.join(dir, '${entryName.toLowerCase()}$fileSuffix');
    final file = File(filePath);
    if (file.existsSync()) {
      print('$filePath already exists.');
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(template(entryName));
    print('Created $filePath');

    final snippet = namedEntrySnippet(entryName, filePath);
    if (configContent == null) {
      print('No mosaic.yaml found — run `mosaic_cli init`, then add under '
          '`$configKey:`:');
      print(snippet);
      return;
    }
    if (RegExp('^\\s*-\\s*name:\\s*$entryName\\s*\$', multiLine: true)
        .hasMatch(configContent)) {
      print('${configFile!.path} already declares "$entryName" — left as is.');
      return;
    }

    final updated = insertUnderKey(configContent, configKey, snippet);
    if (updated == null) {
      print('Add the following under `$configKey:` in ${configFile!.path}:');
      print(snippet);
      return;
    }
    await configFile!.writeAsString(updated);
    print('Registered $label "$entryName" in ${configFile.path}');
    print('Next: run `mosaic_cli build`.');
  }
}

class AddLiveActivitySubCommand extends _AddNamedCommand {
  @override
  final name = 'live-activity';
  @override
  final description =
      'Adds a Live Activity (iOS Dynamic Island / Android Live Update).';
  @override
  String get invocation => 'mosaic_cli add live-activity <Name>';
  @override
  String get configKey => 'live_activities';
  @override
  String get fileSuffix => '.live.dart';
  @override
  String get defaultDir => 'lib/live_activities';
  @override
  String get label => 'live activity';
  @override
  String template(String name) => liveActivityTemplate(name);
}

class AddControlSubCommand extends _AddNamedCommand {
  @override
  final name = 'control';
  @override
  final description =
      'Adds a Control (iOS Control Center / Android Quick Settings tile).';
  @override
  String get invocation => 'mosaic_cli add control <Name>';
  @override
  String get configKey => 'controls';
  @override
  String get fileSuffix => '.control.dart';
  @override
  String get defaultDir => 'lib/controls';
  @override
  String get label => 'control';
  @override
  String template(String name) => controlTemplate(name);
}

class AddWidgetSubCommand extends Command {
  @override
  final name = 'widget';
  @override
  final description = 'Adds a new widget definition.';

  @override
  String get invocation => 'mosaic_cli add widget <Name>';

  AddWidgetSubCommand() {
    argParser.addOption('dir',
        help: 'Directory for the new widget file.\n'
            '(defaults to where existing entries live)');
    argParser.addFlag('register',
        defaultsTo: true,
        help: 'Add the widget to mosaic.yaml as well as creating the file.');
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw UsageException('Widget name is required.', usage);
    }
    final widgetName = rest.first;
    final problem = widgetNameProblem(widgetName);
    if (problem != null) throw UsageException(problem, usage);

    final configFile = resolveConfigFile();
    final configContent = configFile?.existsSync() ?? false
        ? configFile!.readAsStringSync()
        : null;

    final dir = (argResults!['dir'] as String?) ?? widgetsDirFor(configContent);
    final fileName = '${widgetName.toLowerCase()}.widget.dart';
    final filePath = p.join(dir, fileName);

    final file = File(filePath);
    if (file.existsSync()) {
      print('Widget file $filePath already exists.');
      return;
    }

    // Without this the command died with a raw PathNotFoundException on any
    // project whose widget directory did not already exist.
    await file.parent.create(recursive: true);
    await file.writeAsString(widgetTemplate(widgetName));
    print('Created $filePath');

    final snippet = widgetConfigSnippet(widgetName, filePath);
    final register = argResults!['register'] as bool;

    if (!register || configContent == null) {
      if (configContent == null) {
        print('No mosaic.yaml found — run `mosaic_cli init` first, then add:');
      } else {
        print('Add the following under `widgets:` in ${configFile!.path}:');
      }
      print(snippet);
      return;
    }

    if (RegExp('^\\s*-\\s*name:\\s*$widgetName\\s*\$', multiLine: true)
        .hasMatch(configContent)) {
      print('${configFile!.path} already declares "$widgetName" — left as is.');
      return;
    }

    final updated = insertWidgetEntry(configContent, snippet);
    if (updated == null) {
      print('Could not find a `widgets:` list in ${configFile!.path}. Add:');
      print(snippet);
      return;
    }
    await configFile!.writeAsString(updated);
    print('Registered "$widgetName" in ${configFile.path}');
    print('Next: run `mosaic_cli build`.');
  }
}

/// Appends [snippet] to the `widgets:` list in [yaml].
///
/// Returns null when no `widgets:` key is present, so the caller can fall back
/// to printing the snippet rather than writing a malformed file.
String? insertWidgetEntry(String yaml, String snippet) =>
    insertUnderKey(yaml, 'widgets', snippet, createIfMissing: false);

/// Appends [snippet] to the top-level [key]'s list in [yaml].
///
/// With [createIfMissing] the key is appended to the file when absent, which is
/// what `add live-activity` and `add control` need: `live_activities:` and
/// `controls:` are optional and usually not in a freshly generated config.
/// Returns null when the key is absent and may not be created, so the caller can
/// print the snippet rather than write a malformed file.
String? insertUnderKey(
  String yaml,
  String key,
  String snippet, {
  bool createIfMissing = true,
}) {
  final match = RegExp('^$key:[ \\t]*\$', multiLine: true).firstMatch(yaml);
  if (match == null) {
    if (!createIfMissing) return null;
    final sep = yaml.endsWith('\n') ? '' : '\n';
    return '$yaml$sep\n$key:\n${snippet.trimRight()}\n';
  }

  final lines = yaml.split('\n');
  // Line index of the `widgets:` key.
  final startLine = yaml.substring(0, match.start).split('\n').length - 1;

  // The list ends at the first later line that starts a new top-level key.
  var end = lines.length;
  for (var i = startLine + 1; i < lines.length; i++) {
    final l = lines[i];
    if (l.trim().isEmpty) continue;
    if (!l.startsWith(' ') && !l.startsWith('\t')) {
      end = i;
      break;
    }
  }
  // Keep any blank lines that separated this block from the next key.
  var insertAt = end;
  while (insertAt > startLine + 1 && lines[insertAt - 1].trim().isEmpty) {
    insertAt--;
  }

  lines.insertAll(insertAt, snippet.trimRight().split('\n'));
  return lines.join('\n');
}
