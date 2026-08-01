// A command-line tool: stdout is its user interface, so `print` is the
// intended output mechanism rather than a stray debug statement.
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mosaic_widgets/src/core/core.dart';
import '../fixes.dart';
import '../validate.dart';
import 'build_command.dart' show resolveConfigFile;

class DoctorCommand extends Command {
  @override
  final name = 'doctor';
  @override
  final description = 'Validates the project setup and configuration.';

  DoctorCommand() {
    argParser.addFlag(
      'fix',
      negatable: false,
      help: 'Repair the problems that have one unambiguous answer, then\n'
          're-check. Xcode target changes are never made for you.',
    );
  }

  @override
  Future<void> run() async {
    print('Checking mosaic.yaml...');
    final configFile = resolveConfigFile();
    if (configFile == null) {
      print('✗ mosaic.yaml not found.');
      return;
    }
    print('✓ ${configFile.path} found.');

    try {
      final config = MosaicConfig.fromYaml(await configFile.readAsString());
      print('✓ Configuration is valid.');

      print('Checking widget entries...');
      for (final widget in config.widgets) {
        final entryFile = File(widget.entry);
        if (!entryFile.existsSync()) {
          print(
            '✗ Entry file not found for widget "${widget.name}": ${widget.entry}',
          );
        } else {
          print('✓ Widget "${widget.name}" entry found.');
        }
      }
    } catch (e) {
      print('✗ Configuration error: $e');
    }

    print('Checking native directories...');
    final androidRes = Directory('android/app/src/main/res');
    if (androidRes.existsSync()) {
      print('✓ Android resources found.');
    } else {
      print(
        '! Android resources not found. Android widgets will not be generated.',
      );
    }

    // Only that the generated Swift is on disk — whether an Xcode target
    // actually compiles it is checked under "native wiring" below, because the
    // directory is created by `build` and so proves nothing on its own.
    final iosExtension = Directory('ios/HomeWidgetExtension');
    if (iosExtension.existsSync()) {
      print('✓ iOS HomeWidgetExtension sources present.');
    } else {
      print(
        '! ios/HomeWidgetExtension not found. Run `mosaic_cli build` to '
        'generate the iOS sources.',
      );
    }

    // Setup problems that otherwise surface as a native build failure or, worse,
    // a silently empty widget at runtime.
    print('Checking native wiring...');
    var fatal = false;
    try {
      var config = MosaicConfig.fromYaml(await configFile.readAsString());

      if (argResults!['fix'] as bool) {
        final applied = applyFixes(config, Directory.current.path);
        if (applied.isEmpty) {
          print('Nothing to fix automatically.');
        } else {
          for (final fix in applied) {
            print('🔧 ${fix.message}');
          }
          // A fix may have rewritten mosaic.yaml, so re-read before validating.
          config = MosaicConfig.fromYaml(await configFile.readAsString());
        }
      }

      final problems = validateProject(config, Directory.current.path);
      if (problems.isEmpty) {
        print('✓ App Group, host plugin and refresh sources look correct.');
      }
      for (final problem in problems) {
        print('${problem.fatal ? '✗' : '!'} ${problem.message}');
        fatal |= problem.fatal;
      }
      if (fatal && !(argResults!['fix'] as bool)) {
        print('');
        print('Some of these can be repaired: `mosaic_cli doctor --fix`.');
      }
    } catch (_) {
      // Config errors are already reported above.
    }

    print('Doctor check complete.');
    if (fatal) exitCode = 1;
  }
}
