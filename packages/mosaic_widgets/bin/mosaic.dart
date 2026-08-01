// A command-line tool: stdout is its user interface, so `print` is the
// intended output mechanism rather than a stray debug statement.
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mosaic_widgets/src/cli/commands/init_command.dart';
import 'package:mosaic_widgets/src/cli/commands/add_widget_command.dart';
import 'package:mosaic_widgets/src/cli/commands/build_command.dart';
import 'package:mosaic_widgets/src/cli/commands/doctor_command.dart';
import 'package:mosaic_widgets/src/cli/commands/clean_command.dart';
import 'package:mosaic_widgets/src/cli/commands/list_command.dart';
import 'package:mosaic_widgets/src/cli/version.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner(
    'mosaic_cli',
    'Native iOS and Android home-screen widgets from one Dart DSL.\n'
        '\nTypical first run:\n'
        '  mosaic_cli init                    # detect identifiers, write mosaic.yaml\n'
        '  mosaic_cli add widget News         # scaffold and register a widget\n'
        '  mosaic_cli build                   # generate native code\n'
        '  mosaic_cli doctor --fix            # repair setup, report the rest',
  )
    ..addCommand(InitCommand())
    ..addCommand(AddWidgetCommand())
    ..addCommand(BuildCommand())
    ..addCommand(ListCommand())
    ..addCommand(DoctorCommand())
    ..addCommand(CleanCommand());

  runner.argParser.addFlag(
    'version',
    negatable: false,
    help: 'Print the mosaic_cli version.',
  );

  try {
    // Handled here rather than as a command so `--version` works alone.
    final parsed = runner.argParser.parse(args);
    if (parsed['version'] as bool) {
      print('mosaic_cli $packageVersion');
      return;
    }
    await runner.run(args);
  } catch (e) {
    stderr.writeln(e);
    exit(1);
  }
}
