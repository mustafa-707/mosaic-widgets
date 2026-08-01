import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// `requestPinWidget` is the in-app "Add to Home Screen" prompt. It needs a
/// name-to-provider map because the Dart caller knows only the mosaic.yaml
/// name, never the generated Kotlin class.
void main() {
  Future<String> plugin({List<String> names = const ['TestW']}) async {
    // The map is built from the widget definitions, so no config entry is
    // needed per name here.
    final r =
        await runAndroid([for (final n in names) irDef(text('x'), name: n)]);
    return r.file(
        'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicPlugin.kt');
  }

  test('every widget is mapped to its generated provider class', () async {
    final kt = await plugin(names: ['News', 'Weather']);
    expect(
        kt,
        contains(
            '"News" to com.acme.app.mosaic_generated.NewsProvider::class.java'));
    expect(
        kt,
        contains(
            '"Weather" to com.acme.app.mosaic_generated.WeatherProvider::class.java'));
  });

  test('the pin request goes through the launcher, not an activity', () async {
    final kt = await plugin();
    expect(kt, contains('manager.requestPinAppWidget('));
    expect(kt, contains('ComponentName(context, provider)'));
  });

  test('an unknown name is a developer error, and lists what is valid', () {
    // A silent false would look identical to a launcher that declined.
    return plugin().then((kt) {
      expect(kt, contains('"UNKNOWN_WIDGET"'));
      expect(kt, contains('PIN_PROVIDERS.keys.joinToString'));
    });
  });

  test('an unsupported launcher answers false rather than erroring', () async {
    // Not every launcher implements pinning; that is a normal outcome the
    // caller handles by showing manual instructions.
    final kt = await plugin();
    expect(kt, contains('isRequestPinAppWidgetSupported'));
    expect(kt, contains('canRequestPinWidget'));
  });

  test('the API-26 floor is checked before the call', () async {
    final kt = await plugin();
    expect(kt, contains('Build.VERSION.SDK_INT < Build.VERSION_CODES.O'));
    expect(kt, contains('import android.appwidget.AppWidgetManager'));
    expect(kt, contains('import android.content.ComponentName'));
    expect(kt, contains('import android.os.Build'));
  });
}
