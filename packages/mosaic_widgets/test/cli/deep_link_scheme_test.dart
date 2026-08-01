import 'package:mosaic_widgets/src/cli/commands/build_command.dart';
import 'package:mosaic_widgets/src/cli/validate.dart';
import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';

/// Only the declared `deep_link_scheme` is registered as an intent filter, so a
/// widget button on any other custom scheme resolves to nothing — a dead tap
/// with no error on either platform. The demo shipped exactly that bug: widgets
/// used `hwdemo://` while the manifest registered the default `mosaic`.
MosaicConfig configWithScheme(String? scheme) => MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
        if (scheme != null) 'deep_link_scheme': scheme,
      },
      'widgets': [
        {
          'name': 'TestW',
          'entry': 'TestW',
          'android': {
            'min_sdk': 21,
            'sizes': ['medium']
          },
          'ios': {
            'families': ['systemMedium']
          },
        },
      ],
    });

IRDefinition defWithUrls(List<String> urls) => IRDefinition.fromJson({
      'name': 'TestW',
      'width': 4,
      'height': 2,
      'root': {
        '__type': 'HWColumn',
        'children': [
          for (final u in urls)
            {
              '__type': 'HWButton',
              'action': {'__type': 'HWLaunchUrlAction', 'url': u},
              'child': {'__type': 'HWText', 'text': 'tap'},
            },
        ],
      },
    });

void main() {
  group('scheme validation', () {
    test('finds every launch URL in the tree', () {
      final urls = referencedLaunchUrls([
        defWithUrls(['a://b', 'c://d'])
      ]);
      expect(urls, {'a://b', 'c://d'});
    });

    test('a mismatched custom scheme is fatal and names both schemes', () {
      final problems = validateLaunchUrls([
        defWithUrls(['hwdemo://search'])
      ], configWithScheme(null));
      expect(problems, hasLength(1));
      expect(problems.single.fatal, isTrue);
      expect(problems.single.message, contains('hwdemo'));
      // The default is `mosaic`, which is what silently registered instead.
      expect(problems.single.message, contains('"mosaic"'));
    });

    test('the declared scheme passes', () {
      expect(
        validateLaunchUrls([
          defWithUrls(['hwdemo://search?mode=voice'])
        ], configWithScheme('hwdemo')),
        isEmpty,
      );
    });

    test('http and https are left alone — they open a browser', () {
      expect(
        validateLaunchUrls([
          defWithUrls(['https://example.com', 'http://example.com'])
        ], configWithScheme('hwdemo')),
        isEmpty,
      );
    });

    test('a scheme-less URL is fatal', () {
      final problems = validateLaunchUrls([
        defWithUrls(['/just/a/path'])
      ], configWithScheme('hwdemo'));
      expect(problems, hasLength(1));
      expect(problems.single.fatal, isTrue);
      expect(problems.single.message, contains('no scheme'));
    });

    test('widgets with no launch URLs produce nothing', () {
      final def = IRDefinition.fromJson({
        'name': 'TestW',
        'width': 4,
        'height': 2,
        'root': {'__type': 'HWText', 'text': 'x'},
      });
      expect(validateLaunchUrls([def], configWithScheme(null)), isEmpty);
    });
  });

  group('manifest filter is replaced, not accumulated', () {
    String manifestWith(String body) => '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <activity android:name=".MainActivity" android:exported="true">
$body
        </activity>
    </application>
</manifest>
''';

    test('a generated filter is stripped', () {
      final m = manifestWith(deepLinkFilter('mosaic'));
      final stripped = stripGeneratedDeepLinkFilters(m);
      expect(stripped, isNot(contains('android:scheme="mosaic"')));
      expect(stripped, contains('.MainActivity'));
    });

    test('changing the scheme leaves exactly one filter', () {
      // The old behaviour only ever ADDED, so a changed scheme left the
      // previous one registered alongside the new — two live schemes.
      var m = manifestWith(deepLinkFilter('mosaic'));
      m = stripGeneratedDeepLinkFilters(m);
      m = m.replaceFirst(
          '<activity android:name=".MainActivity" android:exported="true">',
          '<activity android:name=".MainActivity" android:exported="true">\n${deepLinkFilter('hwdemo')}');
      expect('android:scheme='.allMatches(m).length, 1);
      expect(m, contains('android:scheme="hwdemo"'));
    });

    test('a hand-written filter is never stripped', () {
      const handWritten = '''
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <data android:scheme="https" android:host="acme.com" />
            </intent-filter>''';
      final m = manifestWith('$handWritten\n${deepLinkFilter('mosaic')}');
      final stripped = stripGeneratedDeepLinkFilters(m);
      expect(stripped, contains('android:host="acme.com"'));
      expect(stripped, isNot(contains('android:scheme="mosaic"')));
    });

    test('stripping is safe when no filter is present', () {
      final m = manifestWith('            <meta-data android:name="x" />');
      expect(stripGeneratedDeepLinkFilters(m), equals(m));
    });

    test('the scheme is XML-escaped', () {
      expect(deepLinkFilter('a&b'), contains('android:scheme="a&amp;b"'));
    });
  });
}
