# mosaic_cli

**The build CLI for the Mosaic ecosystem — scaffold, generate, and diagnose.**

`mosaic_cli` is the command-line tool that drives the Mosaic code-generation pipeline.
It reads `mosaic.yaml`, executes your widget and Live Activity entry files, and emits
production-ready native Swift/Kotlin into your project's `ios/` and `android/` trees.

## Ecosystem

| Package | Role |
|---------|------|
| [mosaic](https://pub.dev/packages/mosaic) | Flutter DSL + `MosaicBridge` runtime |
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

| Command | Description |
|---------|-------------|
| `dart run mosaic_cli init` | Create a starter `mosaic.yaml` in the project root. |
| `dart run mosaic_cli add widget <Name>` | Scaffold a new widget entry file and register it in `mosaic.yaml`. |
| `dart run mosaic_cli build` | Run all widget/Live Activity entries and emit native iOS + Android code. |
| `dart run mosaic_cli doctor` | Diagnose the project configuration and surface common setup issues. |
| `dart run mosaic_cli clean` | Remove all Mosaic-generated artifacts from the native project trees. |

## Typical workflow

```bash
# 1. Initialise mosaic.yaml (or write one by hand).
dart run mosaic_cli init

# 2. Scaffold a widget entry.
dart run mosaic_cli add widget PriceWidget

# 3. Edit lib/widgets/price_widget.widget.dart
#    (pure-Dart DSL — import 'package:mosaic/dsl.dart').

# 4. Generate native code — re-run after every DSL change.
dart run mosaic_cli build

# 5. Diagnose setup issues.
dart run mosaic_cli doctor
```

`build` is the command you will run most often. Generated files are overwritten in place,
so it is safe to run repeatedly.

## More information

- [mosaic](https://pub.dev/packages/mosaic) — the Flutter DSL and `MosaicBridge`.
- [DSL Reference](https://github.com/your-org/mosaic/blob/main/DOCS/DSL_REFERENCE.md)
- [Android Setup](https://github.com/your-org/mosaic/blob/main/DOCS/ANDROID_SETUP.md)
- [iOS Setup](https://github.com/your-org/mosaic/blob/main/DOCS/IOS_SETUP.md)
