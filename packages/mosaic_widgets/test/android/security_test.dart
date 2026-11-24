import 'package:mosaic_widgets/src/cli/commands/build_command.dart';
import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// The provider's onReceive acts on MOSAIC_TOGGLE / CALLBACK / REFRESH without
/// checking the sender, so nothing outside the app may be able to reach it.
void main() {
  const pkg = 'com.acme.app';
  const dir = 'android/app/src/main/kotlin/com/acme/app/mosaic_generated';

  group('manifest exposure', () {
    test('the widget provider receiver is not exported', () {
      final tag = receiverTag(pkg, 'Weather');
      expect(tag, contains('android:exported="false"'));
      expect(tag, isNot(contains('android:exported="true"')));
      // The system server still delivers the update broadcast.
      expect(tag, contains('android.appwidget.action.APPWIDGET_UPDATE'));
      expect(tag, contains('android.appwidget.provider'));
    });

    test('components the platform must reach stay as they were', () {
      // The launcher starts the configuration activity itself.
      expect(configActivityTag(pkg, 'W'), contains('android:exported="true"'));
      // The system binds a Quick Settings tile, guarded by its permission.
      final tile = tileServiceTag(pkg, 'Ctl', 'Label');
      expect(tile, contains('android:exported="true"'));
      expect(tile, contains('BIND_QUICK_SETTINGS_TILE'));
      // The collection service is bound through the host's grant.
      final list = listServiceTag(pkg);
      expect(list, contains('android:exported="false"'));
      expect(list, contains('BIND_REMOTEVIEWS'));
    });
  });

  group('alarm lifecycle', () {
    IRDefinition withInterval(int? ms) => IRDefinition(
        name: 'TestW', root: IRNode.fromJson(text('hi')), updateInterval: ms);

    test('onDisabled cancels the alarm armed in onEnabled', () async {
      final r = await runAndroid([withInterval(60000)]);
      final kt = r.file('$dir/TestWProvider.kt');
      expect(kt, contains('override fun onEnabled'));
      expect(kt, contains('alarmManager.setRepeating('));
      final disabled = kt.substring(kt.indexOf('override fun onDisabled'));
      expect(disabled, contains('alarmManager.cancel(pendingIntent)'));
      // Must rebuild the SAME PendingIntent: request code 0, same component and
      // action, or AlarmManager cannot match it.
      expect(disabled, contains('getBroadcast(context, 0, intent'));
      expect(disabled, contains('ACTION_APPWIDGET_UPDATE'));
    });

    test('no interval means no alarm and no onDisabled', () async {
      final r = await runAndroid([withInterval(null)]);
      final kt = r.file('$dir/TestWProvider.kt');
      expect(kt, isNot(contains('onDisabled')));
      expect(kt, isNot(contains('AlarmManager')));
    });

    test('updatePeriodMillis is untouched', () async {
      final r = await runAndroid([withInterval(60000)]);
      expect(r.file('android/app/src/main/res/xml/hw_testw_info.xml'),
          contains('1800000'));
    });
  });

  group('callback receiver', () {
    test('rejects broadcasts that do not carry the per-install token',
        () async {
      final r = await runAndroid([irDef(text('hi'))]);
      final kt = r.file('$dir/MosaicPlugin.kt');
      expect(kt, contains('RECEIVER_NOT_EXPORTED'));
      final recv = kt.substring(kt.indexOf('val receiver = object'));
      final guard = recv.indexOf('MosaicCallbackAuth.accepts');
      final forward = recv.indexOf('invokeMethod("backgroundCallback"');
      expect(guard, greaterThan(-1));
      expect(guard, lessThan(forward), reason: 'check must precede forwarding');
      expect(kt, contains('object MosaicCallbackAuth'));
      expect(kt, contains('MessageDigest.isEqual'));
      expect(kt, contains('UUID.randomUUID()'));
      // No new Gradle dependency: no androidx import.
      expect(kt, isNot(contains('import androidx')));
    });

    test('the tile attaches the token to its callback broadcast', () async {
      final r = await runAndroidControls([
        {
          'name': 'Ctl',
          'label': 'Ctl',
          'kind': 'button',
          'action': {'__type': 'HWActionCallback', 'callbackName': 'go'},
        }
      ]);
      final kt = r.file('$dir/CtlTileService.kt');
      expect(kt, contains('MosaicCallbackAuth.EXTRA'));
      expect(kt, contains('MosaicCallbackAuth.token(this@CtlTileService)'));
      expect(kt, contains('setPackage(packageName)'));
    });
  });
}
