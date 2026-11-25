import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/gen_harness.dart';

Map<String, dynamic> _text(String s) =>
    {'__type': 'HWText', 'text': s, 'style': <String, dynamic>{}};

Future<String> _swift(Map<String, dynamic> flexibleChild) async {
  final def = IRDefinition(
    name: 'TestW',
    root: IRNode.fromJson({
      '__type': 'HWColumn',
      'children': [
        {'__type': 'HWFlexible', 'flex': 1, 'child': flexibleChild},
      ],
    }),
    resizeMode: 'both',
  );
  return (await runIos([def])).swiftForTestW();
}

void main() {
  networkImageCoverTests();
  test('a container inside a flexible is framed before its background',
      () async {
    final s = await _swift({
      '__type': 'HWContainer',
      'background': {'hex': '#112233', 'opacity': 1.0},
      'radius': 12,
      'child': _text('card'),
    });
    final frame =
        s.indexOf('.frame(maxWidth: .infinity, maxHeight: .infinity)');
    final background = s.indexOf('.background(');
    expect(frame, greaterThan(-1));
    expect(background, greaterThan(frame));
    // The card's own frame comes before its background, so the colour fills.
    expect(s.indexOf('card'), lessThan(background));
  });

  test('a non-container child is left alone', () async {
    final s = await _swift(_text('plain'));
    expect(s, contains('plain'));
    expect(s, contains('.frame(maxWidth: .infinity, maxHeight: .infinity)'));
  });
}

void networkImageCoverTests() {
  Future<String> swift(String fit) async {
    final def = IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson({
        '__type': 'HWNetworkImage',
        'url': 'https://example.com/a.png',
        'fit': fit,
        'circle': false,
        'accentedMode': 'fullColor',
      }),
      resizeMode: 'both',
    );
    return (await runIos([def])).swiftForTestW();
  }

  test('a cover network image cannot grow past the box it is given', () async {
    final s = await swift('cover');
    expect(s, contains('Color.clear.overlay(Image(mosaic: _img)'));
    expect(s, contains('.clipped()'));
  });

  test('a contain network image keeps its plain form', () async {
    final s = await swift('contain');
    expect(s, isNot(contains('Color.clear.overlay')));
    expect(s, contains('Image(mosaic: _img).resizable()'));
  });
}
