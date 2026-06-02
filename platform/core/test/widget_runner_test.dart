import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';

void main() {
  test('parses JSON between sentinels ignoring surrounding logs (legacy list)',
      () {
    const out = 'Debug: starting\n'
        '<<<MOSAIC_IR>>>[{"name":"A"}]<<<END_MOSAIC_IR>>>\n'
        'Warning: trailing line';
    final parsed = WidgetRunner.parseIrOutput(out);
    expect(parsed, [
      {'name': 'A'}
    ]);
  });

  test('parseIrOutput returns widgets from the new object form', () {
    const out = 'Debug: starting\n'
        '<<<MOSAIC_IR>>>{"widgets":[{"name":"A"}],"liveActivities":[{"name":"L"}]}<<<END_MOSAIC_IR>>>\n'
        'Warning: trailing line';
    final parsed = WidgetRunner.parseIrOutput(out);
    expect(parsed, [
      {'name': 'A'}
    ]);
  });

  test('parseLiveActivities returns live activities from the object form', () {
    const out =
        '<<<MOSAIC_IR>>>{"widgets":[{"name":"A"}],"liveActivities":[{"name":"L"}]}<<<END_MOSAIC_IR>>>';
    final parsed = WidgetRunner.parseLiveActivities(out);
    expect(parsed, [
      {'name': 'L'}
    ]);
  });

  test('parseLiveActivities returns [] for the legacy list form', () {
    const out = '<<<MOSAIC_IR>>>[{"name":"A"}]<<<END_MOSAIC_IR>>>';
    expect(WidgetRunner.parseLiveActivities(out), isEmpty);
  });

  test('parseLiveActivities returns [] when liveActivities key absent', () {
    const out = '<<<MOSAIC_IR>>>{"widgets":[{"name":"A"}]}<<<END_MOSAIC_IR>>>';
    expect(WidgetRunner.parseLiveActivities(out), isEmpty);
  });

  test('throws a clear error when sentinels are absent', () {
    expect(() => WidgetRunner.parseIrOutput('no markers here'),
        throwsA(isA<Exception>()));
  });

  test('parseControls returns controls from the object form', () {
    const out =
        '<<<MOSAIC_IR>>>{"widgets":[{"name":"A"}],"liveActivities":[],"controls":[{"__type":"HWControl","name":"Torch"}]}<<<END_MOSAIC_IR>>>';
    final parsed = WidgetRunner.parseControls(out);
    expect(parsed, [
      {'__type': 'HWControl', 'name': 'Torch'}
    ]);
  });

  test('parseControls returns [] for the legacy bare-list form', () {
    const out = '<<<MOSAIC_IR>>>[{"name":"A"}]<<<END_MOSAIC_IR>>>';
    expect(WidgetRunner.parseControls(out), isEmpty);
  });

  test('parseControls returns [] when controls key is absent', () {
    const out =
        '<<<MOSAIC_IR>>>{"widgets":[{"name":"A"}],"liveActivities":[]}<<<END_MOSAIC_IR>>>';
    expect(WidgetRunner.parseControls(out), isEmpty);
  });
}
