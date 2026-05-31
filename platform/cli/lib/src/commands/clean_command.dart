import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// Deletes every *.swift file directly under [extensionDir] whose first line
/// contains the sentinel `// MOSAIC-GENERATED`. Hand-written files are kept.
/// Does nothing if the directory does not exist.
void cleanIosGenerated(Directory extensionDir) {
  if (!extensionDir.existsSync()) return;
  for (final entity in extensionDir.listSync()) {
    if (entity is File && p.extension(entity.path) == '.swift') {
      final lines = entity.readAsLinesSync();
      if (lines.isNotEmpty && lines.first.contains('// MOSAIC-GENERATED')) {
        entity.deleteSync();
        print('Deleted ${entity.path}');
      }
    }
  }
}

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
      // We need to find directories named 'mosaic_generated' and delete them.
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
    cleanIosGenerated(Directory('ios/HomeWidgetExtension'));

    print('Clean complete.');
  }

  void _deleteHwGenerated(Directory dir) {
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is Directory && p.basename(entity.path) == 'mosaic_generated') {
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
