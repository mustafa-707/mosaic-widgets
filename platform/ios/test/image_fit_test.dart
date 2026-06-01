import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

Future<String> _img(String fit) async {
  final r = await runIos([
    irDef({
      '__type': 'HWImage',
      'source': {'__type': 'HWAssetImage', 'path': 'icon'},
      'fit': fit,
    })
  ]);
  return r.swiftForTestW();
}

void main() {
  test('cover -> aspectRatio fill', () async {
    final s = await _img('cover');
    expect(s, contains('.resizable()'));
    expect(s, contains('.aspectRatio(contentMode: .fill)'));
  });

  test('contain -> aspectRatio fit', () async {
    final s = await _img('contain');
    expect(s, contains('.aspectRatio(contentMode: .fit)'));
  });

  test('fill -> resizable, no aspectRatio', () async {
    final s = await _img('fill');
    expect(s, contains('.resizable()'));
    expect(s, isNot(contains('.aspectRatio(')));
  });

  test('fitWidth -> resizable fit with maxWidth infinity', () async {
    final s = await _img('fitWidth');
    expect(s, contains('.resizable()'));
    expect(s, contains('.aspectRatio(contentMode: .fit)'));
    expect(s, contains('maxWidth: .infinity'));
  });

  test('fitHeight -> resizable fit with maxHeight infinity', () async {
    final s = await _img('fitHeight');
    expect(s, contains('.aspectRatio(contentMode: .fit)'));
    expect(s, contains('maxHeight: .infinity'));
  });

  test('none -> no resizable (intrinsic)', () async {
    final s = await _img('none');
    expect(s, isNot(contains('.resizable()')));
  });

  test('scaleDown -> resizable fit', () async {
    final s = await _img('scaleDown');
    expect(s, contains('.resizable()'));
    expect(s, contains('.aspectRatio(contentMode: .fit)'));
  });
}
