import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// A RemoteViews provider sets each view's content by id, so one bound key that
/// drives several views needs one statement per view. Tracking a single "kind"
/// per key silently dropped every binding but the last — a battery level shown
/// as both a number and a bar rendered the bar and left the number blank.
void main() {
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  test('a key bound as text and as progress updates both views', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [
          text(bind('battery')),
          {
            '__type': 'HWProgressBar',
            'value': bind('battery'),
            'max': 100.0,
          },
        ],
      })
    ]);
    final kt = provider(r);
    expect(kt, contains('setTextViewText(R.id.hw_text_battery'));
    expect(kt, contains('setProgressBar(R.id.hw_progress_battery'));
  });

  test('both target views exist in the layout', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [
          text(bind('battery')),
          {'__type': 'HWProgressBar', 'value': bind('battery'), 'max': 100.0},
        ],
      })
    ]);
    final xml = r.file('android/app/src/main/res/layout/hw_testw.xml');
    expect(xml, contains('hw_text_battery'));
    expect(xml, contains('hw_progress_battery'));
  });

  test('the same key in two text views updates both', () async {
    // This test used to assert one statement, on the theory that both views
    // shared an id so a single call covered them. They did share an id — and
    // RemoteViews acts on the first match only, so the second view silently
    // never updated. Distinct ids, one statement each.
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [text(bind('label')), text(bind('label'))],
      })
    ]);
    final xml = r.file('android/app/src/main/res/layout/hw_testw.xml');
    expect(xml, contains('@+id/hw_text_label"'));
    expect(xml, contains('@+id/hw_text_label_2"'));

    final kt = provider(r);
    expect(kt, contains('setTextViewText(R.id.hw_text_label,'));
    expect(kt, contains('setTextViewText(R.id.hw_text_label_2,'));
    // Both read the same stored key.
    expect('"label"'.allMatches(kt).length, greaterThanOrEqualTo(2));
  });

  test('a single-kind bind is unchanged', () async {
    final r = await runAndroid([irDef(text(bind('only')))]);
    expect(provider(r), contains('setTextViewText(R.id.hw_text_only'));
  });
}
