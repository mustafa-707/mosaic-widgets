import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';

void main() {
  optionalPlatformBlocks();
  test('deep_link_scheme defaults to mosaic', () {
    final c = MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b
widgets: []
''');
    expect(c.app.deepLinkScheme, 'mosaic');
  });

  test('deep_link_scheme parses explicit value', () {
    final c = MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b
  deep_link_scheme: myapp
widgets: []
''');
    expect(c.app.deepLinkScheme, 'myapp');
  });
}

/// A widget that omits `android:` / `ios:` used to crash the build with
/// `type 'Null' is not a subtype of type 'Map<String, dynamic>'` — no file, no
/// key, no hint. Neither block affects output beyond `ios.families`, so both
/// are optional and the minimal widget entry is name + entry.
void optionalPlatformBlocks() {
  group('optional platform blocks', () {
    MosaicConfig parse(String widgetYaml) => MosaicConfig.fromYaml('''
app:
  bundle_id: com.acme.app
  android_package: com.acme.app
  ios_app_group: group.com.acme.app.widgets
widgets:
$widgetYaml''');

    test('a widget needs only a name and an entry', () {
      final c = parse('  - name: Steps\n    entry: lib/steps.dart\n');
      expect(c.widgets.single.name, 'Steps');
      expect(c.widgets.single.entry, 'lib/steps.dart');
    });

    test('omitting ios: yields the default home-screen families', () {
      final c = parse('  - name: Steps\n    entry: lib/steps.dart\n');
      expect(c.widgets.single.ios.families,
          containsAll(['systemSmall', 'systemMedium']));
    });

    test('a declared ios: block still wins', () {
      final c = parse('''  - name: Steps
    entry: lib/steps.dart
    ios:
      families: [systemLarge]
''');
      expect(c.widgets.single.ios.families, ['systemLarge']);
    });

    test('omitting android: yields defaults rather than throwing', () {
      final c = parse('  - name: Steps\n    entry: lib/steps.dart\n');
      expect(c.widgets.single.android.minSdk, 21);
      expect(c.widgets.single.android.sizes, isEmpty);
    });

    test('a legacy config carrying min_sdk and sizes still parses', () {
      final c = parse('''  - name: Steps
    entry: lib/steps.dart
    android:
      min_sdk: 26
      sizes: [medium]
    ios:
      families: [systemMedium]
''');
      expect(c.widgets.single.android.minSdk, 26);
      expect(c.widgets.single.android.sizes, ['medium']);
    });
  });
}
