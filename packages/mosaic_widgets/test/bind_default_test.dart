import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_widgets/dsl.dart';
import 'package:mosaic_widgets/src/core/core.dart';

/// A bind with no value rendered `--`, everywhere, always.
///
/// That is worst exactly where it is most visible: `placeholder(in:)` is what
/// the OS shows in the widget gallery *before the app has ever run*, and it
/// shipped an empty dictionary — so every bound value in the picker preview
/// read `--` while the user was deciding whether to add the widget at all.
///
/// Android had the opposite problem: `resolveString(ctx, key, fallback)` has
/// always taken a fallback, and every generated call site omitted it.
void main() {
  group('wire', () {
    test('a bind without a default is unchanged on the wire', () {
      // The common case must not grow a key, or every golden moves for nothing.
      expect(
          const MBind('price').toJson(), {'__type': 'HWBind', 'key': 'price'});
    });

    test('a declared default travels', () {
      expect(
        const MBind('price', defaultValue: '64000').toJson(),
        {'__type': 'HWBind', 'key': 'price', 'defaultValue': '64000'},
      );
    });

    test('it survives the IR round trip', () {
      // The generators read IR, not DSL, so a default that stops here is a
      // default that never reaches either platform.
      final json = const MBind('price', defaultValue: '64000').toJson();
      final back = IRBind.fromJson(json);
      expect(back.key, 'price');
      expect(back.defaultValue, '64000');
      expect(back.toJson(), json);
    });

    test('MDeviceValue inherits it', () {
      // It extends MBind, so a metric can declare what to show before the
      // first native read lands.
      final v = MDeviceValue(MDeviceMetric.batteryLevel, defaultValue: '100');
      expect(v.toJson()['defaultValue'], '100');
      expect(v.toJson()['key'], 'mosaic_battery_level');
    });
  });
}
