import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String layout(r) => r.file('android/app/src/main/res/layout/hw_testw.xml');

  Future<String> imageWithFit(String? fit) async {
    final r = await runAndroid([
      irDef({
        '__type': 'HWImage',
        'source': {'__type': 'HWAssetImage', 'path': 'icon.png'},
        if (fit != null) 'fit': fit,
      })
    ]);
    return layout(r);
  }

  test('fit contain maps to fitCenter', () async {
    expect(await imageWithFit('contain'),
        contains('android:scaleType="fitCenter"'));
  });

  test('fit cover maps to centerCrop', () async {
    expect(await imageWithFit('cover'),
        contains('android:scaleType="centerCrop"'));
  });

  test('default (no fit) stays centerCrop', () async {
    expect(
        await imageWithFit(null), contains('android:scaleType="centerCrop"'));
  });

  test('fill maps to fitXY', () async {
    expect(await imageWithFit('fill'), contains('android:scaleType="fitXY"'));
  });

  test('fitWidth maps to fitStart', () async {
    expect(await imageWithFit('fitWidth'),
        contains('android:scaleType="fitStart"'));
  });

  test('fitHeight maps to fitEnd', () async {
    expect(await imageWithFit('fitHeight'),
        contains('android:scaleType="fitEnd"'));
  });

  test('none maps to center', () async {
    expect(await imageWithFit('none'), contains('android:scaleType="center"'));
  });

  test('scaleDown maps to centerInside', () async {
    expect(await imageWithFit('scaleDown'),
        contains('android:scaleType="centerInside"'));
  });
}
