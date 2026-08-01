import 'dart:io';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('gradient container writes a gradient drawable and references it',
      () async {
    final r = await runAndroid([
      irDef(container(text('hi'), extra: {
        'gradient': {
          '__type': 'HWLinearGradient',
          'colors': [
            {'hex': '#FF0000', 'opacity': 1.0},
            {'hex': '#0000FF', 'opacity': 1.0}
          ],
          'stops': null
        }
      }))
    ]);
    // find a generated gradient drawable
    final dir = Directory('${r.root.path}/android/app/src/main/res/drawable');
    expect(
        dir.existsSync() &&
            dir.listSync().any((f) => f.path.contains('gradient')),
        isTrue);
    expect(r.file('android/app/src/main/res/layout/hw_testw.xml'),
        contains('@drawable/'));
  });

  test('border container writes a shape drawable with stroke', () async {
    final r = await runAndroid([
      irDef(container(text('hi'), extra: {
        'border': {
          'color': {'hex': '#00FF00', 'opacity': 1.0},
          'width': 2.0
        },
        'radius': 8.0
      }))
    ]);
    final dir = Directory('${r.root.path}/android/app/src/main/res/drawable');
    final files =
        dir.listSync().map((f) => File(f.path).readAsStringSync()).join('\n');
    expect(files, contains('<stroke'));
  });
}
