# mosaic_cli

**The build CLI for the Mosaic ecosystem — scaffold, generate, and diagnose.**

`mosaic_cli` is the command-line tool that drives the Mosaic code-generation pipeline.
It reads `mosaic.yaml`, executes your widget and Live Activity entry files, and emits
production-ready native Swift/Kotlin into your project's `ios/` and `android/` trees.

## Ecosystem

| Package | Role |
|---------|------|
| [mosaic_widgets](https://pub.dev/packages/mosaic_widgets) | Flutter DSL + `MosaicBridge` runtime |
| [mosaic_core](https://pub.dev/packages/mosaic_core) | IR, config, runner primitives |
| [mosaic_android](https://pub.dev/packages/mosaic_android) | Android RemoteViews/Kotlin generator |
| [mosaic_ios](https://pub.dev/packages/mosaic_ios) | iOS WidgetKit/Live Activity generator |
| **mosaic_cli** ← _you are here_ | `dart run mosaic_cli build` and friends |

## Install

Add as a dev dependency so it is available via `dart run`:

```yaml
dev_dependencies:
  mosaic_cli: ^1.0.0
```

## Commands

```bash
dart run mosaic_cli init                  # detect identifiers, write mosaic.yaml
dart run mosaic_cli add widget News       # scaffold + register a widget
dart run mosaic_cli build                 # generate native Swift/Kotlin
dart run mosaic_cli doctor --fix          # repair setup, report what needs Xcode
```

| Command | Description |
|---------|-------------|
| `init` | Writes a starter `mosaic.yaml`, reading `applicationId` from `build.gradle*` and the Runner target's `PRODUCT_BUNDLE_IDENTIFIER` so the derived App Group is correct immediately. |
| `add widget <Name>` | Creates the definition file and registers it in `mosaic.yaml`, placing it wherever your existing entries live. `--dir` overrides; `--no-register` only prints the YAML. |
| `add live-activity <Name>` | Scaffolds a Live Activity — lock-screen tree plus all four Dynamic Island slots — creating `live_activities:` if absent. |
| `add control <Name>` | Scaffolds a Control Center (iOS 18+) / Quick Settings tile toggle. |
| `build` | Runs your entry files and generates native code. Fails fast with actionable messages on missing drawables, undeclared `MLocalized` keys, deep-link schemes that resolve to nothing, and toggles missing `valueKey`. Deletes generated files orphaned by a removed widget. |
| `list` | Shows every declared widget, live activity and control with status (missing builder, native output not generated), plus refresh callbacks and locales. `--paths` prints the generated paths. |
| `doctor` | 15 project checks. Exits non-zero when any is fatal, so it works in CI. |
| `doctor --fix` | Repairs the unambiguous ones — `android:supportsRtl`, `android_package` vs `applicationId`, the required `group.` prefix, missing entitlements files, `NSSupportsLiveActivities` — and re-checks. Never edits `project.pbxproj`. |
| `clean` | Removes generated artifacts, identified by a `MOSAIC-GENERATED` sentinel, and leaves hand-written files alone. |
| `--version` | Prints the CLI version. |

## What `doctor` catches

These all fail **silently** otherwise — the app builds and the widget is simply blank or dead:

- App Group missing, misspelled, or lacking the `group.` prefix → app and widget read different `UserDefaults` suites.
- `MosaicPlugin` not registered in `AppDelegate` **or** `MainActivity` → every `MosaicBridge` call throws `MissingPluginException`.
- Generated Swift with no Xcode app-extension target → the app ships no `.appex` and no widget appears in the gallery.
- A widget renamed in `mosaic.yaml` without renaming `build<Name>()`.
- `android_package` disagreeing with the real `applicationId` → "Can't load widget" on every widget.


## Typical workflow

```bash
# 1. Initialise mosaic.yaml (or write one by hand).
dart run mosaic_cli init

# 2. Scaffold a widget entry.
dart run mosaic_cli add widget PriceWidget

# 3. Edit lib/widgets/price_widget.widget.dart
#    (pure-Dart DSL — import 'package:mosaic_widgets/dsl.dart').

# 4. Generate native code — re-run after every DSL change.
dart run mosaic_cli build

# 5. Diagnose setup issues.
dart run mosaic_cli doctor
```

`build` is the command you will run most often. Generated files are overwritten in place,
so it is safe to run repeatedly.

## More information

- [mosaic_widgets](https://pub.dev/packages/mosaic_widgets) — the Flutter DSL and `MosaicBridge`.
- [DSL Reference](https://github.com/your-org/mosaic/blob/main/docs/DSL_REFERENCE.md)
- [Android Setup](https://github.com/your-org/mosaic/blob/main/docs/ANDROID_SETUP.md)
- [iOS Setup](https://github.com/your-org/mosaic/blob/main/docs/IOS_SETUP.md)
