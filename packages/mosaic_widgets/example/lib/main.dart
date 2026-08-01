// Example for package:mosaic
//
// Widget definition files import package:mosaic_widgets/dsl.dart (pure-Dart DSL) so
// the build runner can execute them with `dart run` — no Flutter runtime needed
// at build time.
//
// App/bridge code imports package:mosaic_widgets/mosaic_widgets.dart (DSL + MosaicBridge).

// Widget definitions use package:mosaic_widgets/dsl.dart (pure-Dart, build-time safe).
// App/bridge code uses package:mosaic_widgets/mosaic_widgets.dart (re-exports dsl.dart + MosaicBridge).
// In a single file that uses both, import only the full barrel.
import 'package:mosaic_widgets/mosaic_widgets.dart';

// ---------------------------------------------------------------------------
// Widget definition
// ---------------------------------------------------------------------------

/// Minimal home-screen widget: a container with a static label and a
/// runtime-bound subtitle driven by [MosaicBridge.saveString].
MosaicDefinition buildExampleWidget() {
  return MosaicDefinition(
    name: 'ExampleWidget',
    width: 2,
    height: 2,
    root: MContainer(
      // Adaptive background: dark blue in light mode, near-black in dark mode.
      background: const MColor.hex('#1E3A8A', dark: '#0F172A'),
      radius: 16,
      child: MPadding(
        const MInsets.all(12),
        MColumn([
          const MText(
            'Hello Mosaic',
            style: MTextStyle(
              color: MColor.hex('#FFFFFF'),
              size: 14,
              bold: true,
            ),
          ),
          // MBind('subtitle') resolves at render time against the value
          // pushed from the app via MosaicBridge.saveString('subtitle', ...).
          MText(
            MBind('subtitle'),
            style: const MTextStyle(
              color: MColor.hex('#93C5FD'),
              size: 11,
            ),
          ),
          // Runtime-bound numeric value formatted with the device locale.
          MText(
            MBind('price'),
            format: MFormat.currency,
            style: const MTextStyle(
              color: MColor.hex('#FFFFFF'),
              size: 18,
              bold: true,
            ),
          ),
        ]),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// App entry point
// ---------------------------------------------------------------------------

/// Demonstrates [MosaicBridge] — the runtime API that pushes data into widget
/// bindings and triggers home-screen refreshes.
///
/// In a real Flutter app this runs inside [WidgetsFlutterBinding.ensureInitialized]
/// before [runApp]. Here it is kept as a standalone async main so the file
/// passes `flutter analyze` without requiring a full widget tree.
Future<void> main() async {
  // Tell the bridge which App Group (iOS) / shared preferences key (Android)
  // to use for the widget data store.
  await MosaicBridge.setAppGroupId('group.com.example.myapp.widgets');

  // Push bound values by key — the same keys used in MBind('...') above.
  await MosaicBridge.saveString('subtitle', 'Live from Flutter!');
  await MosaicBridge.saveString('price', '67420.00');

  // Ask the OS to re-render all registered widgets with the new data.
  await MosaicBridge.refreshAll();
}
