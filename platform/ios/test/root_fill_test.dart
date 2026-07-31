import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// A root container applies its background before any outer `.frame`, so
/// without an expanding frame the background hugged its content and the
/// system's default widget background showed through as a light gutter around
/// the widget. The fill frame must land AFTER `.padding` (so padding stays
/// inside the tile) and BEFORE `.background` (so the background covers it).
void main() {
  Map<String, dynamic> bg() => {'hex': '#4A90D9', 'opacity': 1.0};

  test('root container expands to fill the tile', () async {
    final r = await runIos([
      irDef(container(text('hi'), extra: {'background': bg(), 'radius': 20.0}))
    ]);
    expect(r.swiftForTestW(),
        contains('.frame(maxWidth: .infinity, maxHeight: .infinity)'));
  });

  test('fill frame precedes the background so the background covers the tile',
      () async {
    final r = await runIos([
      irDef(container(text('hi'), extra: {'background': bg(), 'radius': 20.0}))
    ]);
    final s = r.swiftForTestW();
    final frame = s.indexOf('.frame(maxWidth: .infinity, maxHeight: .infinity)');
    final background = s.indexOf('.background(');
    expect(frame, greaterThan(-1));
    expect(background, greaterThan(-1));
    expect(frame, lessThan(background));
  });

  test('padding stays inside the filled area', () async {
    final r = await runIos([
      irDef(container(text('hi'), extra: {
        'background': bg(),
        'padding': {'top': 14.0, 'left': 14.0, 'bottom': 14.0, 'right': 14.0},
      }))
    ]);
    final s = r.swiftForTestW();
    expect(s.indexOf('.padding(EdgeInsets('),
        lessThan(s.indexOf('.frame(maxWidth: .infinity, maxHeight: .infinity)')));
  });

  test('only the outermost container fills — nested ones hug their content',
      () async {
    final r = await runIos([
      irDef(container(
        container(text('inner'), extra: {'background': bg()}),
        extra: {'background': bg()},
      ))
    ]);
    final s = r.swiftForTestW();
    expect('.frame(maxWidth: .infinity, maxHeight: .infinity)'.allMatches(s),
        hasLength(1));
  });

  test('a container with an explicit size is not overridden', () async {
    final r = await runIos([
      irDef(container(text('hi'),
          extra: {'background': bg(), 'width': 100.0, 'height': 50.0}))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.frame(width: 100.0, height: 50.0)'));
    expect(s, isNot(contains('.frame(maxWidth: .infinity, maxHeight: .infinity)')));
  });
}
