import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('runtime data accessor + type-routed bindings', () {
    test('bound image uses setImageView not setTextViewText', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWImage',
          'source': {
            '__type': 'HWFileImage',
            'path': {'__type': 'HWBind', 'key': 'pic'},
          },
          'fit': 'cover',
        }),
      ]);
      final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/hw_generated/TestWProvider.kt',
      );
      expect(kt, contains('setImageView'));
      expect(kt, isNot(contains('setTextViewText(R.id.hw_text_pic')));
    });

    test('bound progress uses setProgressBar', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWProgressBar',
          'value': {'__type': 'HWBind', 'key': 'p'},
          'max': 100.0,
          'color': {'hex': '#FF0000', 'opacity': 1.0},
        }),
      ]);
      final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/hw_generated/TestWProvider.kt',
      );
      expect(kt, contains('setProgressBar'));
    });

    test('static progress writes android:progress in layout', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWProgressBar',
          'value': 42.0,
          'max': 100.0,
          'color': {'hex': '#FF0000', 'opacity': 1.0},
        }),
      ]);
      expect(
        r.file('android/app/src/main/res/layout/hw_testw.xml'),
        contains('android:progress="42"'),
      );
    });

    test('MosaicData helper file is generated', () async {
      final r = await runAndroid([irDef(text(bind('t')))]);
      expect(
        r.exists(
          'android/app/src/main/kotlin/com/acme/app/hw_generated/MosaicData.kt',
        ),
        isTrue,
      );
    });

    test('MosaicData exposes resolve helpers and uses widget_data prefs',
        () async {
      final r = await runAndroid([irDef(text(bind('t')))]);
      final md = r.file(
        'android/app/src/main/kotlin/com/acme/app/hw_generated/MosaicData.kt',
      );
      expect(md, contains('object MosaicData'));
      expect(md, contains('fun resolveString'));
      expect(md, contains('fun resolveDouble'));
      expect(md, contains('fun resolveBool'));
      expect(md, contains('fun resolveList'));
      expect(md, contains('widget_data'));
      expect(md.split('\n').first, contains('MOSAIC-GENERATED'));
    });

    test('text bind resolves via MosaicData.resolveString', () async {
      final r = await runAndroid([irDef(text(bind('t')))]);
      final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/hw_generated/TestWProvider.kt',
      );
      expect(
        kt,
        contains('setTextViewText(R.id.hw_text_t, MosaicData.resolveString'),
      );
    });

    test('visibility bind resolves via MosaicData.resolveBool', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWVisibility',
          'bind': {'key': 'vis'},
          'child': text('x'),
        }),
      ]);
      final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/hw_generated/TestWProvider.kt',
      );
      expect(kt, contains('MosaicData.resolveBool(context, "vis")'));
      expect(kt, contains('setViewVisibility(R.id.hw_visibility_vis'));
    });
  });
}
