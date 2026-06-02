import 'package:mosaic_cli/src/commands/build_command.dart';
import 'package:test/test.dart';

void main() {
  group('controlsProgressMessage', () {
    test('returns message for non-empty controls', () {
      expect(controlsProgressMessage(3), 'Generating 3 controls...');
    });

    test('returns message for a single control', () {
      expect(controlsProgressMessage(1), 'Generating 1 controls...');
    });

    test('returns null for zero controls', () {
      expect(controlsProgressMessage(0), isNull);
    });
  });
}
