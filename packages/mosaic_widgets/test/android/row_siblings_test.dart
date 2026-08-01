import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Wrappers (button, padding, visibility) hard-coded `match_parent` width, so
/// the first one in a Row consumed the whole width and its siblings — a second
/// button, a toggle — were pushed out of the widget and never appeared.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  Map<String, dynamic> button(String label, Map<String, dynamic> action) => {
        '__type': 'HWButton',
        'child': text(label),
        'action': action,
      };

  test('two buttons in a row each size to content, so both are visible',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWRow',
        'mainAxisAlignment': 'spaceBetween',
        'children': [
          button('refresh', {
            '__type': 'HWActionCallback',
            'callbackName': 'refresh_weather',
          }),
          button('°C / °F', {
            '__type': 'HWToggleAction',
            'key': 'weather_unit_f',
          }),
        ],
      })
    ]);
    final xml = layout(r);

    // Both buttons exist...
    expect(xml, contains('@+id/hw_button_main'));
    expect(xml, contains('@+id/hw_button_1'));

    // ...and neither claims the full row width.
    for (final id in ['hw_button_main', 'hw_button_1']) {
      final idx = xml.indexOf('@+id/$id');
      final tag = xml.substring(idx, xml.indexOf('>', idx));
      expect(tag, contains('android:layout_width="wrap_content"'),
          reason: '$id must not swallow the row');
    }
  });

  test('a button in a column still fills the cross axis', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [
          button('go', {'__type': 'HWRefreshAction'}),
        ],
      })
    ]);
    final xml = layout(r);
    final idx = xml.indexOf('@+id/hw_button_main');
    final tag = xml.substring(idx, xml.indexOf('>', idx));
    expect(tag, contains('android:layout_width="match_parent"'));
  });

  test('padding and visibility wrappers in a row also size to content',
      () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWRow',
        'children': [
          {
            '__type': 'HWVisibility',
            'bind': bind('flag'),
            'child': text('shown'),
          },
          text('sibling'),
        ],
      })
    ]);
    final xml = layout(r);
    final idx = xml.indexOf('hw_visibility_');
    final tag = xml.substring(
        xml.lastIndexOf('<FrameLayout', idx), xml.indexOf('>', idx));
    expect(tag, contains('android:layout_width="wrap_content"'));
  });
}
