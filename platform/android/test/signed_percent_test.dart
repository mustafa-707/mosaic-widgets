import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Web APIs almost always return a 24h change already expressed in percent
/// units — CoinGecko's `usd_24h_change` is `1.327679510905918`, meaning 1.33%.
///
/// `MFormat.percent` treats its input as a *fraction*, so it renders that as
/// 133%. Before `signedPercent` existed the demo showed the raw double on a
/// real phone, because a native `refresh:` source writes the API value straight
/// into the store and overwrites anything the app formatted in Dart.
void main() {
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');
  // The format switch is shared runtime, not per-widget code.
  String runtime(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicData.kt');

  Map<String, dynamic> formatted(String fmt) => {
        '__type': 'HWText',
        'text': bind('change'),
        'style': {},
        'format': fmt,
      };

  test('signedPercent reaches the provider as its own format', () async {
    final kt = provider(await runAndroid([irDef(formatted('signedPercent'))]));
    expect(kt, contains('formatValue(MosaicData.resolveString(context, '
        '"change"), "signedPercent")'));
  });

  test('it formats with a sign and two decimals, and does not scale', () async {
    final kt = runtime(await runAndroid([irDef(formatted('signedPercent'))]));
    // %+ gives the explicit sign; .2f the fixed scale.
    expect(kt, contains(r'"%+.2f%%"'));
    // The branch must not route through getPercentInstance, which multiplies
    // by 100 — the exact bug this format exists to avoid.
    final branch = kt.substring(kt.indexOf('"signedPercent"'));
    expect(branch.split('\n').take(3).join('\n'),
        isNot(contains('getPercentInstance')));
  });

  test('percent still means fraction, and is untouched', () async {
    final kt = runtime(await runAndroid([irDef(formatted('percent'))]));
    expect(kt, contains('"percent" ->'));
    expect(kt, contains('getPercentInstance'));
  });

  test('an unknown format still falls through to the raw value', () async {
    final kt = provider(await runAndroid([irDef(formatted('nonsense'))]));
    expect(kt, contains('resolveString(context, "change")'));
  });
}
