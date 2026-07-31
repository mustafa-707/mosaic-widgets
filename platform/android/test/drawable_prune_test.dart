import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Generated drawables are named by a content hash, so changing a radius, a
/// border or a colour writes a *new* file and strands the old one.
///
/// A stranded drawable is not just clutter. It still references the colour
/// resource it was written against, and once nothing re-registers that colour
/// the next build dies with `AAPT: error: resource color/mosaic_… not found`
/// — naming a drawable file that no layout uses, which is close to unfindable
/// by hand. This is exactly how it was discovered.
void main() {
  Map<String, dynamic> rounded(String hex, double radius) => {
        '__type': 'HWContainer',
        'radius': radius,
        'background': {'hex': hex, 'dark': '#000000', 'opacity': 1.0},
        'child': text('x'),
      };

  Directory drawableDir(r) =>
      Directory(p.join(r.root.path, 'android/app/src/main/res/drawable'));

  List<String> generatedNames(r) => drawableDir(r)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.xml'))
      .map((f) => p.basenameWithoutExtension(f.path))
      .toList()
    ..sort();

  test('a drawable from a previous build does not survive', () async {
    final r = await runAndroid([irDef(rounded('#FF0000', 8))]);
    final before = generatedNames(r);
    expect(before, isNotEmpty);

    // Same project, different radius: a new hash, and the old file is stale.
    final r2 = await runAndroid([irDef(rounded('#FF0000', 16))], root: r.root);
    final after = generatedNames(r2);
    expect(after, isNot(contains(before.first)),
        reason: 'the superseded drawable is still on disk');
  });

  test('a hand-written drawable is never deleted', () async {
    final r = await runAndroid([irDef(rounded('#FF0000', 8))]);
    final mine = File(p.join(drawableDir(r).path, 'hw_bg_mine.xml'));
    // Same prefix as generated files, but no sentinel — it is the developer's.
    mine.writeAsStringSync('<?xml version="1.0"?>\n<shape/>\n');

    await runAndroid([irDef(rounded('#FF0000', 16))], root: r.root);
    expect(mine.existsSync(), isTrue,
        reason: 'pruning must key off the sentinel, not the filename');
  });

  test('drawables still in use are kept', () async {
    final r = await runAndroid([irDef(rounded('#00FF00', 12))]);
    final names = generatedNames(r);
    final r2 = await runAndroid([irDef(rounded('#00FF00', 12))], root: r.root);
    expect(generatedNames(r2), equals(names));
  });
}
