import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Android TV is not a widget surface.
///
/// The Android TV and Google TV launchers host **no AppWidgets at all**, so a
/// RemoteViews tree never appears there however it is declared. What the TV
/// home screen shows is channels of preview programs published through
/// `TvProvider`, and the launcher draws those cards itself — there is no layout
/// to generate, only content to publish.
MosaicConfig _config({bool withTv = true}) => MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
      },
      'widgets': [
        {
          'name': 'TestW',
          'entry': 'TestW',
          'android': {
            'min_sdk': 21,
            'sizes': ['medium'],
          },
        },
      ],
      if (withTv)
        'tv_channels': [
          {'name': 'featured', 'display_name': 'Featured'},
        ],
    });

void main() {
  String tv(r) => r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicTv.kt',
      );

  test('a declared channel generates the publisher', () async {
    final r = await runAndroid([irDef(text('x'))], config: _config());
    final kt = tv(r);
    expect(kt, contains('object MosaicTv'));
    expect(kt, contains('"featured" to "Featured"'));
  });

  test('it uses the framework TvContract, not androidx.tvprovider', () async {
    // The support library only wraps these same ContentValues. Requiring it
    // would mean editing the app's build.gradle for a feature most projects
    // never enable.
    final kt = tv(await runAndroid([irDef(text('x'))], config: _config()));
    expect(kt, contains('import android.media.tv.TvContract'));
    // The generated file *mentions* androidx.tvprovider in a comment
    // explaining why it is not used, so assert on the import specifically.
    expect(kt, isNot(contains('import androidx.tvprovider')));
  });

  test('preview programs are gated to API 26', () async {
    // TvContract.PreviewPrograms did not exist before O; calling it on an
    // older device throws rather than degrading.
    final kt = tv(await runAndroid([irDef(text('x'))], config: _config()));
    expect(kt, contains('Build.VERSION_CODES.O'));
  });

  test('a device with no TV provider does not crash the app', () async {
    // Every phone running this app hits these paths if the developer calls
    // publish; an absent provider must be survivable.
    final kt = tv(await runAndroid([irDef(text('x'))], config: _config()));
    expect(kt, contains('catch (e: Exception)'));
  });

  test('a project without tv_channels generates nothing', () async {
    // WRITE_EPG_DATA and a TV receiver are not things a phone-only app should
    // carry because it happens to use this package.
    final r = await runAndroid([
      irDef(text('x')),
    ], config: _config(withTv: false));
    expect(
      r.fileOrNull(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicTv.kt',
      ),
      isNull,
    );
  });

  test('the plugin reports unsupported when no channel is declared', () async {
    // Better than a MissingPluginException: the Dart side can tell the
    // difference between "not on Android" and "you did not declare one".
    final plugin = (await runAndroid([
      irDef(text('x')),
    ], config: _config(withTv: false)))
        .file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicPlugin.kt',
    );
    expect(plugin, contains('publishTvChannel'));
    expect(plugin, contains('No tv_channels declared'));
  });
}
