import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Golden tests for the "Components pack": Divider, Icon, Gauge, Badge.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  List<String> drawables(GenResult r) {
    return r
        .resXmlFiles()
        .where((f) => f.path.contains('/drawable/'))
        .map((f) => f.readAsStringSync())
        .toList();
  }

  group('HWDivider', () {
    test('horizontal divider emits a View with background + height', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWDivider',
          'thickness': 2.0,
          'color': {'hex': '#FF0000', 'opacity': 1.0},
          'vertical': false,
          'indent': 0.0,
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('<View'));
      expect(xml, contains('android:background="#FF0000"'));
      expect(xml, contains('android:layout_height="2.0dp"'));
      expect(xml, contains('android:layout_width="match_parent"'));
    });

    test('vertical divider uses width=thickness, match_parent height',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWDivider',
          'thickness': 3.0,
          'color': {'hex': '#00FF00', 'opacity': 1.0},
          'vertical': true,
          'indent': 0.0,
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:width="3.0dp"'.replaceAll('width', 'layout_width')));
      expect(xml, contains('android:layout_height="match_parent"'));
    });

    test('indent maps to start/end margins', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWDivider',
          'thickness': 1.0,
          'color': {'hex': '#0000FF', 'opacity': 1.0},
          'vertical': false,
          'indent': 8.0,
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('android:layout_marginStart="8.0dp"'));
      expect(xml, contains('android:layout_marginEnd="8.0dp"'));
    });
  });

  group('HWIcon', () {
    test('icon with androidDrawable emits ImageView src + tint, sized',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWIcon',
          'sfSymbol': 'star',
          'androidDrawable': 'ic_star',
          'size': 32.0,
          'color': {'hex': '#FFAA00', 'opacity': 1.0},
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('<ImageView'));
      expect(xml, contains('android:src="@drawable/ic_star"'));
      expect(xml, contains('android:tint="#FFAA00"'));
      expect(xml, contains('android:layout_width="32.0dp"'));
      expect(xml, contains('android:layout_height="32.0dp"'));
    });

    test('icon without androidDrawable emits comment + empty sized View',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWIcon',
          'sfSymbol': 'star.fill',
          'androidDrawable': null,
          'size': 24.0,
          'color': {'hex': '#FFFFFF', 'opacity': 1.0},
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('<!-- icon has no androidDrawable -->'));
      expect(xml, contains('<View'));
      expect(xml, contains('android:layout_width="24.0dp"'));
      expect(xml, isNot(contains('@drawable/')));
    });
  });

  group('HWGauge', () {
    test('gauge approximated as horizontal ProgressBar with comment', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWGauge',
          'value': 30.0,
          'max': 100.0,
          'trackColor': {'hex': '#222222', 'opacity': 1.0},
          'fillColor': {'hex': '#00FF00', 'opacity': 1.0},
          'lineWidth': 6.0,
        })
      ]);
      final xml = layout(r);
      expect(
        xml,
        contains(
            '<!-- gauge approximated as linear progress on Android (RemoteViews has no arc) -->'),
      );
      expect(xml, contains('<ProgressBar'));
      expect(xml, contains('style="?android:attr/progressBarStyleHorizontal"'));
      expect(xml, contains('android:max="100"'));
      expect(xml, contains('android:progress="30"'));
      // fillColor -> progressTint, trackColor -> backgroundTint
      expect(xml, contains('android:progressTint="#00FF00"'));
      expect(xml, contains('android:backgroundTint="#222222"'));
      // lineWidth has no analogue on a linear ProgressBar: the drop is
      // surfaced via a documented comment rather than silently ignored.
      expect(
        xml,
        contains(
            '<!-- gauge lineWidth ignored: approximated as linear ProgressBar on Android -->'),
      );
    });

    test('gauge value bind reuses the progress runtime-bind path', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWGauge',
          'value': bind('battery'),
          'max': 100.0,
          'fillColor': {'hex': '#00FF00', 'opacity': 1.0},
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('@+id/hw_progress_battery'));
      final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt',
      );
      expect(kt, contains('setProgressBar(R.id.hw_progress_battery'));
      expect(kt, contains('"battery"'));
    });
  });

  group('HWBadge', () {
    test('badge emits FrameLayout with child + top|end count TextView',
        () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWBadge',
          'child': text('Inbox'),
          'count': 5,
          'color': {'hex': '#FF0000', 'opacity': 1.0},
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('<FrameLayout'));
      // child rendered
      expect(xml, contains('android:text="Inbox"'));
      // count TextView positioned top|end
      expect(xml, contains('android:layout_gravity="top|end"'));
      expect(xml, contains('android:text="5"'));
      // rounded background drawable referenced
      expect(xml, contains('android:background="@drawable/hw_badge_'));
      // the badge bg drawable exists with rounded corners + the color
      final draws = drawables(r);
      final badge = draws.firstWhere((d) => d.contains('<corners'));
      expect(badge, contains('#FF0000'));
      expect(badge, startsWith('<?xml'));
    });

    test('badge count bind reuses text bind path', () async {
      final r = await runAndroid([
        irDef({
          '__type': 'HWBadge',
          'child': text('Inbox'),
          'count': bind('unread'),
          'color': {'hex': '#FF0000', 'opacity': 1.0},
        })
      ]);
      final xml = layout(r);
      expect(xml, contains('@+id/hw_text_unread'));
      final kt = r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt',
      );
      expect(kt, contains('setTextViewText(R.id.hw_text_unread'));
      expect(kt, contains('"unread"'));
    });
  });
}
