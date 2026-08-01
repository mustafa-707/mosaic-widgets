import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('text with quotes/ampersand is XML-escaped in layout', () async {
    final r = await runAndroid([irDef(text('it\'s "A" & <b>'))]);
    final xml = r.file('android/app/src/main/res/layout/hw_testw.xml');
    expect(xml, contains('&quot;A&quot;'));
    expect(xml, contains('&amp;'));
    expect(xml, isNot(contains('"A"')));
  });

  test('definition name is sanitized for resource filename', () async {
    final r = await runAndroid([irDef(text('hi'), name: 'My Widget')]);
    expect(r.exists('android/app/src/main/res/layout/hw_mywidget.xml'), isTrue);
  });
}
