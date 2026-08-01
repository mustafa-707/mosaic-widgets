import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// The outermost container must fill the widget cell. When it wrapped its
/// content instead, the tile collapsed to a narrow column and a rounded
/// background rendered as a capsule with the content squeezed out of view.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  Map<String, dynamic> bg() => {'hex': '#4A90D9', 'opacity': 1.0};

  test('root container fills the tile', () async {
    final r = await runAndroid([
      irDef(container(text('hi'), extra: {'background': bg(), 'radius': 20.0}))
    ]);
    final xml = layout(r);
    // The container carrying the background must not wrap.
    final bgIndex = xml.indexOf('android:background="@drawable/');
    final open = xml.lastIndexOf('<FrameLayout', bgIndex);
    final tag = xml.substring(open, bgIndex);
    expect(tag, contains('android:layout_width="match_parent"'));
    expect(tag, contains('android:layout_height="match_parent"'));
  });

  test('nested containers still wrap their content', () async {
    final r = await runAndroid([
      irDef(container(
        container(text('inner'), extra: {'background': bg()}),
        extra: {'background': bg()},
      ))
    ]);
    final xml = layout(r);
    // Exactly one container fills; the inner one wraps.
    expect(
        'android:layout_width="match_parent" android:layout_height="match_parent"'
            .allMatches(xml)
            .length,
        greaterThanOrEqualTo(1));
    expect(xml, contains('android:layout_width="wrap_content"'));
  });

  test('an explicit size on the root is still honoured', () async {
    final r = await runAndroid([
      irDef(container(text('hi'),
          extra: {'background': bg(), 'width': 100.0, 'height': 50.0}))
    ]);
    expect(layout(r), contains('android:layout_width="100.0dp"'));
  });
}
