import 'package:mosaic_widgets/src/cli/commands/build_command.dart';
import 'package:test/test.dart';

/// The widget picker uses the receiver's android:label. Without it Android
/// falls back to the application label, so every widget shows the app's name.
void main() {
  const pkg = 'com.acme.app';

  test('falls back to the widget name', () {
    expect(receiverTag(pkg, 'Weather'), contains('android:label="Weather"'));
  });

  test('uses the configured label when given', () {
    expect(receiverTag(pkg, 'Weather', label: 'Weather Now'),
        contains('android:label="Weather Now"'));
  });

  test('escapes markup in the label', () {
    expect(receiverTag(pkg, 'W', label: 'Tom & "Jerry" <b>'),
        contains('android:label="Tom &amp; &quot;Jerry&quot; &lt;b&gt;"'));
  });

  test('the label sits on the receiver, not the intent-filter', () {
    final tag = receiverTag(pkg, 'Weather');
    final receiverOpen = tag.indexOf('<receiver');
    final receiverClose = tag.indexOf('>', receiverOpen);
    expect(
        tag.substring(receiverOpen, receiverClose), contains('android:label='));
  });
}
