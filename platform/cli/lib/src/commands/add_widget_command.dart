import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

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

    await file.writeAsString('''
import 'package:flutter/hw_dsl.dart';

HWDefinition build$widgetName() {
  return HWDefinition(
    name: "$widgetName",
    root: HWContainer(
      background: HWColor.hex("#111111"),
      radius: 16,
      child: HWPadding(
        HWInsets.all(12),
        HWColumn([
          HWText("$widgetName Widget", style: HWTextStyle(bold: true, size: 16)),
          HWText(HWBind("subtitle"), style: HWTextStyle(size: 12, opacity: 0.7)),
        ]),
      ),
    ),
  );
}
''');

    print('Created $filePath');
    print('Please add the following to your home_widget.yaml:');
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
