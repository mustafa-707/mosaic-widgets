# mosaic_core

**Intermediate Representation, config parsing, and runner primitives for the Mosaic ecosystem.**

`mosaic_core` is the shared foundation that all other Mosaic packages build on. It defines
the IR (Intermediate Representation) tree that the Dart DSL compiles into, the `mosaic.yaml`
config model, and the widget-runner interface used by the code generators.

Most projects **do not add this package directly** — it arrives as a transitive dependency
of [`mosaic`](https://pub.dev/packages/mosaic) and [`mosaic_cli`](https://pub.dev/packages/mosaic_cli).

## Ecosystem

| Package | Role |
|---------|------|
| [mosaic](https://pub.dev/packages/mosaic) | Flutter DSL + `MosaicBridge` runtime |
| **mosaic_core** ← _you are here_ | IR, config, runner primitives |
| [mosaic_android](https://pub.dev/packages/mosaic_android) | Android RemoteViews/Kotlin generator |
| [mosaic_ios](https://pub.dev/packages/mosaic_ios) | iOS WidgetKit/Live Activity generator |
| [mosaic_cli](https://pub.dev/packages/mosaic_cli) | `dart run mosaic_cli build` and friends |

## Install

Only add this explicitly if you are building a custom code generator or tool on top of
the Mosaic IR.

```yaml
dependencies:
  mosaic_core: ^1.0.0
```

## What's inside

- **IR node tree** — the platform-neutral representation that `MosaicDefinition` (and
  `MosaicLiveActivity`) serialise into. Both `mosaic_android` and `mosaic_ios` consume
  this tree to emit native code.
- **`mosaic.yaml` config model** — typed Dart classes for the app config, widget
  registrations, and Live Activity registrations defined in a project's `mosaic.yaml`.
- **Widget runner** — the mechanism used by `mosaic_cli` to `dart run` a widget entry
  file and capture its `MosaicDefinition` (or `MosaicLiveActivity`) without a Flutter
  runtime.

## Typical usage (tool authors)

```dart
import 'package:mosaic_core/mosaic_core.dart';

// Load and parse mosaic.yaml from a project root.
final config = MosaicConfig.fromYaml(yamlString);

// Run a widget entry and get back the IR tree.
final definition = await WidgetRunner.run(config.widgets.first);

// Hand the IR to a generator.
final output = MyCustomGenerator().generate(definition);
```

For most app developers, see [`mosaic`](https://pub.dev/packages/mosaic) instead.
