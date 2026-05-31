import 'package:hw_cli/src/commands/add_widget_command.dart';
import 'package:test/test.dart';

void main() {
  test('scaffold imports the mosaic package, not flutter', () {
    final out = widgetTemplate('Profile');
    expect(out, contains("import 'package:mosaic/mosaic.dart';"));
    expect(out, isNot(contains("package:flutter/hw_dsl.dart")));
    expect(out, contains('buildProfile'));
  });
}
