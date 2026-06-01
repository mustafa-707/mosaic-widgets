import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// AAPT rejects any res XML whose XML declaration is not the very first line
/// ("processing instruction target matching xml is not allowed"). This test
/// exercises every feature gap closed in this batch within a single widget and
/// asserts that all produced res XML files start with `<?xml`.
void main() {
  test('every generated res XML starts with the XML declaration', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'mainAxisAlignment': 'spaceAround',
        'crossAxisAlignment': 'stretch',
        'children': [
          text('hi', style: {'opacity': 0.5}),
          {
            '__type': 'HWImage',
            'source': {'__type': 'HWAssetImage', 'path': 'icon.png'},
            'fit': 'contain',
          },
          {
            '__type': 'HWProgressBar',
            'value': 40,
            'max': 100,
            'color': {'hex': '#FF0000', 'opacity': 1.0},
          },
          {
            '__type': 'HWVisibility',
            'bind': {'__type': 'HWBind', 'key': 'show'},
            'child': text('shown'),
            'replacement': text('hidden'),
          },
          {
            '__type': 'HWTimer',
            'target': 1700000000000,
            'countUp': true,
          },
          container(text('grad'), extra: {
            'gradient': {
              '__type': 'HWLinearGradient',
              'colors': [
                {'hex': '#FF0000', 'opacity': 1.0},
                {'hex': '#00FF00', 'opacity': 1.0},
                {'hex': '#0000FF', 'opacity': 1.0},
              ],
              'stops': [0.0, 0.5, 1.0],
            }
          }),
        ],
      })
    ]);

    final offender = r.firstNonXmlDeclFile();
    expect(offender, isNull,
        reason: 'res XML must start with <?xml; offending file: $offender');
    // Sanity: we actually produced multiple res XML files (layout, info, drawable).
    expect(r.resXmlFiles().length, greaterThanOrEqualTo(3));
  });
}
