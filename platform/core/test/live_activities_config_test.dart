import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';

void main() {
  test('live_activities list parses', () {
    final c = MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b
widgets: []
live_activities:
  - name: Delivery
    entry: lib/activities/delivery.dart
  - name: Workout
    entry: lib/activities/workout.dart
''');
    expect(c.liveActivities, hasLength(2));
    expect(c.liveActivities[0].name, 'Delivery');
    expect(c.liveActivities[0].entry, 'lib/activities/delivery.dart');
    expect(c.liveActivities[1].name, 'Workout');
  });

  test('config without live_activities yields empty list (back-compat)', () {
    final c = MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b
widgets: []
''');
    expect(c.liveActivities, isEmpty);
  });
}
