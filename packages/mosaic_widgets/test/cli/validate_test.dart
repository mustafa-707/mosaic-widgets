import 'dart:io';

import 'package:mosaic_widgets/src/cli/validate.dart';
import 'package:mosaic_widgets/src/core/core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

MosaicConfig config({String refresh = ''}) => MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b.widgets
widgets: []
$refresh
''');

IRDefinition defWithIcon(String drawable) => IRDefinition.fromJson({
      'name': 'W',
      'root': {
        '__type': 'HWColumn',
        'children': [
          {'__type': 'HWIcon', 'sfSymbol': 'star', 'androidDrawable': drawable},
        ],
      },
    });

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('mosaic_validate_'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String rel, String contents) {
    final file = File(p.join(root.path, rel));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  group('drawables', () {
    test('collects androidDrawable names from the tree', () {
      expect(referencedAndroidDrawables([defWithIcon('ic_bitcoin')]),
          {'ic_bitcoin'});
    });

    test('flags a referenced drawable that does not exist', () {
      write('android/app/src/main/res/drawable/other.xml', '<vector/>');
      final problems =
          validateDrawables([defWithIcon('ic_bitcoin')], root.path);
      expect(problems, hasLength(1));
      expect(problems.single.fatal, isTrue);
      expect(problems.single.message, contains('ic_bitcoin'));
    });

    test('accepts a drawable present in any drawable* qualifier dir', () {
      write('android/app/src/main/res/drawable-night/ic_bitcoin.xml',
          '<vector/>');
      expect(
          validateDrawables([defWithIcon('ic_bitcoin')], root.path), isEmpty);
    });

    test('accepts png as well as xml', () {
      write('android/app/src/main/res/drawable/ic_bitcoin.png', 'x');
      expect(
          validateDrawables([defWithIcon('ic_bitcoin')], root.path), isEmpty);
    });

    test('stays quiet when the project has no android res dir', () {
      expect(
          validateDrawables([defWithIcon('ic_bitcoin')], root.path), isEmpty);
    });
  });

  /// Writes a valid App Group on both targets.
  ///
  /// A missing entitlements file is itself a fatal problem now (it means the
  /// group was never configured), so tests targeting another concern must
  /// satisfy this first or they see two problems instead of one.
  void writeValidAppGroup() {
    write('ios/Runner/Runner.entitlements',
        '<plist>group.com.a.b.widgets</plist>');
  }

  group('app group entitlements', () {
    test('flags an entitlements file missing the configured group', () {
      write('ios/Runner/Runner.entitlements', '<plist>group.wrong.id</plist>');
      final problems = validateProject(config(), root.path);
      expect(
          problems.where((e) => e.message.contains('App Group')), hasLength(1));
    });

    test('accepts the matching group', () {
      writeValidAppGroup();
      expect(validateProject(config(), root.path), isEmpty);
    });
  });

  group('host plugin wiring', () {
    test('flags an AppDelegate that never registers the plugin', () {
      writeValidAppGroup();
      write('ios/Runner/AppDelegate.swift', 'class AppDelegate {}');
      final problems = validateProject(config(), root.path);
      expect(problems.single.message, contains('MosaicPlugin.register'));
      expect(problems.single.fatal, isTrue);
    });

    test('flags a plugin file missing from the Runner target', () {
      writeValidAppGroup();
      write(
          'ios/Runner/AppDelegate.swift', 'MosaicPlugin.register(with: self)');
      write('ios/Runner/MosaicPlugin.swift', 'class MosaicPlugin {}');
      write('ios/Runner.xcodeproj/project.pbxproj', 'AppDelegate.swift');
      final problems = validateProject(config(), root.path);
      expect(problems.single.message,
          contains('not a member of the Runner target'));
    });

    test('accepts a correctly wired project', () {
      writeValidAppGroup();
      write(
          'ios/Runner/AppDelegate.swift', 'MosaicPlugin.register(with: self)');
      write('ios/Runner/MosaicPlugin.swift', 'class MosaicPlugin {}');
      write('ios/Runner.xcodeproj/project.pbxproj', 'MosaicPlugin.swift');
      expect(validateProject(config(), root.path), isEmpty);
    });
  });

  group('live activities opt-in', () {
    MosaicConfig withActivity() => MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b.widgets
widgets: []
live_activities:
  - name: Order
    entry: lib/live/order.live.dart
''');

    test('flags a missing NSSupportsLiveActivities key', () {
      writeValidAppGroup();
      write('ios/Runner/Info.plist', '<plist><dict></dict></plist>');
      final problems = validateProject(withActivity(), root.path);
      expect(problems.single.message, contains('NSSupportsLiveActivities'));
      expect(problems.single.fatal, isTrue);
    });

    test('accepts the key when present', () {
      writeValidAppGroup();
      write('ios/Runner/Info.plist',
          '<plist><key>NSSupportsLiveActivities</key><true/></plist>');
      expect(validateProject(withActivity(), root.path), isEmpty);
    });

    test('does not require the key when no live activities are declared', () {
      writeValidAppGroup();
      write('ios/Runner/Info.plist', '<plist><dict></dict></plist>');
      expect(validateProject(config(), root.path), isEmpty);
    });
  });

  group('refresh sources', () {
    test('flags a non-absolute url', () {
      final problems = validateProject(
        config(refresh: '''
refresh:
  refresh_news:
    url: /relative/path
    map:
      k: a.b
'''),
        root.path,
      );
      expect(problems.single.message, contains('not absolute http(s)'));
    });

    test('warns, non-fatally, about an empty map', () {
      final problems = validateProject(
        config(refresh: '''
refresh:
  refresh_news:
    url: https://api.example.com/news
    map: {}
'''),
        root.path,
      );
      expect(problems.single.fatal, isFalse);
    });
  });
}
