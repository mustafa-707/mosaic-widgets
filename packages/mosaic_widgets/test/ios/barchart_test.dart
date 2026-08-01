import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  Map<String, dynamic> bars() => {
        '__type': 'HWBarChart',
        'bind': bind('week'),
        'color': {'hex': '#22C55E'},
        'spacing': 3,
        'radius': 2,
      };

  test('draws real shapes rather than a rasterised image', () async {
    final r = await runIos([irDef(bars())]);
    final swift = r.swiftForTestW();
    expect(swift, contains('RoundedRectangle(cornerRadius: 2)'));
    expect(swift, contains('mosaicNumList(entry.data["week"])'));
  });

  test('bars are bottom-aligned', () async {
    // Bars grow up from a baseline; centring them would misread as floating.
    final r = await runIos([irDef(bars())]);
    expect(r.swiftForTestW(), contains('alignment: .bottom'));
  });

  test('bars scale from zero, not from the series minimum', () async {
    final swift = (await runIos([irDef(bars())])).swiftForTestW();
    expect(swift, contains('max(0, v) / scale'));
  });

  test('an all-zero series does not divide by zero', () async {
    final swift = (await runIos([irDef(bars())])).swiftForTestW();
    expect(swift, contains('hi <= 0 ? 0 : hi'));
  });

  test('a zero bucket still reads as a bucket', () async {
    final swift = (await runIos([irDef(bars())])).swiftForTestW();
    expect(swift, contains('max(1,'));
  });
}
