import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  const dir = 'android/app/src/main/kotlin/com/acme/app/mosaic_generated';
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');
  String provider(r) => r.file('$dir/TestWProvider.kt');

  test('a definition without widgetUrl generates no wrapper and no click',
      () async {
    final r = await runAndroid([irDef(text('hi'))]);
    expect(layout(r), isNot(contains('hw_root')));
    expect(provider(r), isNot(contains('hw_root')));
    expect(provider(r), isNot(contains('widgetUrl')));
  });

  test('literal widgetUrl wraps the root and opens the url on tap', () async {
    final r = await runAndroid([
      IRDefinition(
          name: 'TestW',
          root: IRNode.fromJson(text('hi')),
          widgetUrl: 'mosaic://offer/1')
    ]);
    final xml = layout(r);
    expect(xml, contains('android:id="@+id/hw_root"'));
    expect(xml.indexOf('hw_root'), lessThan(xml.indexOf('<TextView')));
    expect(xml.trimRight(), endsWith('</FrameLayout>'));
    final kt = provider(r);
    expect(kt, contains('val widgetUrl: String = "mosaic://offer/1"'));
    expect(kt, contains('Intent.ACTION_VIEW'));
    expect(kt, contains('PendingIntent.getActivity(context, appWidgetId * 100 + 99'));
    expect(kt, contains('FLAG_IMMUTABLE'));
    expect(kt, contains('views.setOnClickPendingIntent(R.id.hw_root'));
  });

  test('bound widgetUrl is resolved at update time and skipped when empty',
      () async {
    final r = await runAndroid([
      IRDefinition(
          name: 'TestW',
          root: IRNode.fromJson(text('hi')),
          widgetUrl: {
            '__type': 'HWBind',
            'key': 'offer_url',
            'defaultValue': 'mosaic://home'
          })
    ]);
    final kt = provider(r);
    expect(
        kt,
        contains('val widgetUrl: String = MosaicData.resolveString(context, '
            '"offer_url", "mosaic://home")'));
    expect(kt, contains('if (widgetUrl.isNotBlank())'));
  });

  test('the compact tree is wrapped too, so a small widget stays tappable',
      () async {
    final r = await runAndroid([
      IRDefinition(
          name: 'TestW',
          root: IRNode.fromJson(text('big')),
          compactRoot: IRNode.fromJson(text('small')),
          widgetUrl: 'mosaic://x')
    ]);
    final compact =
        r.file('android/app/src/main/res/layout/hw_testw_compact.xml');
    expect(compact, contains('android:id="@+id/hw_root"'));
  });

  test('widgetUrl does not disturb a button inside the tree', () async {
    final r = await runAndroid([
      IRDefinition(
          name: 'TestW',
          root: IRNode.fromJson({
            '__type': 'HWButton',
            'child': text('x'),
            'action': {'__type': 'HWActionCallback', 'callbackName': 'a'},
          }),
          widgetUrl: 'mosaic://x')
    ]);
    final kt = provider(r);
    expect(kt, contains('R.id.hw_button_main'));
    expect(kt, contains('R.id.hw_root'));
  });

  test('bound timer reads epoch ms at update time and zeroes when absent',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWTimer',
        'target': {'__type': 'HWBind', 'key': 'ends_at'},
      })
    ]);
    final kt = provider(r);
    expect(kt,
        contains('val epoch0 = MosaicData.resolveDouble(context, "ends_at").toLong()'));
    expect(kt, contains('if (epoch0 > System.currentTimeMillis())'));
    expect(
        kt,
        contains('views.setChronometer(R.id.hw_timer_0, '
            'android.os.SystemClock.elapsedRealtime() + (epoch0 - System.currentTimeMillis()), null, true)'));
    expect(kt, contains('setChronometerCountDown(R.id.hw_timer_0, true)'));
    // Missing / past: a stopped chronometer at zero.
    expect(
        kt,
        contains('views.setChronometer(R.id.hw_timer_0, '
            'android.os.SystemClock.elapsedRealtime(), null, false)'));
    expect(kt, isNot(contains('target0')));
  });

  test('bound count-up timer only needs a positive epoch', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWTimer',
        'target': {'__type': 'HWBind', 'key': 'since'},
        'countUp': true,
      })
    ]);
    final kt = provider(r);
    expect(kt, contains('if (epoch0 > 0L)'));
    expect(kt, contains('setChronometerCountDown(R.id.hw_timer_0, false)'));
  });
}
