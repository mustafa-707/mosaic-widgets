import 'package:hw_core/hw_core.dart';
import 'package:test/test.dart';

void main() {
  test('deep_link_scheme defaults to mosaic', () {
    final c = HWConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b
widgets: []
''');
    expect(c.app.deepLinkScheme, 'mosaic');
  });

  test('deep_link_scheme parses explicit value', () {
    final c = HWConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b
  deep_link_scheme: myapp
widgets: []
''');
    expect(c.app.deepLinkScheme, 'myapp');
  });
}
