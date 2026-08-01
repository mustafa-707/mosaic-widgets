import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/gen_harness.dart';

/// Two bugs that only showed up on a real iOS home screen.
IRDefinition _def(IRNode root) => IRDefinition(name: 'TestW', root: root);

void main() {
  test('a bound list is parsed, not cast', () async {
    // `MosaicBridge.saveList` JSON-encodes to a String, because Android's store
    // holds only strings. iOS cast straight to `[[String: Any]]`, which is nil
    // for a String — so every MListView rendered empty, silently, forever.
    final r = await runIos([
      _def(IRNode.fromJson({
        '__type': 'HWListView',
        'bind': {'__type': 'HWBind', 'key': 'tasks'},
        'itemTemplate': {
          '__type': 'HWText',
          'text': {'__type': 'HWBind', 'key': 'title'},
          'style': {},
        },
      }))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('mosaicRowList(entry.data["tasks"])'));
    expect(s, isNot(contains('as? [[String: Any]] ?? []')));
  });

  test('the parser accepts both shapes and neither crashes', () async {
    final core = readFile((await runIos([
      _def(IRNode.fromJson({
        '__type': 'HWListView',
        'bind': {'__type': 'HWBind', 'key': 'rows'},
        'itemTemplate': {'__type': 'HWText', 'text': 'x', 'style': {}},
      }))
    ]))
        .file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));
    expect(core, contains('func mosaicRowList'));
    // Already-decoded arrays pass through; strings are decoded; anything else
    // yields an empty list rather than throwing inside a view body.
    expect(core,
        contains('if let rows = value as? [[String: Any]] { return rows }'));
    expect(core, contains('JSONSerialization.jsonObject'));
    expect(core, contains('return []'));
  });

  test('a declared currency code is used verbatim', () async {
    // Without it the amount renders in the *device's* currency: a BTC/USD
    // widget showed "JOD 64,510.000" on a phone set to Jordan, relabelling the
    // number without converting it.
    final s = (await runIos([
      _def(IRNode.fromJson({
        '__type': 'HWText',
        'text': {'__type': 'HWBind', 'key': 'price'},
        'style': {},
        'format': 'currency',
        'currencyCode': 'USD',
      }))
    ]))
        .swiftForTestW();
    expect(s, contains('.currency(code: "USD")'));
    expect(s, isNot(contains('Locale.current.currency')));
  });

  test('without a code it still follows the device', () async {
    // Correct when the amount really is in the user's own currency.
    final s = (await runIos([
      _def(IRNode.fromJson({
        '__type': 'HWText',
        'text': {'__type': 'HWBind', 'key': 'price'},
        'style': {},
        'format': 'currency',
      }))
    ]))
        .swiftForTestW();
    expect(s, contains('Locale.current.currency?.identifier ?? "USD"'));
  });
}
