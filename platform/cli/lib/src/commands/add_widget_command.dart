import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

String widgetTemplate(String name) => '''
import 'package:mosaic/dsl.dart';

MosaicDefinition build$name() {
  return MosaicDefinition(
    name: "$name",
    root: MContainer(
      background: MColor.hex("#111111"),
      radius: 16,
      child: MPadding(
        MInsets.all(12),
        MColumn([
          MText("$name Widget", style: MTextStyle(bold: true, size: 16)),
          MText(MBind("subtitle"), style: MTextStyle(size: 12, opacity: 0.7)),
        ]),
      ),
    ),
  );
}
''';

class AddWidgetCommand extends Command {
  @override
  final name = 'add';
  @override
  final description = 'Adds a new widget definition.';

  AddWidgetCommand() {
    addSubcommand(AddWidgetSubCommand());
  }
}

class AddWidgetSubCommand extends Command {
  @override
  final name = 'widget';
  @override
  final description = 'Adds a new widget definition.';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Widget name is required.', usage);
    }
    final widgetName = argResults!.rest.first;
    final fileName = '${widgetName.toLowerCase()}.widget.dart';
    final filePath = p.join('lib/home_widgets', fileName);

    final file = File(filePath);
    if (file.existsSync()) {
      print('Widget file $filePath already exists.');
      return;
    }

    await file.writeAsString(widgetTemplate(widgetName));

    print('Created $filePath');
    print('Please add the following to your mosaic.yaml:');
    print('''
  - name: $widgetName
    entry: $filePath
    android:
      min_sdk: 21
      sizes: [small, medium]
    ios:
      families: [systemSmall, systemMedium]
''');
  }
}
