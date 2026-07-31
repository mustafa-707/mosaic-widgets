import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// A horizontal LinearLayout is `wrap_content` tall, so a child asking for
/// `match_parent` height is a circular constraint that Android resolves to
/// **zero** — the view silently does not render. No error, no log, nothing in the
/// generated XML looks wrong.
///
/// This bit MPadding (iteration 10), MFlexible (iteration 20), and then three
/// more handlers found by sweeping for it, so each is pinned here.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  Future<String> inRow(Map<String, dynamic> child) async {
    final r = await runAndroid([
      irDef({'__type': 'HWRow', 'children': [child]})
    ]);
    return layout(r);
  }

  /// The height attribute of the first element matching [tag].
  String? heightOf(String xml, String tag) =>
      RegExp('<$tag\\b[^>]*?android:layout_height="([^"]+)"')
          .firstMatch(xml)
          ?.group(1);

  test('a network image does not collapse inside a row', () async {
    final xml = await inRow({'__type': 'HWNetworkImage', 'url': 'https://a/b.jpg'});
    expect(heightOf(xml, 'ImageView'), 'wrap_content');
  });

  test('a list view does not collapse inside a row', () async {
    final xml = await inRow({
      '__type': 'HWListView',
      'bind': bind('items'),
      'itemTemplate': text('i'),
    });
    expect(heightOf(xml, 'ListView'), 'wrap_content');
    // Still weighted along the main axis.
    expect(xml, contains('android:layout_weight="1"'));
  });

  test('a stack does not collapse inside a row', () async {
    // The worst case: everything layered inside would vanish with it.
    final xml = await inRow({
      '__type': 'HWStack',
      'children': [text('layered')],
    });
    expect(xml, contains('layered'));
    expect(xml, isNot(contains('android:layout_height="match_parent">\n    <TextView')));
  });

  test('a stack still fills when it is the root', () async {
    // Outside a LinearLayout it must claim the whole widget as before.
    final r = await runAndroid([
      irDef({'__type': 'HWStack', 'children': [text('x')]})
    ]);
    expect(layout(r), contains('android:layout_height="match_parent"'));
  });

  test('a network image still fills inside a column', () async {
    // A Column is match_parent wide, so match_parent width is safe there.
    final r = await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [
          {'__type': 'HWNetworkImage', 'url': 'https://a/b.jpg'},
        ],
      })
    ]);
    final xml = layout(r);
    expect(
      RegExp(r'<ImageView\b[^>]*?android:layout_width="([^"]+)"')
          .firstMatch(xml)
          ?.group(1),
      'match_parent',
    );
  });

  test('no generated layout puts match_parent height inside a row', () async {
    // Sweep: every leaf and container type as a direct row child.
    const candidates = [
      {'__type': 'HWNetworkImage', 'url': 'https://a/b.jpg'},
      {'__type': 'HWStack', 'children': [{'__type': 'HWText', 'text': 'x'}]},
      {'__type': 'HWCenter', 'child': {'__type': 'HWText', 'text': 'x'}},
      {'__type': 'HWFlexible', 'flex': 1, 'child': {'__type': 'HWText', 'text': 'x'}},
      {'__type': 'HWSizedBox', 'width': 8},
    ];
    for (final c in candidates) {
      final xml = await inRow(c);
      // Ignore the root container, which is the only legitimate filler.
      final body = xml.substring(xml.indexOf('>', xml.indexOf('<FrameLayout')) + 1);
      final offenders = RegExp(r'android:layout_height="match_parent"')
          .allMatches(body)
          .length;
      expect(offenders, 0, reason: 'match_parent height under a row for ${c['__type']}');
    }
  });
}
