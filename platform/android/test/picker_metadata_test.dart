import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Without picker metadata Android falls back to the application label and
/// icon, so every widget is listed under the app name with the Flutter logo.
MosaicConfig configWith({String? label, String? description}) =>
    MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
      },
      'widgets': [
        {
          'name': 'TestW',
          'entry': 'TestW',
          if (label != null) 'label': label,
          if (description != null) 'description': description,
          'android': {
            'min_sdk': 21,
            'sizes': ['medium'],
          },
          'ios': {
            'families': ['systemMedium'],
          },
        },
      ],
    });

void main() {
  const infoPath = 'android/app/src/main/res/xml/hw_testw_info.xml';

  test('previewLayout renders the real widget in the picker', () async {
    final r = await runAndroid([irDef(text('hi'))], config: configWith());
    expect(r.file(infoPath),
        contains('android:previewLayout="@layout/hw_testw"'));
  });

  // android:description accepts only a string RESOURCE reference. A literal
  // fails resource linking: "is incompatible with attribute description (attr)
  // reference".
  test('description is emitted as a string resource reference, never a literal',
      () async {
    final r = await runAndroid([irDef(text('hi'))],
        config: configWith(description: 'Live weather for your city'));
    final info = r.file(infoPath);
    expect(info, contains('android:description="@string/mosaic_desc_testw"'));
    expect(info, isNot(contains('Live weather for your city')));

    // ...and the referenced resource exists.
    final strings = r.file('android/app/src/main/res/values/mosaic_strings.xml');
    expect(strings,
        contains('<string name="mosaic_desc_testw">Live weather for your city</string>'));
  });

  test('description is omitted when not configured', () async {
    final r = await runAndroid([irDef(text('hi'))], config: configWith());
    expect(r.file(infoPath), isNot(contains('android:description=')));
    expect(r.exists('android/app/src/main/res/values/mosaic_strings.xml'),
        isFalse);
  });

  test('a description containing markup is escaped in the resource', () async {
    final r = await runAndroid([irDef(text('hi'))],
        config: configWith(description: 'Tom & "Jerry" <b>'));
    expect(r.file('android/app/src/main/res/values/mosaic_strings.xml'),
        contains('Tom &amp;'));
  });

  group('config', () {
    test('displayName falls back to the widget name', () {
      expect(configWith().widgets.single.displayName, 'TestW');
    });

    test('label overrides the picker title', () {
      expect(configWith(label: 'Weather Now').widgets.single.displayName,
          'Weather Now');
    });
  });
}
