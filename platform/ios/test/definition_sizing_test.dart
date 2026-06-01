import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';
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
  test('empty families + resizeMode both derives multiple families', () async {
    final def = IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson({'__type': 'HWText', 'text': 'hi', 'style': {}}),
      resizeMode: 'both',
    );
    final r = await runIos([def], config: _cfgWithFamilies([]));
    final s = r.swiftForTestW();
    expect(s, contains('.systemSmall'));
    expect(s, contains('.systemMedium'));
    expect(s, contains('.systemLarge'));
    // advisory note about width/height/previewImage being unused by WidgetKit
    expect(s, contains('advisory'));
  });

  test('explicit families are still honored over the fallback', () async {
    final def = IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson({'__type': 'HWText', 'text': 'hi', 'style': {}}),
      resizeMode: 'both',
    );
    final r = await runIos([def], config: _cfgWithFamilies(['systemMedium']));
    final s = r.swiftForTestW();
    expect(s, contains('.systemMedium'));
    expect(s, isNot(contains('.systemLarge')));
  });
}
