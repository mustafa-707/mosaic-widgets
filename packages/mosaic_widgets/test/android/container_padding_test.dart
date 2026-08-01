import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// `MContainer(padding:)` mirrors Flutter's `Container(padding:)` — inside the
/// background and border. The iOS generator already emitted `.padding(...)` for
/// this key, but the DSL never sent it and Android ignored it, so the modifier
/// was unreachable on one platform and absent on the other.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  Map<String, dynamic> container(Map<String, dynamic>? padding) => {
        '__type': 'HWContainer',
        'radius': 0,
        'child': {'__type': 'HWText', 'text': 'hi'},
        if (padding != null) 'padding': padding,
      };

  test('padding becomes RTL-aware start/end attributes', () async {
    final r = await runAndroid([
      irDef(container({'left': 8, 'top': 4, 'right': 12, 'bottom': 6}))
    ]);
    final xml = layout(r);
    expect(xml, contains('android:paddingStart="8dp"'));
    expect(xml, contains('android:paddingEnd="12dp"'));
    expect(xml, contains('android:paddingTop="4dp"'));
    expect(xml, contains('android:paddingBottom="6dp"'));
    // left/right would not mirror in an RTL locale.
    expect(xml, isNot(contains('android:paddingLeft')));
  });

  test('omitted sides default to 0', () async {
    final r = await runAndroid([
      irDef(container({'left': 10}))
    ]);
    final xml = layout(r);
    expect(xml, contains('android:paddingStart="10dp"'));
    expect(xml, contains('android:paddingEnd="0dp"'));
  });

  test('double insets keep their decimal form, which AAPT accepts', () async {
    // MInsets carries doubles, so real widgets emit "14.0dp" rather than "14dp".
    final r = await runAndroid([
      irDef(container({'left': 14.0, 'top': 14.0}))
    ]);
    expect(layout(r), contains('android:paddingStart="14.0dp"'));
  });

  test('no padding emits no padding attributes', () async {
    final r = await runAndroid([irDef(container(null))]);
    expect(layout(r), isNot(contains('android:paddingStart')));
  });

  test('an empty padding map emits nothing', () async {
    final r = await runAndroid([irDef(container(<String, dynamic>{}))]);
    expect(layout(r), isNot(contains('android:paddingStart')));
  });
}
