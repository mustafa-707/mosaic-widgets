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

  test('AndroidGenerator accepts and stores liveActivities', () {
    final la = [
      {'__type': 'HWLiveActivity', 'name': 'Delivery'}
    ];
    final gen = AndroidGenerator(
      config: config,
      definitions: const [],
      liveActivities: la,
    );
    expect(gen.liveActivities, la);
  });

  test('AndroidGenerator liveActivities defaults to empty', () {
    final gen = AndroidGenerator(config: config, definitions: const []);
    expect(gen.liveActivities, isEmpty);
  });
}
