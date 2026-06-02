import 'package:test/test.dart';
import 'package:mosaic_cli/src/commands/build_command.dart';

void main() {
  group('receiverTag', () {
    test('uses sanitized provider class name and sanitized xml resource', () {
      final tag = receiverTag('com.acme.app', 'My Widget');
      expect(
        tag,
        contains(
          'android:name="com.acme.app.mosaic_generated.MyWidgetProvider"',
        ),
      );
      expect(tag, contains('@xml/hw_mywidget_info'));
      // Must NOT contain the raw (space-bearing) reference.
      expect(tag, isNot(contains('hw_my widget_info')));
      expect(tag, isNot(contains('My WidgetProvider')));
    });

    test('keeps behavior identical for normal names', () {
      final tag = receiverTag('com.acme.app', 'Weather');
      expect(
        tag,
        contains('android:name="com.acme.app.mosaic_generated.WeatherProvider"'),
      );
      expect(tag, contains('@xml/hw_weather_info'));
    });
  });

  group('listServiceTag', () {
    test('declares the RemoteViews service with BIND_REMOTEVIEWS permission',
        () {
      final tag = listServiceTag('com.acme.app');
      expect(
        tag,
        contains(
          'android:name="com.acme.app.mosaic_generated.MosaicListService"',
        ),
      );
      expect(tag, contains('android.permission.BIND_REMOTEVIEWS'));
    });
  });

  group('configActivityTag', () {
    test('emits the APPWIDGET_CONFIGURE intent-filter for the config activity',
        () {
      final tag = configActivityTag('com.acme.app', 'My Widget');
      expect(
        tag,
        contains(
          'android:name="com.acme.app.mosaic_generated.MyWidgetConfigActivity"',
        ),
      );
      expect(tag, contains('android:exported="true"'));
      expect(
        tag,
        contains(
          'android:name="android.appwidget.action.APPWIDGET_CONFIGURE"',
        ),
      );
      // Must NOT contain a raw (space-bearing) class name.
      expect(tag, isNot(contains('My WidgetConfigActivity')));
    });
  });

  group('tileServiceTag', () {
    test('emits the QS_TILE intent-filter and BIND permission', () {
      final tag = tileServiceTag('com.acme.app', 'Torch', 'Flashlight');
      expect(
        tag,
        contains(
          'android:name="com.acme.app.mosaic_generated.TorchTileService"',
        ),
      );
      expect(tag, contains('android:exported="true"'));
      expect(
        tag,
        contains(
          'android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"',
        ),
      );
      expect(
        tag,
        contains(
          'android:name="android.service.quicksettings.action.QS_TILE"',
        ),
      );
      expect(
        tag,
        contains(
          'android:name="android.service.quicksettings.ACTIVE_TILE"',
        ),
      );
      expect(tag, contains('android:label="Flashlight"'));
    });

    test('sanitizes a space-bearing control name into the class name', () {
      final tag = tileServiceTag('com.acme.app', 'My Light', 'On');
      expect(
        tag,
        contains(
          'android:name="com.acme.app.mosaic_generated.MyLightTileService"',
        ),
      );
      expect(tag, isNot(contains('My LightTileService')));
    });

    test('xml-escapes the label', () {
      final tag = tileServiceTag('com.acme.app', 'Torch', 'A & B');
      expect(tag, contains('android:label="A &amp; B"'));
    });
  });

  group('deepLinkFilter', () {
    test('escapes a scheme containing &', () {
      final filter = deepLinkFilter('my&scheme');
      expect(filter, contains('android:scheme="my&amp;scheme"'));
      expect(filter, isNot(contains('android:scheme="my&scheme"')));
    });

    test('leaves a normal scheme unchanged', () {
      final filter = deepLinkFilter('mosaic');
      expect(filter, contains('android:scheme="mosaic"'));
    });
  });
}
