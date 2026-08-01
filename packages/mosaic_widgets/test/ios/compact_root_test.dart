import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/gen_harness.dart';

/// A `systemSmall` tile is roughly a quarter of a `systemLarge` one, so a
/// definition that renders the same tree at both sizes either wastes the large
/// or overflows the small. `compactRoot` lets the definition hand WidgetKit a
/// second tree, chosen from `@Environment(\.widgetFamily)` at render time.
IRDefinition _def({IRNode? compact}) => IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson({
        '__type': 'HWText',
        'text': 'the full layout',
        'style': {},
      }),
      compactRoot: compact,
      resizeMode: 'both',
    );

IRNode _compact() => IRNode.fromJson({
      '__type': 'HWText',
      'text': 'tiny',
      'style': {},
    });

void main() {
  test('no compact tree keeps the single-tree body', () async {
    final s = (await runIos([_def()])).swiftForTestW();
    expect(s, contains('the full layout'));
    // No family switch, and — this is the part that matters — no environment
    // property, because an unread one warns in code the developer cannot edit.
    expect(s, isNot(contains('widgetFamily')));
  });

  test('a compact tree emits both trees behind a family switch', () async {
    final s = (await runIos([_def(compact: _compact())])).swiftForTestW();
    expect(s, contains('@Environment(\\.widgetFamily) private var family'));
    expect(s, contains('tiny'));
    expect(s, contains('the full layout'));
    expect(s, contains('family == .systemSmall'));
  });

  test('the accessory families that have no room take the compact tree', () {
    // Circular and inline are a lock-screen glyph and a single line of text.
    // Rectangular is wide enough for the full tree, so it must not be listed.
    return runIos([_def(compact: _compact())]).then((r) {
      final s = r.swiftForTestW();
      expect(s, contains('.accessoryCircular'));
      expect(s, contains('.accessoryInline'));
      expect(s, isNot(contains('family == .accessoryRectangular')));
    });
  });

  test('the compact tree survives the IR round trip', () {
    final json = _def(compact: _compact()).toJson();
    final back = IRDefinition.fromJson(json);
    expect(back.compactRoot, isNotNull);
    expect(back.compactRoot!.data['text'], 'tiny');
  });
}
