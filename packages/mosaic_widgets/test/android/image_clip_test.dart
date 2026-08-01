import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// RemoteViews has no clip API and no clip attribute, so a rounded or circular
/// image is expressed as an outline-shaped background drawable plus
/// setClipToOutline driven from the provider.
void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  test('circle emits an oval outline and enables clipping', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWNetworkImage',
        'url': 'https://cdn.example.com/a.jpg',
        'circle': true,
      })
    ]);
    expect(layout(r), contains('android:background="@drawable/hw_clip_'));
    expect(provider(r), contains('"setClipToOutline", true'));

    final drawable = r.resXmlFiles().firstWhere(
        (f) => f.path.contains('hw_clip_'),
        orElse: () => throw StateError('no clip drawable emitted'));
    expect(drawable.readAsStringSync(), contains('android:shape="oval"'));
  });

  test('radius emits rounded corners', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWNetworkImage',
        'url': 'https://cdn.example.com/a.jpg',
        'radius': 12.0,
      })
    ]);
    final drawable =
        r.resXmlFiles().firstWhere((f) => f.path.contains('hw_clip_'));
    expect(drawable.readAsStringSync(), contains('android:radius="12.0dp"'));
  });

  test('plain images are untouched', () async {
    final r = await runAndroid([
      irDef({'__type': 'HWNetworkImage', 'url': 'https://a/b.jpg'})
    ]);
    expect(layout(r), isNot(contains('hw_clip_')));
    expect(provider(r), isNot(contains('setClipToOutline')));
  });

  test('a clip shape wins the background slot over the placeholder', () async {
    // Both want android:background; the shape must win or clipping breaks.
    final r = await runAndroid([
      irDef({
        '__type': 'HWNetworkImage',
        'url': 'https://a/b.jpg',
        'circle': true,
        'placeholder': {'hex': '#123456', 'opacity': 1.0},
      })
    ]);
    final xml = layout(r);
    expect(xml, contains('@drawable/hw_clip_'));
    expect(xml, isNot(contains('android:background="#')));
  });

  test('asset images can be circular too', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWImage',
        'source': {'__type': 'HWAssetImage', 'path': 'avatar.png'},
        'circle': true,
      })
    ]);
    expect(layout(r), contains('@drawable/hw_clip_'));
    expect(provider(r), contains('"setClipToOutline", true'));
  });

  test('identical shapes collapse to one drawable', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWRow',
        'children': [
          {
            '__type': 'HWNetworkImage',
            'url': 'https://a/1.jpg',
            'circle': true
          },
          {
            '__type': 'HWNetworkImage',
            'url': 'https://a/2.jpg',
            'circle': true
          },
        ],
      })
    ]);
    final clips =
        r.resXmlFiles().where((f) => f.path.contains('hw_clip_')).length;
    expect(clips, 1);
  });
}
