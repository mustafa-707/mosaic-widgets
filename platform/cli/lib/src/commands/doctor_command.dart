import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:hw_core/hw_core.dart';

class DoctorCommand extends Command {
  @override
  final name = 'doctor';
  @override
  final description = 'Validates the project setup and configuration.';

  @override
  Future<void> run() async {
    print('Checking home_widget.yaml...');
    final configFile = File('home_widget.yaml');
    if (!configFile.existsSync()) {
      print('✗ home_widget.yaml not found.');
      return;
    }
    print('✓ home_widget.yaml found.');

    try {
      final config = HWConfig.fromYaml(await configFile.readAsString());
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

    final iosExtension = Directory('ios/HomeWidgetExtension');
    if (iosExtension.existsSync()) {
      print('✓ iOS HomeWidgetExtension found.');
    } else {
      print(
        '! iOS HomeWidgetExtension not found. iOS widgets will not be generated.',
      );
    }

    print('Doctor check complete.');
  }
}
