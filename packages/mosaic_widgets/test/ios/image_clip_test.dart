import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// `circle`/`radius` on an image — the usual way to get an avatar.
void main() {
  test('circle clips to a Circle', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWNetworkImage',
        'url': 'https://cdn.example.com/a.jpg',
        'circle': true,
      })
    ]);
    expect(r.swiftForTestW(), contains('.clipShape(Circle())'));
  });

  test('radius clips to a rounded rectangle', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWNetworkImage',
        'url': 'https://cdn.example.com/a.jpg',
        'radius': 12.0,
      })
    ]);
    expect(r.swiftForTestW(),
        contains('.clipShape(RoundedRectangle(cornerRadius: 12.0))'));
  });

  test('circle wins over radius when both are set', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWNetworkImage',
        'url': 'https://a/b.jpg',
        'circle': true,
        'radius': 12.0,
      })
    ]);
    final swift = r.swiftForTestW();
    expect(swift, contains('.clipShape(Circle())'));
    expect(swift, isNot(contains('RoundedRectangle')));
  });

  test(
      'the placeholder is clipped to the same shape, so a pending download '
      'does not show a square', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWNetworkImage',
        'url': 'https://a/b.jpg',
        'circle': true,
        'placeholder': {'hex': '#123456', 'opacity': 1.0},
      })
    ]);
    final swift = r.swiftForTestW();
    expect('.clipShape(Circle())'.allMatches(swift).length, 2);
  });

  test('asset and file images accept the same clip', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWImage',
        'source': {'__type': 'HWAssetImage', 'path': 'avatar.png'},
        'circle': true,
      })
    ]);
    expect(r.swiftForTestW(), contains('.clipShape(Circle())'));
  });

  test('plain images get no clip modifier', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWImage',
        'source': {'__type': 'HWAssetImage', 'path': 'a.png'},
      })
    ]);
    expect(r.swiftForTestW(), isNot(contains('clipShape')));
  });
}
