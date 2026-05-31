import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:hw_cli/src/commands/init_command.dart';
import 'package:hw_cli/src/commands/add_widget_command.dart';
import 'package:hw_cli/src/commands/build_command.dart';
import 'package:hw_cli/src/commands/doctor_command.dart';
import 'package:hw_cli/src/commands/clean_command.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner('hw_cli', 'Home Widget Generator CLI')
    ..addCommand(InitCommand())
    ..addCommand(AddWidgetCommand())
    ..addCommand(BuildCommand())
    ..addCommand(DoctorCommand())
    ..addCommand(CleanCommand());

  try {
    await runner.run(args);
  } catch (e) {
    stderr.writeln(e);
    exit(1);
  }
}
