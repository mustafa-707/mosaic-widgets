import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';

void main() {
  test('controls list parses', () {
    final c = MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b
widgets: []
controls:
  - name: Flashlight
    entry: lib/controls/flashlight.control.dart
  - name: OpenApp
    entry: lib/controls/open_app.control.dart
''');
    expect(c.controls, hasLength(2));
    expect(c.controls[0].name, 'Flashlight');
    expect(c.controls[0].entry, 'lib/controls/flashlight.control.dart');
    expect(c.controls[1].name, 'OpenApp');
  });

  test('config without controls yields empty list (back-compat)', () {
    final c = MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b
widgets: []
''');
    expect(c.controls, isEmpty);
  });
}
