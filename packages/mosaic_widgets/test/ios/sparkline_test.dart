import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  Map<String, dynamic> spark({bool fill = false}) => {
        '__type': 'HWSparkline',
        'bind': bind('series'),
        'color': {'hex': '#38BDF8'},
        'strokeWidth': 2,
        'fill': fill,
      };

  test('draws a real Path rather than a rasterised image', () async {
    final r = await runIos([irDef(spark())]);
    final swift = r.swiftForTestW();
    expect(swift, contains('Path { p in'));
    expect(swift, contains('.stroke('));
    expect(swift, contains('mosaicNumList(entry.data["series"])'));
  });

  test('normalises inside a GeometryReader', () async {
    // A Path cannot know its own size, so the box has to come from outside.
    final r = await runIos([irDef(spark())]);
    expect(r.swiftForTestW(), contains('GeometryReader { geo in'));
  });

  test('a series shorter than two points draws nothing', () async {
    final r = await runIos([irDef(spark())]);
    expect(r.swiftForTestW(), contains('guard points.count > 1'));
  });

  test('a flat series does not divide by zero', () async {
    final r = await runIos([irDef(spark())]);
    expect(r.swiftForTestW(), contains('(hi - lo) == 0 ? 1 : (hi - lo)'));
  });

  test('fill adds a closed path under the line', () async {
    final withFill = await runIos([irDef(spark(fill: true))]);
    expect(withFill.swiftForTestW(), contains('closeSubpath()'));
    final without = await runIos([irDef(spark())]);
    expect(without.swiftForTestW(), isNot(contains('closeSubpath()')));
  });

  test('the numeric coercion tolerates strings and JSON text', () async {
    // The store round-trips through JSON, so a saved list can arrive in any of
    // three shapes.
    final r = await runIos([irDef(spark())]);
    final core =
        readFile(r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));
    expect(core, contains('func mosaicNumList'));
    expect(core, contains('JSONSerialization'));
  });
}
