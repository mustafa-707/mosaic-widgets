# AGENTS.md — Working in the Mosaic repo

Guidance for AI agents (and humans) contributing to or extending Mosaic itself. If you are
*using* Mosaic to build widgets in an app, read `skills/mosaic-widgets/SKILL.md` instead.

## What this repo is
A Dart/Flutter monorepo. Mosaic compiles a Dart DSL → native iOS/Android home-widget code.
Pipeline: **DSL (`mosaic`) → IR JSON (`mosaic_core`) → native generators (`mosaic_android`,
`mosaic_ios`) → `mosaic_cli build`**. Runtime data flows app → `MosaicBridge` → native renderer.

## Layout
```
platform/core      mosaic_core    IR models, config (mosaic.yaml), widget_runner, escape helpers
platform/flutter   mosaic         DSL (lib/dsl.dart, pure Dart) + bridge (lib/bridge.dart, Flutter)
platform/android   mosaic_android lib/mosaic_android.dart — RemoteViews/Kotlin/XML generator
platform/ios       mosaic_ios     lib/mosaic_ios.dart — WidgetKit/ActivityKit/SwiftUI generator
platform/cli       mosaic_cli     bin/ + lib/src/commands (init/add/build/doctor/clean)
examples/demo_app  the reference app; its generated native files exercise the generators
DOCS/, docs/       user + design docs, ROADMAP, PUBLISHING; specs under docs/superpowers/
skills/            the mosaic-widgets user skill
```

## Hard rules (do not regress)
- `platform/flutter/lib/dsl.dart` must stay **Flutter-free** (no `package:flutter` import). The
  build runner executes widget-definition files under `dart run`; importing Flutter breaks it.
  The bridge (`bridge.dart`) is the only place Flutter is allowed.
- The IR wire `__type` tags are the legacy `HW…` strings (`HWText`, `HWContainer`, …) and are an
  internal stable protocol — do NOT rename them; DSL `toJson`, generator handler `type` getters,
  and all test fixtures must agree.
- Generated Android resource XML must have `<?xml ?>` as the **first** line (AAPT rejects a leading
  comment). Generated files carry a `MOSAIC-GENERATED` sentinel (XML: line 2; Kotlin/Swift: line 1).
- iOS APIs must be availability-gated: home widgets iOS 14+, accessory/Live Activity 16/16.1+,
  AppIntent buttons + configurable widgets 17+. Generated Swift must type-check at BOTH 16.1 and 17.

## Build & test
```bash
# per-package unit/golden tests (pure Dart packages)
for d in core android ios cli; do (cd platform/$d && dart test); done
(cd platform/flutter && flutter test)            # DSL/bridge tests
(cd platform/core && dart run build_runner build --delete-conflicting-outputs)  # after editing @JsonSerializable models
```

## The native verification gate (run before claiming generator work done)
Generated native code is verified by compiling it — never assume:
```bash
cd examples/demo_app
dart run mosaic_cli clean && dart run mosaic_cli build      # regenerate
flutter build apk --debug                                   # Android: compiles generated Kotlin + AAPT
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)          # iOS: type-check generated Swift, BOTH targets
xcrun swiftc -typecheck -sdk "$SDK" -target arm64-apple-ios17.0-simulator ios/HomeWidgetExtension/*.swift
xcrun swiftc -typecheck -sdk "$SDK" -target arm64-apple-ios16.1-simulator ios/HomeWidgetExtension/*.swift
```
On-device rendering (widget actually drawing, Dynamic Island, configurable UI) requires adding the
generated files to the Xcode Widget Extension target and running on a device — that is a manual gate.

## How to add a DSL feature (the standard flow)
1. **DSL** (`dsl.dart`): add the class/prop + `toJson` (keep pure Dart); add a `flutter test`.
   Pick the wire shape carefully — both generators consume it.
2. **Generators**: implement the handler/prop in `mosaic_android.dart` AND `mosaic_ios.dart`, each
   with golden tests asserting the emitted XML/Swift. Where a platform genuinely can't do it,
   degrade with a visible comment or throw a clear gen-time error — never silently drop a field.
3. **Verify** via the native gate above. Update `DOCS/DSL_REFERENCE.md` and the skill.

## Conventions
- TDD: failing test first, then implement. Commit per logical unit; conventional-commit messages.
- Path deps stay `path:` in the repo (the publish-time version swap is documented in docs/PUBLISHING.md — do not commit it).
- Don't add hardcoded `com.example`/scheme/package assumptions — derive from `mosaic.yaml`.
