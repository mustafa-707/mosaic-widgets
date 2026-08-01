import 'package:mosaic_widgets/src/cli/commands/build_command.dart';
import 'package:test/test.dart';

/// Manifest automation only ever appended, so a renamed widget — or the
/// hw_generated → mosaic_generated package move — left receivers pointing at
/// classes that no longer exist. Android still registers those providers and
/// the launcher cannot instantiate them, which the user sees as "Can't load
/// widget" on every widget in the app.
String manifest(String body) => '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="demo">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
            </intent-filter>
        </activity>
$body
    </application>
</manifest>
''';

String receiver(String className) => '''
        <receiver android:name="$className" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/hw_news_info" />
        </receiver>''';

void main() {
  const pkg = 'com.example.demo_app';
  const current = '$pkg.mosaic_generated.NewsWidgetProvider';
  const legacy = '$pkg.hw_generated.NewsWidgetProvider';

  test('removes receivers from the pre-rename hw_generated package', () {
    final result = pruneStaleMosaicManifestEntries(
      manifest('${receiver(legacy)}\n${receiver(current)}'),
      pkg,
      keepClasses: {current},
    );
    expect(result, isNot(contains(legacy)));
    expect(result, contains(current));
  });

  test('removes a generated receiver whose widget no longer exists', () {
    const removed = '$pkg.mosaic_generated.OldWidgetProvider';
    final result = pruneStaleMosaicManifestEntries(
      manifest('${receiver(removed)}\n${receiver(current)}'),
      pkg,
      keepClasses: {current},
    );
    expect(result, isNot(contains(removed)));
    expect(result, contains(current));
  });

  test('never touches hand-written components', () {
    final source = manifest(receiver(current));
    final result = pruneStaleMosaicManifestEntries(
      source,
      pkg,
      keepClasses: {current},
    );
    expect(result, contains('.MainActivity'));
    expect(result, contains('android.intent.action.MAIN'));
    expect(result, equals(source));
  });

  test('prunes stale config activities and services too', () {
    final body = '''
        <activity android:name="$pkg.mosaic_generated.GoneConfigActivity" android:exported="true">
        </activity>
        <service android:name="$pkg.mosaic_generated.MosaicListService" android:exported="false">
        </service>''';
    final result = pruneStaleMosaicManifestEntries(
      manifest(body),
      pkg,
      keepClasses: {'$pkg.mosaic_generated.MosaicListService'},
    );
    expect(result, isNot(contains('GoneConfigActivity')));
    expect(result, contains('MosaicListService'));
  });

  test('leaves a manifest with nothing stale byte-identical', () {
    final source = manifest(receiver(current));
    expect(
      pruneStaleMosaicManifestEntries(source, pkg, keepClasses: {current}),
      equals(source),
    );
  });
}
