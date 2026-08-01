import 'dart:io';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  String drawables(r) {
    final dir = Directory('${r.root.path}/android/app/src/main/res/drawable');
    return dir
        .listSync()
        .map((f) => File(f.path).readAsStringSync())
        .join('\n');
  }

  test(
      'gradient with stops still emits a drawable and an approximation comment',
      () async {
    final r = await runAndroid([
      irDef(container(text('hi'), extra: {
        'gradient': {
          '__type': 'HWLinearGradient',
          'colors': [
            {'hex': '#FF0000', 'opacity': 1.0},
            {'hex': '#00FF00', 'opacity': 1.0},
            {'hex': '#0000FF', 'opacity': 1.0},
          ],
          'stops': [0.0, 0.2, 1.0],
        }
      }))
    ]);
    final xml = drawables(r);
    expect(xml, contains('<gradient'));
    expect(
        xml,
        contains(
            'gradient stops approximated: Android shape gradients support up to 3 positions'));
    // Layout still references the drawable.
    expect(r.file('android/app/src/main/res/layout/hw_testw.xml'),
        contains('@drawable/'));
  });

  test('gradient without stops emits no approximation comment', () async {
    final r = await runAndroid([
      irDef(container(text('hi'), extra: {
        'gradient': {
          '__type': 'HWLinearGradient',
          'colors': [
            {'hex': '#FF0000', 'opacity': 1.0},
            {'hex': '#0000FF', 'opacity': 1.0},
          ],
          'stops': null,
        }
      }))
    ]);
    final xml = drawables(r);
    expect(xml, contains('<gradient'));
    expect(xml, isNot(contains('stops approximated')));
  });
}
