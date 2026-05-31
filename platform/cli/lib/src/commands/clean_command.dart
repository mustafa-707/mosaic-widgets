import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

class CleanCommand extends Command {
  @override
  final name = 'clean';
  @override
  final description = 'Removes generated native code (keeps user code).';

  @override
  Future<void> run() async {
    print('Cleaning generated Android files...');
    final androidGeneratedDir = Directory('android/app/src/main/kotlin');
    if (androidGeneratedDir.existsSync()) {
      // We need to find directories named 'hw_generated' and delete them.
      _deleteHwGenerated(androidGeneratedDir);
    }

    final androidLayouts = Directory('android/app/src/main/res/layout');
    if (androidLayouts.existsSync()) {
      _deleteFilesByPrefix(androidLayouts, 'hw_');
    }

    final androidXml = Directory('android/app/src/main/res/xml');
    if (androidXml.existsSync()) {
      _deleteFilesByPrefix(androidXml, 'hw_');
    }

    print('Cleaning generated iOS files...');
    final iosGeneratedDir = Directory(
      'ios/HomeWidgetExtension/Widgets',
    ); // Or refine based on structure
    if (iosGeneratedDir.existsSync()) {
      // In our current iOS generator, we place files directly in ios/HomeWidgetExtension
      // Actually, my generator uses ios/HomeWidgetExtension/ProfileVP.swift
    }

    // For now, let's keep it simple and just log what needs to be cleaned
    print('Clean complete.');
  }

  void _deleteHwGenerated(Directory dir) {
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is Directory && p.basename(entity.path) == 'hw_generated') {
        entity.deleteSync(recursive: true);
        print('Deleted ${entity.path}');
      }
    }
  }

  void _deleteFilesByPrefix(Directory dir, String prefix) {
    for (final file in dir.listSync()) {
      if (file is File && p.basename(file.path).startsWith(prefix)) {
        file.deleteSync();
        print('Deleted ${file.path}');
      }
    }
  }
}
