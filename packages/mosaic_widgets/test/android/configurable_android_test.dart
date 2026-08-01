import 'package:test/test.dart';
import 'package:mosaic_widgets/src/core/core.dart';
import 'package:mosaic_widgets/src/android/android.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// A definition carrying [params] (one per [MParamType]) so the generator emits
/// a configuration Activity wiring each value into the shared "widget_data"
/// store under the param key.
IRDefinition configurableDef({String name = 'ConfW'}) => IRDefinition(
      name: name,
      root: IRNode.fromJson({
        '__type': 'HWColumn',
        'children': [
          text(bind('city')),
          text(bind('count')),
          text(bind('darkMode')),
          text(bind('units')),
        ],
      }),
      params: const [
        {
          'key': 'city',
          'label': 'City',
          'type': 'text',
          'defaultValue': 'Berlin',
          'choices': null,
        },
        {
          'key': 'count',
          'label': 'Count',
          'type': 'number',
          'defaultValue': 5,
          'choices': null,
        },
        {
          'key': 'darkMode',
          'label': 'Dark Mode',
          'type': 'toggle',
          'defaultValue': true,
          'choices': null,
        },
        {
          'key': 'units',
          'label': 'Units',
          'type': 'choice',
          'defaultValue': 'metric',
          'choices': ['metric', 'imperial'],
        },
      ],
    );

void main() {
  const kotlinPath =
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated';

  group('configurable widget (with params)', () {
    test('generates <Name>ConfigActivity.kt with the sentinel and package',
        () async {
      final res = await runAndroid([configurableDef()]);
      final path = '$kotlinPath/ConfWConfigActivity.kt';
      expect(res.exists(path), isTrue,
          reason: 'config activity should be generated');
      final kt = res.file(path);
      // Sentinel MUST be the first line.
      expect(kt.split('\n').first, equals(kotlinSentinel));
      expect(kt, contains('package com.acme.app.mosaic_generated'));
      expect(kt, contains('import com.acme.app.R'));
      expect(kt, contains('class ConfWConfigActivity'));
    });

    test('builds one input per param type (EditText/SwitchCompat/Spinner)',
        () async {
      final res = await runAndroid([configurableDef()]);
      final kt = res.file('$kotlinPath/ConfWConfigActivity.kt');
      expect(kt, contains('LinearLayout'));
      // text + number -> EditText (number gets numeric inputType).
      expect(kt, contains('EditText'));
      expect(kt, contains('InputType'));
      // toggle -> SwitchCompat (AndroidX), NOT deprecated android.widget.Switch.
      expect(kt, contains('SwitchCompat('),
          reason: 'must instantiate AndroidX SwitchCompat');
      // choice -> Spinner over the choices.
      expect(kt, contains('Spinner'));
      expect(kt, contains('metric'));
      expect(kt, contains('imperial'));
    });

    test(
        'imports androidx SwitchCompat and does not reference deprecated android.widget.Switch',
        () async {
      final res = await runAndroid([configurableDef()]);
      final kt = res.file('$kotlinPath/ConfWConfigActivity.kt');
      expect(
        kt,
        contains('import androidx.appcompat.widget.SwitchCompat'),
        reason: 'must import AndroidX SwitchCompat',
      );
      expect(
        kt,
        isNot(contains('import android.widget.Switch')),
        reason: 'must not import deprecated android.widget.Switch',
      );
      expect(
        kt,
        isNot(contains('Switch(this)')),
        reason: 'must not instantiate deprecated android.widget.Switch',
      );
    });

    test('writes each value into "widget_data" under the param key', () async {
      final res = await runAndroid([configurableDef()]);
      final kt = res.file('$kotlinPath/ConfWConfigActivity.kt');
      expect(kt, contains('"widget_data"'));
      // Each key is persisted as a String.
      expect(kt, contains('putString("city"'));
      expect(kt, contains('putString("count"'));
      expect(kt, contains('putString("darkMode"'));
      expect(kt, contains('putString("units"'));
    });

    test('follows the config-activity contract (EXTRA_APPWIDGET_ID, cancel)',
        () async {
      final res = await runAndroid([configurableDef()]);
      final kt = res.file('$kotlinPath/ConfWConfigActivity.kt');
      expect(kt, contains('AppWidgetManager.EXTRA_APPWIDGET_ID'));
      expect(kt, contains('RESULT_CANCELED'));
      expect(kt, contains('RESULT_OK'));
      // Triggers a widget update via the provider on save.
      expect(kt, contains('ConfWProvider'));
    });

    test('info XML references the config activity via android:configure',
        () async {
      final res = await runAndroid([configurableDef()]);
      final info = res.file('android/app/src/main/res/xml/hw_confw_info.xml');
      expect(
        info,
        contains(
          'android:configure="com.acme.app.mosaic_generated.ConfWConfigActivity"',
        ),
      );
    });
  });

  group('non-configurable widget (no params)', () {
    test('generates NO config activity and NO android:configure', () async {
      final res = await runAndroid([
        irDef({
          '__type': 'HWColumn',
          'children': [text(bind('city'))],
        }, name: 'PlainW')
      ]);
      expect(
        res.exists('$kotlinPath/PlainWConfigActivity.kt'),
        isFalse,
        reason: 'no params -> no config activity',
      );
      final info = res.file('android/app/src/main/res/xml/hw_plainw_info.xml');
      expect(info, isNot(contains('android:configure')));
    });
  });
}
