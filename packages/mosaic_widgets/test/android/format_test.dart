import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String provider(r) => r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt',
      );

  String mosaicData(r) => r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicData.kt',
      );

  // Combined generated Kotlin (provider routing + MosaicData formatting). The
  // spec asserts "provider Kotlin contains getCurrencyInstance"; the actual
  // format call lives in MosaicData.formatValue which the provider invokes.
  String kotlin(r) => '${provider(r)}\n${mosaicData(r)}';

  Map<String, dynamic> fmtText(String key, String format) => {
        '__type': 'HWText',
        'text': bind(key),
        'format': format,
        'style': <String, dynamic>{},
      };

  test('currency format on bound text uses getCurrencyInstance', () async {
    final r = await runAndroid([irDef(fmtText('price', 'currency'))]);
    expect(kotlin(r), contains('getCurrencyInstance'));
  });

  test('relativeTime format uses getRelativeTimeSpanString', () async {
    final r = await runAndroid([irDef(fmtText('when', 'relativeTime'))]);
    expect(kotlin(r), contains('getRelativeTimeSpanString'));
  });

  test('decimal format uses getInstance', () async {
    final r = await runAndroid([irDef(fmtText('count', 'decimal'))]);
    expect(kotlin(r), contains('NumberFormat.getInstance'));
  });

  test('percent format uses getPercentInstance', () async {
    final r = await runAndroid([irDef(fmtText('rate', 'percent'))]);
    expect(kotlin(r), contains('getPercentInstance'));
  });

  test('date format uses getDateInstance', () async {
    final r = await runAndroid([irDef(fmtText('day', 'date'))]);
    expect(kotlin(r), contains('getDateInstance'));
  });

  test('formatted bound text routes through MosaicData.formatValue', () async {
    final r = await runAndroid([irDef(fmtText('price', 'currency'))]);
    final p = provider(r);
    expect(p, contains('MosaicData.formatValue'));
    expect(p, contains('setTextViewText(R.id.hw_text_price'));
  });

  test('MosaicData exposes formatValue helper', () async {
    final r = await runAndroid([irDef(fmtText('price', 'currency'))]);
    final md = r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicData.kt',
    );
    expect(md, contains('fun formatValue'));
    expect(md, contains('getCurrencyInstance'));
    expect(md, contains('getRelativeTimeSpanString'));
  });

  test('unformatted bound text still resolves as plain string', () async {
    final r = await runAndroid([irDef(text(bind('name')))]);
    final p = provider(r);
    expect(p, contains('setTextViewText(R.id.hw_text_name'));
    expect(p, isNot(contains('MosaicData.formatValue(context, "name"')));
  });
}
