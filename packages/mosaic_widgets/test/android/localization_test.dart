import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// A widget renders outside the Flutter engine, so Dart's localization stack is
/// unavailable to it. Text has to become real Android string resources for the
/// platform to select by device language.
MosaicConfig configWithStrings() => MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
      },
      'widgets': [
        {
          'name': 'TestW',
          'entry': 'TestW',
          'android': {
            'min_sdk': 21,
            'sizes': ['medium'],
          },
          'ios': {
            'families': ['systemMedium'],
          },
        },
      ],
      'strings': {
        'en': {'trending': 'TRENDING NOW', 'read': 'READ'},
        'ar': {'trending': 'الأكثر تداولاً', 'read': 'اقرأ'},
      },
    });

void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  test('localized text references a string resource, not a literal', () async {
    final r = await runAndroid([
      irDef(text({'__type': 'HWLocalized', 'key': 'trending'}))
    ], config: configWithStrings());
    final xml = layout(r);
    expect(xml, contains('android:text="@string/mosaic_s_trending"'));
    expect(xml, isNot(contains('TRENDING NOW')));
  });

  test('the default locale goes in values/, others in values-<locale>/',
      () async {
    final r = await runAndroid([
      irDef(text({'__type': 'HWLocalized', 'key': 'trending'}))
    ], config: configWithStrings());
    // First locale listed is the default, so it is the fallback for any language
    // without its own table.
    expect(r.exists('android/app/src/main/res/values/mosaic_localized.xml'),
        isTrue);
    expect(r.exists('android/app/src/main/res/values-ar/mosaic_localized.xml'),
        isTrue);
    expect(r.file('android/app/src/main/res/values/mosaic_localized.xml'),
        contains('TRENDING NOW'));
    expect(r.file('android/app/src/main/res/values-ar/mosaic_localized.xml'),
        contains('الأكثر تداولاً'));
  });

  test('resource names are consistent between layout and values', () async {
    final r = await runAndroid([
      irDef(text({'__type': 'HWLocalized', 'key': 'read'}))
    ], config: configWithStrings());
    expect(layout(r), contains('@string/mosaic_s_read'));
    expect(r.file('android/app/src/main/res/values/mosaic_localized.xml'),
        contains('name="mosaic_s_read"'));
  });

  test('values are XML-escaped', () async {
    final config = MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
      },
      'widgets': [
        {
          'name': 'TestW',
          'entry': 'TestW',
          'android': {
            'min_sdk': 21,
            'sizes': ['medium']
          },
          'ios': {
            'families': ['systemMedium']
          },
        },
      ],
      'strings': {
        'en': {'amp': 'Tom & "Jerry" <b>'},
      },
    });
    final r = await runAndroid([
      irDef(text({'__type': 'HWLocalized', 'key': 'amp'}))
    ], config: config);
    expect(r.file('android/app/src/main/res/values/mosaic_localized.xml'),
        contains('Tom &amp;'));
  });

  test('nothing is written when no strings are declared', () async {
    final r = await runAndroid([irDef(text('plain'))]);
    expect(r.exists('android/app/src/main/res/values/mosaic_localized.xml'),
        isFalse);
  });

  test('plain and bound text are unaffected', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [text('literal'), text(bind('live'))],
      })
    ], config: configWithStrings());
    final xml = layout(r);
    expect(xml, contains('android:text="literal"'));
    expect(xml, contains('hw_text_live'));
  });
}
