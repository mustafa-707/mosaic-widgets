import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

Future<String> _layout(Map<String, dynamic> style) async {
  final r = await runAndroid([
    IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson(text('hello', style: style)),
    ),
  ]);
  return r.file('android/app/src/main/res/layout/hw_testw.xml');
}

void main() {
  test('a bundled font becomes an @font family and drops bold', () async {
    final xml = await _layout({
      'bold': true,
      'font': {'android': 'zain_bold', 'ios': 'Zain-Bold'},
    });
    expect(xml, contains('android:fontFamily="@font/zain_bold"'));
    expect(xml, contains('android:textStyle="normal"'));
  });

  test('italic still applies on top of a bundled font', () async {
    final xml = await _layout({
      'italic': true,
      'font': {'android': 'zain_regular'},
    });
    expect(xml, contains('android:fontFamily="@font/zain_regular"'));
    expect(xml, contains('android:textStyle="italic"'));
  });

  test('a font with no Android name falls back to the weight family', () async {
    final xml = await _layout({
      'weight': 'w500',
      'font': {'ios': 'Zain-Bold'},
    });
    expect(xml, contains('android:fontFamily="sans-serif-medium"'));
    expect(xml, isNot(contains('@font/')));
  });

  test('an unsafe resource name is ignored, not written into the layout',
      () async {
    final xml = await _layout({
      'font': {'android': 'bad"name'},
    });
    expect(xml, isNot(contains('@font/')));
    expect(xml, isNot(contains('bad"name')));
  });
}
