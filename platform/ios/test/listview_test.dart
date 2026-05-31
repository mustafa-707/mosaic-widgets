import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('listview decodes bound array and ForEach over elements', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWListView',
        'bind': bind('items'),
        'itemTemplate': text(bind('title'))
      })
    ]);
    final s = r.swiftForTestW();
    // real data path: reads the bound array from entry data
    expect(s, contains('entry.data["items"] as? [[String: Any]]'));
    expect(s, contains('ForEach('));
    expect(s, contains('.enumerated()'));
    // stable id
    expect(s, contains(r'id: \.offset'));
  });

  test('listview item binds resolve against the current element', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWListView',
        'bind': bind('items'),
        'itemTemplate': text(bind('title'))
      })
    ]);
    final s = r.swiftForTestW();
    // The item template's HWBind reads item["title"], not entry.data["title"]
    expect(s, contains('item["title"]'));
    // no hardcoded stub
    expect(s, isNot(contains('Text("List Item")')));
  });

  test('outer binds still resolve against entry.data after a listview',
      () async {
    final r = await runIos([
      irDef({
        '__type': 'HWColumn',
        'children': [
          {
            '__type': 'HWListView',
            'bind': bind('items'),
            'itemTemplate': text(bind('title'))
          },
          text(bind('footer')),
        ]
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('item["title"]'));
    // bindSource restored: the footer text reads entry.data, not item
    expect(s, contains('entry.data["footer"]'));
  });
}
