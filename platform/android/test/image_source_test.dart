import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('asset image references a drawable', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWImage',
        'source': {'__type': 'HWAssetImage', 'path': 'icon.png'},
        'fit': 'cover'
      })
    ]);
    expect(r.file('android/app/src/main/res/layout/hw_testw.xml'),
        contains('@drawable/icon'));
  });

  test('static file image path sets a static uri in the provider', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWImage',
        'source': {'__type': 'HWFileImage', 'path': '/data/pic.png'},
        'fit': 'cover'
      })
    ]);
    final kt = r.file(
      'android/app/src/main/kotlin/com/acme/app/hw_generated/TestWProvider.kt',
    );
    expect(kt, contains('setImageViewUri'));
    expect(kt, contains('/data/pic.png'));
  });

  test('bound file image still resolves at runtime', () async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWImage',
        'source': {
          '__type': 'HWFileImage',
          'path': {'__type': 'HWBind', 'key': 'pic'}
        },
        'fit': 'cover'
      })
    ]);
    final kt = r.file(
      'android/app/src/main/kotlin/com/acme/app/hw_generated/TestWProvider.kt',
    );
    expect(kt, contains('MosaicData.resolveString(context, "pic"'));
    expect(kt, contains('setImageViewUri'));
  });
}
