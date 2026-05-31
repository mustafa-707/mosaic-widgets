import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('asset image emits Image(named) reference', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWImage',
        'source': {'__type': 'HWAssetImage', 'path': 'icon.png'},
        'fit': 'cover'
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('Image('));
    // asset name without extension (Xcode asset catalog references)
    expect(s, contains('Image("icon")'));
  });

  test('asset image without extension is left intact', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWImage',
        'source': {'__type': 'HWAssetImage', 'path': 'logo'},
        'fit': 'contain'
      })
    ]);
    expect(r.swiftForTestW(), contains('Image("logo")'));
  });

  test('static file image loads via resolveFileImage', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWImage',
        'source': {'__type': 'HWFileImage', 'path': '/tmp/pic.jpg'},
        'fit': 'cover'
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('resolveFileImage("/tmp/pic.jpg")'));
    expect(s, contains('Image(uiImage:'));
  });

  test('bound file image reads entry data', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWImage',
        'source': {
          '__type': 'HWFileImage',
          'path': {'__type': 'HWBind', 'key': 'avatar'}
        },
        'fit': 'cover'
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('resolveFileImage((entry.data["avatar"] as? String))'));
  });
}
