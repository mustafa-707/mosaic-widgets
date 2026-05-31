import 'package:mosaic_cli/src/commands/add_widget_command.dart';
import 'package:test/test.dart';

void main() {
  test('scaffold imports the mosaic package, not flutter', () {
    final out = widgetTemplate('Profile');
    // Widget definitions import the pure-Dart DSL (not the Flutter-dependent
    // barrel), so the build runner can execute them under `dart run`.
    expect(out, contains("import 'package:mosaic/dsl.dart';"));
    expect(out, isNot(contains("package:mosaic/mosaic.dart")));
    expect(out, isNot(contains("package:flutter/hw_dsl.dart")));
    expect(out, contains('buildProfile'));
  });
}
