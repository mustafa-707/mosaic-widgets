import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/gen_harness.dart';

IRNode _text(String s) =>
    IRNode.fromJson({'__type': 'HWText', 'text': s, 'style': {}});

IRDefinition _def({bool compact = false, bool large = false}) => IRDefinition(
      name: 'TestW',
      root: _text('medium layout'),
      compactRoot: compact ? _text('small layout') : null,
      largeRoot: large ? _text('large layout') : null,
      resizeMode: 'both',
    );

void main() {
  test('no large tree emits no large branch', () async {
    final s = (await runIos([_def(compact: true)])).swiftForTestW();
    expect(s, isNot(contains('mosaicPrefersLarge(family)')));
    expect(s, isNot(contains('large layout')));
  });

  test('a large tree adds its branch and the family environment', () async {
    final s = (await runIos([_def(large: true)])).swiftForTestW();
    expect(s, contains('@Environment(\\.widgetFamily) private var family'));
    expect(s, contains('mosaicPrefersLarge(family)'));
    expect(s, contains('large layout'));
    expect(s, contains('medium layout'));
    expect(s, isNot(contains('mosaicPrefersCompact(family)')));
  });

  test('all three trees sit behind one family switch, small checked first',
      () async {
    final s =
        (await runIos([_def(compact: true, large: true)])).swiftForTestW();
    final small = s.indexOf('mosaicPrefersCompact(family)');
    final large = s.indexOf('mosaicPrefersLarge(family)');
    expect(small, greaterThan(-1));
    expect(large, greaterThan(small));
    expect(s, contains('small layout'));
    expect(s, contains('medium layout'));
    expect(s, contains('large layout'));
  });

  test('the shared helper covers systemLarge and systemExtraLarge', () async {
    final r = await runIos([_def(large: true)]);
    final core =
        readFile(r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));
    expect(core, contains('func mosaicPrefersLarge(_ family: WidgetFamily)'));
    expect(core, contains('.systemExtraLarge'));
    expect(core, contains('.systemLarge'));
  });
}
