import 'package:mosaic_android/mosaic_android.dart';
import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';

void main() {
  final config = MosaicConfig.fromJson({
    'app': {
      'bundle_id': 'com.acme.app',
      'android_package': 'com.acme.app',
      'ios_app_group': 'group.com.acme.app.widgets',
    },
    'widgets': [],
  });

  test('AndroidGenerator accepts and stores controls', () {
    final controls = [
      {'__type': 'HWControl', 'name': 'Torch'}
    ];
    final gen = AndroidGenerator(
      config: config,
      definitions: const [],
      controls: controls,
    );
    expect(gen.controls, controls);
  });

  test('AndroidGenerator controls defaults to empty', () {
    final gen = AndroidGenerator(config: config, definitions: const []);
    expect(gen.controls, isEmpty);
  });
}
