import 'package:hw_core/hw_core.dart';
import 'package:test/test.dart';

void main() {
  test('parses JSON between sentinels ignoring surrounding logs', () {
    const out = 'Debug: starting\n'
        '<<<MOSAIC_IR>>>[{"name":"A"}]<<<END_MOSAIC_IR>>>\n'
        'Warning: trailing line';
    final parsed = WidgetRunner.parseIrOutput(out);
    expect(parsed, [{'name': 'A'}]);
  });

  test('throws a clear error when sentinels are absent', () {
    expect(() => WidgetRunner.parseIrOutput('no markers here'),
        throwsA(isA<Exception>()));
  });
}
