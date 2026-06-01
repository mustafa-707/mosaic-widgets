import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  test('visibility with replacement emits two views toggled inversely',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWVisibility',
        'bind': {'__type': 'HWBind', 'key': 'show'},
        'child': text('shown'),
        'replacement': text('hidden'),
      })
    ]);
    final xml = layout(r);
    // Two container views: the child view and the replacement view.
    expect(xml, contains('@+id/hw_visibility_show'));
    expect(xml, contains('@+id/hw_visibility_show_alt'));

    final kt = provider(r);
    // child visible when true
    expect(
        kt,
        contains(
            'views.setViewVisibility(R.id.hw_visibility_show, if (MosaicData.resolveBool(context, "show")) android.view.View.VISIBLE else android.view.View.GONE)'));
    // replacement visible when false (inverse)
    expect(
        kt,
        contains(
            'views.setViewVisibility(R.id.hw_visibility_show_alt, if (MosaicData.resolveBool(context, "show")) android.view.View.GONE else android.view.View.VISIBLE)'));
  });

  test('visibility without replacement keeps single GONE-toggle behavior',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWVisibility',
        'bind': {'__type': 'HWBind', 'key': 'show'},
        'child': text('shown'),
      })
    ]);
    final xml = layout(r);
    expect(xml, contains('@+id/hw_visibility_show'));
    expect(xml, isNot(contains('hw_visibility_show_alt')));

    final kt = provider(r);
    expect(kt, isNot(contains('_alt')));
  });
}
