import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:hw_core/hw_core.dart';
import 'package:hw_android/hw_android.dart';
import 'package:hw_ios/hw_ios.dart';
import 'package:path/path.dart' as p;

class BuildCommand extends Command {
  @override
  final name = 'build';
  @override
  final description = 'Generates native code for home widgets.';

  @override
  Future<void> run() async {
    final configFile = File('home_widget.yaml');
    if (!configFile.existsSync()) {
      throw Exception('home_widget.yaml not found. Run "hw_cli init" first.');
    }

    print('Loading configuration...');
    final config = HWConfig.fromYaml(await configFile.readAsString());

    print('Executing widget definitions...');
    final runner = WidgetRunner(
      config: config,
      projectRoot: Directory.current.path,
    );
    final irData = await runner.run();

    final irDefinitions = irData.map((e) => IRDefinition.fromJson(e)).toList();

    print('Generating Android code...');
    final androidGenerator = AndroidGenerator(
      config: config,
      definitions: irDefinitions,
    );
    await androidGenerator.generate(runner.projectRoot);

    print('Generating iOS code...');
    final iosGenerator = IosGenerator(
      config: config,
      definitions: irDefinitions,
    );
    await iosGenerator.generate(runner.projectRoot);

    print('Automating Android configuration...');
    await _automateAndroidManifest(runner.projectRoot, config, irDefinitions);

    print('Syncing assets...');
    await _syncAssets(runner.projectRoot, config);

    print('Build complete!');
    print('\n🚀 NEXT STEPS FOR iOS:');
    print(
      '1. Open Xcode and add the generated .swift files to your Widget Extension target.',
    );
    print(
      '2. Ensure App Groups are configured for both the app and the extension.',
    );
    print('3. See DOCS/IOS_SETUP.md for detailed instructions.');
  }

  Future<void> _syncAssets(String projectRoot, HWConfig config) async {
    final assetsDir = Directory(p.join(projectRoot, 'assets', 'widgets'));
    if (!assetsDir.existsSync()) return;

    final entities = assetsDir.listSync();
    if (entities.isEmpty) return;

    // Android
    final androidResDir = Directory(
      p.join(projectRoot, 'android', 'app', 'src', 'main', 'res', 'drawable'),
    );
    if (!androidResDir.existsSync()) androidResDir.createSync(recursive: true);

    // iOS (Simplified for now, just copying to Runner folder. Real iOS might need xcassets)
    final iosRunnerDir = Directory(p.join(projectRoot, 'ios', 'Runner'));

    for (final entity in entities) {
      if (entity is File) {
        final fileName = p
            .basename(entity.path)
            .toLowerCase()
            .replaceAll('-', '_');

        // Copy to Android
        await entity.copy(p.join(androidResDir.path, fileName));

        // Copy to iOS
        if (iosRunnerDir.existsSync()) {
          await entity.copy(p.join(iosRunnerDir.path, fileName));
        }

        print('Synced asset: $fileName');
      }
    }
  }

  Future<void> _automateAndroidManifest(
    String projectRoot,
    HWConfig config,
    List<IRDefinition> definitions,
  ) async {
    final manifestFile = File(
      p.join(
        projectRoot,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    );
    if (!manifestFile.existsSync()) {
      print(
        'Warning: AndroidManifest.xml not found at ${manifestFile.path}. Skipping automation.',
      );
      return;
    }

    var content = await manifestFile.readAsString();
    final androidPackage = config.app.androidPackage;

    for (final def in definitions) {
      final receiverName = '$androidPackage.hw_generated.${def.name}Provider';
      final receiverTag =
          '''
        <receiver android:name="$receiverName" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/hw_${def.name.toLowerCase()}_info" />
        </receiver>''';

      if (!content.contains(receiverName)) {
        if (content.contains('</application>')) {
          content = content.replaceFirst(
            '</application>',
            '$receiverTag\n    </application>',
          );
          print('Added receiver for ${def.name} to AndroidManifest.xml');
        }
      }
    }

    // Add Deep Link intent filter to MainActivity
    final scheme = config.app.deepLinkScheme;
    final intentFilter = '''
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="$scheme" />
            </intent-filter>''';

    if (!content.contains('android:scheme="$scheme"')) {
      // Find MainActivity
      final activityPattern = RegExp(
        r'<activity[^>]*android:name="\.MainActivity"[^>]*>',
      );
      final match = activityPattern.firstMatch(content);
      if (match != null) {
        final activityTag = match.group(0)!;
        content = content.replaceFirst(
          activityTag,
          '$activityTag\n$intentFilter',
        );
        print('Added deep link intent filter to MainActivity');
      }
    }

    await manifestFile.writeAsString(content);
  }
}
