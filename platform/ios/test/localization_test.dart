import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// The widget extension carries its own bundle, so its localizations must live
/// beside the generated Swift — the app's are not visible to it.
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
          'android': {'min_sdk': 21, 'sizes': ['medium']},
          'ios': {'families': ['systemMedium']},
        },
      ],
      'strings': {
        'en': {'trending': 'TRENDING NOW', 'read': 'READ'},
        'ar': {'trending': 'الأكثر تداولاً', 'read': 'اقرأ'},
      },
    });

void main() {
  test('localized text uses LocalizedStringKey, not a literal', () async {
    final r = await runIos(
        [irDef(text({'__type': 'HWLocalized', 'key': 'trending'}))],
        config: configWithStrings());
    final swift = r.swiftForTestW();
    expect(swift, contains('Text(LocalizedStringKey("trending"))'));
    expect(swift, isNot(contains('TRENDING NOW')));
  });

  test('one Localizable.strings per locale, beside the generated Swift',
      () async {
    final r = await runIos(
        [irDef(text({'__type': 'HWLocalized', 'key': 'trending'}))],
        config: configWithStrings());
    expect(r.exists('ios/HomeWidgetExtension/en.lproj/Localizable.strings'),
        isTrue);
    expect(r.exists('ios/HomeWidgetExtension/ar.lproj/Localizable.strings'),
        isTrue);
    expect(readFile(r.file('ios/HomeWidgetExtension/en.lproj/Localizable.strings')),
        contains('"trending" = "TRENDING NOW";'));
    expect(readFile(r.file('ios/HomeWidgetExtension/ar.lproj/Localizable.strings')),
        contains('الأكثر تداولاً'));
  });

  test('quotes in values are escaped so the strings file stays valid', () async {
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
          'android': {'min_sdk': 21, 'sizes': ['medium']},
          'ios': {'families': ['systemMedium']},
        },
      ],
      'strings': {
        'en': {'quoted': 'say "hi"'},
      },
    });
    final r = await runIos(
        [irDef(text({'__type': 'HWLocalized', 'key': 'quoted'}))],
        config: config);
    expect(readFile(r.file('ios/HomeWidgetExtension/en.lproj/Localizable.strings')),
        contains(r'say \"hi\"'));
  });

  test('nothing is written when no strings are declared', () async {
    final r = await runIos([irDef(text('plain'))]);
    expect(r.exists('ios/HomeWidgetExtension/en.lproj/Localizable.strings'),
        isFalse);
  });

  test('plain and bound text are unaffected', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWColumn',
        'children': [text('literal'), text(bind('live'))],
      })
    ], config: configWithStrings());
    final swift = r.swiftForTestW();
    expect(swift, contains('Text("literal")'));
    expect(swift, contains('mosaicStr(entry.data["live"])'));
  });
}
