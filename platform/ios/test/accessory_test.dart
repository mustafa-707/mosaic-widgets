import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

MosaicConfig _cfgWithFamilies(List<String> families) => MosaicConfig.fromJson({
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
          'ios': {'families': families},
        },
      ],
    });

void main() {
  test('accessoryCircular family emits gated WidgetFamily + accentable',
      () async {
    final r = await runIos(
      [irDef(text('hi'))],
      config: _cfgWithFamilies(['accessoryCircular']),
    );
    final s = r.swiftForTestW();
    expect(s, contains('.accessoryCircular'));
    expect(s, contains('#available(iOS 16'));
    expect(s, contains('.widgetAccentable()'));
  });

  test('system + accessory families coexist; system not gated', () async {
    final r = await runIos(
      [irDef(text('hi'))],
      config: _cfgWithFamilies(['systemSmall', 'accessoryRectangular']),
    );
    final s = r.swiftForTestW();
    expect(s, contains('.systemSmall'));
    expect(s, contains('.accessoryRectangular'));
    expect(s, contains('#available(iOS 16'));
  });

  test('all three accessory families supported', () async {
    final r = await runIos(
      [irDef(text('hi'))],
      config: _cfgWithFamilies(
          ['accessoryCircular', 'accessoryRectangular', 'accessoryInline']),
    );
    final s = r.swiftForTestW();
    expect(s, contains('.accessoryCircular'));
    expect(s, contains('.accessoryRectangular'));
    expect(s, contains('.accessoryInline'));
  });

  test('unknown family throws a clear gen-time error listing valid families',
      () async {
    expect(
      () => runIos(
        [irDef(text('hi'))],
        config: _cfgWithFamilies(['bogusFamily']),
      ),
      throwsA(isA<Object>().having(
        (e) => e.toString(),
        'message',
        allOf(
          contains('bogusFamily'),
          contains('accessoryCircular'),
          contains('systemSmall'),
        ),
      )),
    );
  });

  test('no accessory families => no iOS16 gate emitted', () async {
    final r = await runIos(
      [irDef(text('hi'))],
      config: _cfgWithFamilies(['systemMedium']),
    );
    final s = r.swiftForTestW();
    expect(s, isNot(contains('#available(iOS 16')));
    // accentable is harmless on system widgets and kept for lock-screen tinting.
    expect(s, contains('.widgetAccentable()'));
  });
}
