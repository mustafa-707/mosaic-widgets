import 'package:hw_core/hw_core.dart';
import 'package:test/test.dart';

void main() {
  test('xmlEscape escapes the five XML entities', () {
    expect(xmlEscape('a<b>&"\''), 'a&lt;b&gt;&amp;&quot;&apos;');
  });

  test('kotlinEscape escapes quote, backslash, dollar, newline', () {
    expect(kotlinEscape('a"b\\c\$d\n'), r'a\"b\\c\$d\n');
  });

  test('swiftEscape escapes quote, backslash, newline', () {
    expect(swiftEscape('a"b\\c\n'), r'a\"b\\c\n');
  });

  test('sanitizeIdentifier produces a valid identifier', () {
    expect(sanitizeIdentifier('My Widget-1'), 'MyWidget1');
    expect(sanitizeIdentifier('9lives'), '_9lives');
    expect(sanitizeIdentifier(''), '_');
  });
}
