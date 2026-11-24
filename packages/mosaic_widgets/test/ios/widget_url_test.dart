import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('without widgetUrl the legacy global_url read is unchanged', () async {
    final r = await runIos([irDef(text('hi'))]);
    final s = r.swiftForTestW();
    expect(s, contains('.widgetURL(URL(string: loadGlobalUrl()))'));
    expect(s, contains('return entry.data["global_url"] as? String ?? ""'));
  });

  test('literal widgetUrl is the widget-level url', () async {
    final r = await runIos([
      IRDefinition(
          name: 'TestW',
          root: IRNode.fromJson(text('hi')),
          widgetUrl: 'mosaic://offer/1')
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.widgetURL(URL(string: loadGlobalUrl()))'));
    expect(s, contains('return "mosaic://offer/1"'));
  });

  test('bound widgetUrl reads its key, then global_url, then the default',
      () async {
    final r = await runIos([
      IRDefinition(
          name: 'TestW',
          root: IRNode.fromJson(text('hi')),
          widgetUrl: {
            '__type': 'HWBind',
            'key': 'offer_url',
            'defaultValue': 'mosaic://home'
          })
    ]);
    final s = r.swiftForTestW();
    expect(
        s,
        contains('return (entry.data["offer_url"] as? String) ?? '
            '(entry.data["global_url"] as? String) ?? "mosaic://home"'));
    // The key must be loaded from the App Group, or the read is always nil.
    expect(s, contains('"offer_url"'));
    expect(RegExp(r'for k in \[[^\]]*"offer_url"[^\]]*\]').hasMatch(s), isTrue);
  });

  test('bound timer shows zero when the key is missing or in the past',
      () async {
    final r = await runIos([
      irDef({
        '__type': 'HWTimer',
        'target': {'__type': 'HWBind', 'key': 'ends_at'},
        'countUp': false,
        'style': <String, dynamic>{},
      })
    ]);
    final s = r.swiftForTestW();
    expect(
        s,
        contains('if let _ms = mosaicNum(entry.data["ends_at"]), '
            '_ms / 1000.0 > Date().timeIntervalSince1970'));
    // iOS 16+ stops at 0:00 on its own; `.timer` is the pre-16 fallback.
    expect(s, contains('Text(timerInterval: Date()..._d, countsDown: true)'));
    expect(s, contains('Text(_d, style: .timer)'));
    expect(s, contains('Text("0:00")'));
  });

  test('bound count-up timer only hides when the key is missing', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWTimer',
        'target': {'__type': 'HWBind', 'key': 'since'},
        'countUp': true,
        'style': <String, dynamic>{},
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('if let _ms = mosaicNum(entry.data["since"]) {'));
    expect(s, contains('countsDown: false'));
    expect(s, contains('Text("0:00")'));
  });
}
