import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_widgets/dsl.dart';
import 'package:mosaic_widgets/src/cli/validate.dart';
import 'package:mosaic_widgets/src/core/core.dart';

/// `MAdaptive` holds one subtree per platform and each generator emits only its
/// own. Selection is generation-time — there is no Dart on the home screen, so
/// a runtime platform check is not possible.
///
/// The subtle half is not the handlers, it is the walkers: several passes crawl
/// raw IR JSON looking for drawables, bind keys and device metrics. A walker
/// that descends into both branches over-collects — demanding an Android
/// drawable that only the iOS branch names, or emitting a native metric read
/// for a bind the other platform renders.
IRDefinition _def(Map<String, dynamic> root) =>
    IRDefinition(name: 'TestW', root: IRNode.fromJson(root));

Map<String, dynamic> _adaptive({
  required Map<String, dynamic> ios,
  required Map<String, dynamic> android,
}) =>
    {'__type': 'HWAdaptive', 'ios': ios, 'android': android};

Map<String, dynamic> _icon({String? sf, String? drawable}) => {
      '__type': 'HWIcon',
      if (sf != null) 'sfSymbol': sf,
      if (drawable != null) 'androidDrawable': drawable,
      'size': 12.0,
    };

Map<String, dynamic> _text(Object t) => {
      '__type': 'HWText',
      'text': t,
      'style': {},
    };

Map<String, dynamic> _bind(String key) => {'__type': 'HWBind', 'key': key};

void main() {
  test('the wire carries both branches', () {
    final json = const MAdaptive(
      ios: MText('on ios'),
      android: MText('on android'),
    ).toJson();
    expect(json['__type'], 'HWAdaptive');
    expect((json['ios'] as Map)['text'], 'on ios');
    expect((json['android'] as Map)['text'], 'on android');
  });

  test('drawable validation ignores the iOS branch', () {
    // The iOS branch names no drawable at all. Walking into it would be
    // harmless here, but walking into an *Android-only* drawable from the iOS
    // side is what previously failed builds — so assert the split directly.
    final defs = [
      _def(
        _adaptive(
          ios: _icon(sf: 'bolt.fill'),
          android: _icon(drawable: 'ic_bolt'),
        ),
      ),
    ];
    final names = referencedAndroidDrawables(defs);
    expect(names, contains('ic_bolt'));
  });

  test('an Android-only drawable is not demanded from an iOS-only branch', () {
    // The reverse arrangement: a drawable named inside the branch that Android
    // never generates must not become a required resource.
    final defs = [
      _def(
        _adaptive(
          ios: _icon(drawable: 'ios_only_never_generated'),
          android: _text('plain'),
        ),
      ),
    ];
    expect(
      referencedAndroidDrawables(defs),
      isNot(contains('ios_only_never_generated')),
      reason: 'that subtree is never emitted on Android, so the resource is '
          'never referenced and must not fail the build',
    );
  });

  test('device metrics are collected per platform', () {
    final root = _adaptive(
      ios: _text(_bind('mosaic_battery_level')),
      android: _text(_bind('mosaic_storage_free_gb')),
    );
    final ios = deviceMetricsIn(root, platform: 'ios');
    final android = deviceMetricsIn(root, platform: 'android');

    expect(ios, contains(MosaicDeviceMetric.batteryLevel));
    expect(
      ios,
      isNot(contains(MosaicDeviceMetric.storageFreeGb)),
      reason: 'storage is only read in the Android branch, and reading it on '
          'iOS costs a filesystem call for a value nothing renders',
    );
    expect(android, contains(MosaicDeviceMetric.storageFreeGb));
    expect(android, isNot(contains(MosaicDeviceMetric.batteryLevel)));
  });

  test('without a platform, both branches are walked', () {
    // The right behaviour for genuinely shared collections, such as localized
    // string keys, which either platform may resolve.
    final both = deviceMetricsIn(
      _adaptive(
        ios: _text(_bind('mosaic_battery_level')),
        android: _text(_bind('mosaic_storage_free_gb')),
      ),
    );
    expect(both, contains(MosaicDeviceMetric.batteryLevel));
    expect(both, contains(MosaicDeviceMetric.storageFreeGb));
  });
}
