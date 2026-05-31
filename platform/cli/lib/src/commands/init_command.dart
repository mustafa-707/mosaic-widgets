import 'dart:io';
import 'package:args/command_runner.dart';

class InitCommand extends Command {
  @override
  final name = 'init';
  @override
  final description =
      'Initializes the home widget configuration and scaffolding.';

  @override
  Future<void> run() async {
    final configFile = File('home_widget.yaml');
    if (configFile.existsSync()) {
      print('home_widget.yaml already exists.');
    } else {
      await configFile.writeAsString('''
app:
  bundle_id: com.example.app
  android_package: com.example.app
  ios_app_group: group.com.example.app.widgets

widgets:
  # - name: ProfileWidget
  #   entry: lib/home_widgets/profile.widget.dart
  #   android:
  #     min_sdk: 21
  #     sizes: [small, medium]
  #   ios:
  #     families: [systemSmall, systemMedium]
''');
      print('Created home_widget.yaml');
    }

    final widgetsDir = Directory('lib/home_widgets');
    if (!widgetsDir.existsSync()) {
      await widgetsDir.create(recursive: true);
      print('Created lib/home_widgets directory');
    }
  }
}
