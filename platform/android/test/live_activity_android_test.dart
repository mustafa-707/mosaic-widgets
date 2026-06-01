import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('Unit 1 — Live Activity notification layout from lockScreen', () {
    test('generates hw_la_<name>.xml from the lockScreen tree', () async {
      final la = [
        {
          '__type': 'HWLiveActivity',
          'name': 'OrderTracker',
          'lockScreen': {
            '__type': 'HWColumn',
            'children': [
              text('Order on the way'),
              text(bind('eta')),
            ],
          },
          'dynamicIsland': {'ignored': true},
        },
      ];

      final res = await runAndroidLiveActivity(la);

      const layoutPath =
          'android/app/src/main/res/layout/hw_la_ordertracker.xml';
      expect(res.exists(layoutPath), isTrue,
          reason: 'expected $layoutPath to be generated');

      final xml = res.file(layoutPath);
      expect(xml.split('\n').first.trimRight(), startsWith('<?xml'),
          reason: 'first line must be the XML declaration for AAPT');
      expect(xml, contains('MOSAIC-GENERATED'));

      // lockScreen content rendered via the existing handlers.
      expect(xml, contains('Order on the way'));
      expect(xml, contains('LinearLayout'));
      // Bound text rendered as a TextView with the resolvable bind id.
      expect(xml, contains('hw_text_eta'));
    });

    test('all generated res XML lead with the XML declaration', () async {
      final la = [
        {
          '__type': 'HWLiveActivity',
          'name': 'OrderTracker',
          'lockScreen': text('hello'),
        },
      ];
      final res = await runAndroidLiveActivity(la);
      expect(res.firstNonXmlDeclFile(), isNull);
    });
  });

  group('Unit 2 — MosaicLiveActivityManager.kt', () {
    const ktPath =
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicLiveActivityManager.kt';

    Future<String> genManager() async {
      final la = [
        {
          '__type': 'HWLiveActivity',
          'name': 'OrderTracker',
          'lockScreen': {
            '__type': 'HWColumn',
            'children': [
              text('Order on the way'),
              text(bind('eta')),
            ],
          },
        },
      ];
      final res = await runAndroidLiveActivity(la);
      expect(res.exists(ktPath), isTrue, reason: 'expected $ktPath');
      return res.file(ktPath);
    }

    test('is generated with the sentinel first line and package', () async {
      final kt = await genManager();
      expect(kt.split('\n').first, startsWith('// MOSAIC-GENERATED'));
      expect(kt, contains('package com.acme.app.mosaic_generated'));
      expect(kt, contains('import com.acme.app.R'));
    });

    test('exposes start/update/end/enabled/active', () async {
      final kt = await genManager();
      expect(kt, contains('fun start('));
      expect(kt, contains('fun update('));
      expect(kt, contains('fun end('));
      expect(kt, contains('fun enabled('));
      expect(kt, contains('fun active('));
    });

    test('references the hw_la_<name> layout', () async {
      final kt = await genManager();
      expect(kt, contains('hw_la_ordertracker'));
    });

    test('writes to the shared widget_data store and a channel', () async {
      final kt = await genManager();
      expect(kt, contains('"widget_data"'));
      expect(kt, contains('mosaic_live_activities'));
      expect(kt, contains('NotificationChannel'));
      expect(kt, contains('NotificationManagerCompat'));
    });
  });
}
