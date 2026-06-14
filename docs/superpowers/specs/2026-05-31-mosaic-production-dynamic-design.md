# Mosaic — Production-Ready + Runtime-Dynamic Home Widgets

**Date:** 2026-05-31
**Status:** Approved design, pre-implementation
**Former name:** Antigravity Home Widgets (`hw_flutter`)

## Summary

Mosaic is a DSL-based framework for building native iOS (WidgetKit/SwiftUI) and
Android (AppWidget/RemoteViews) home-screen widgets from a single Dart
definition. This round of work makes it actually work end-to-end on real
consumer apps (today many paths only work in the bundled demo), and makes
widget content **runtime-dynamic**: the app pushes data into shared storage and
widgets re-render live with no app rebuild and no code regeneration.

Publishing to pub.dev (LICENSE/CHANGELOG/semver/pana) is explicitly deferred.

## Goals

1. Rename project to **Mosaic** across all packages, classes, imports, docs.
2. Fix all 15 audit findings (correctness, codegen safety, config-driven values, robustness).
3. Make all widget content runtime-data-bound (text, image, timer, progress, visibility, list, optional color).
4. Add a runnable Dart test suite (golden tests over generated output + unit tests).
5. Regenerate the demo app on the new name as the end-to-end smoke check.

## Non-Goals (this round)

- pub.dev publishing mechanics (LICENSE, CHANGELOG, semver discipline, pana score, dartdoc polish).
- Server-driven layout/data (remote fetch).
- Full IR-interpreter on native (dynamic *layout* without rebuild). Layout stays codegen'd; only *content* is dynamic.

## Architecture

Unchanged spine: **DSL (Dart) → IR (JSON) → native codegen (Kotlin/Swift)**.

The shift: generated native code becomes a thin **runtime renderer** that reads a
shared data store on every widget refresh and resolves bindings, instead of
baking values at generation time.

```
Dart .widget.dart  →  MosaicDefinition.toJson()  →  IR JSON
        │                                              │
   mosaic (DSL)                                  mosaic_core (IR models)
        │                                              │
        └──────────────► mosaic_cli build ◄────────────┘
                              │
              ┌───────────────┴───────────────┐
        mosaic_android                    mosaic_ios
        (Kotlin/XML gen)                  (Swift gen)
              │                                │
   reads SharedPreferences           reads App Group UserDefaults
   "widget_data" each update         each timeline render
```

At runtime: `MosaicBridge.saveString/saveJson/saveList/saveBool` writes to the
shared store; native renderer resolves `MBind('key')` references when the widget
refreshes.

### Package rename map

| Old | New | Contents |
|-----|-----|----------|
| `hw_core` | `mosaic_core` | IR models, config, widget_runner |
| `hw_flutter` | `mosaic` | DSL + `MosaicBridge` |
| `hw_android` | `mosaic_android` | Android generator |
| `hw_ios` | `mosaic_ios` | iOS generator |
| `hw_cli` | `mosaic_cli` | CLI (init/add/build/doctor/clean) |

Class/symbol renames: `HW*` → `M*` for DSL nodes (`MText`, `MContainer`, `MBind`,
`MColumn`, …), `HWDefinition` → `MosaicDefinition`, `HomeWidgetBridge` →
`MosaicBridge`, generated `*Provider`/`*Widget` names unchanged in pattern.
Config file `home_widget.yaml` → `mosaic.yaml` (CLI checks both for back-compat,
prefers `mosaic.yaml`). Method channel `hw_flutter_bridge` → `mosaic_bridge`.
Android generated package segment `hw_generated` → `mosaic_generated`.
Deep-link/callback action suffix `.MOSAIC_CALLBACK`.

## Runtime-Dynamic Model

Every content field accepts either a literal OR an `MBind`, resolved natively per
refresh via a generated typed accessor.

| Field | Today | After |
|-------|-------|-------|
| Text | bind ✓ | keep; coerce non-string values to display string correctly |
| Timer target | baked epoch literal | `MBind` → read epoch (ms) from store |
| Progress value / max | partial / static ignored | both literal-or-bind; static value rendered |
| Visibility | broken (`as? Bool` always false) | fixed + bind-able |
| Image (file) | path literal/bind | `MBind` path resolved from store, sandbox-safe |
| Color / gradient | static only | literal default, optional bind (hex string) |
| ListView items | non-functional stub | JSON array from store → repeat item template per element |

**Generated data accessor (per platform):**
- Android: helper reading `SharedPreferences("widget_data")` (or App Group when configured), typed getters `resolveString/Double/Bool/List(key)`.
- iOS: helper reading App Group `UserDefaults(suiteName:)`, same typed surface, correct `NSNumber` handling for bool/number.

**ListView contract:** store value at `bind.key` is a JSON array of objects;
the item template references per-item fields via `MBind('field')` resolved
against the current array element rather than the global store.

## Fix Batches (all 15 findings)

- **A — wiring/correctness (HIGH):**
  - Callback intent action uses `${config.app.androidPackage}.MOSAIC_CALLBACK`, not hardcoded `com.example.*`.
  - iOS `refresh(name)` implemented natively (`WidgetCenter.reloadTimelines(ofKind:)`).
  - iOS deep-link delivery: AppDelegate forwards opened URLs to the `onDeepLink` channel.
  - Android `backgroundCallback` channel method wired in MainActivity → reaches Dart `registerBackgroundCallback`.
  - iOS visibility bool read via `NSNumber.boolValue`.
- **B — codegen safety (HIGH):**
  - Escape helpers for XML, Kotlin string literals, Swift string literals; applied to all user-supplied values (text, url, callback name, asset path).
  - `def.name` sanitized to a valid identifier before use as class/resource name.
  - Output overwrite/collision guard: detect duplicate lowercased names; fail with a clear error.
  - `parseColor` null-safe on missing `hex`; alpha applied for non-`#` cases.
- **C — config-driven (MED):**
  - Deep-link scheme read from `mosaic.yaml`, not hardcoded `hwdemo`.
  - Android `updatePeriodMillis` derived from `updateInterval` (clamped to Android's 1800000 ms min; 0 to disable and rely on AlarmManager).
  - PendingIntent request code unique per widget instance (`appWidgetId * 100 + index`).
- **D — robustness (MED):**
  - `widget_runner` wraps JSON output in sentinel markers (`<<<MOSAIC_IR>>> … <<<END>>>`) and parses between them, not "last stdout line".
  - iOS `firstWhere` uses `orElse`/early validation with a descriptive error.
  - Null-safe IR field access in all handlers (`children`, `child`, `bind`).
- **E — CLI (MED):**
  - `add widget` scaffold imports `package:mosaic_widgets/mosaic_widgets.dart`.
  - `clean` implemented for iOS (remove generated `mosaic_generated`/widget Swift files).
- **F — missing handlers (MED):**
  - `MBorder` (real border via shape drawable / SwiftUI `.border`/overlay).
  - `MLinearGradient` (real gradient drawable XML / SwiftUI `LinearGradient`), not flat `colors[0]`.
  - `MAssetImage` / `MFileImage` as standalone nodes, plus inside `MImage`.

## Testing Strategy (runnable in this environment)

Native Kotlin/Swift cannot be compiled here, so correctness is anchored by Dart
tests over generator output, plus a manual native build by the user.

1. **Golden tests** (`mosaic_android`, `mosaic_ios`): fixture IR → assert generated
   Kotlin/Swift/XML strings. Cover escaping, name sanitization, every node handler,
   gradient/border, list, timer/progress/visibility binds.
2. **Unit tests** (`mosaic_core`): config YAML parse, `widget_runner` sentinel
   extraction, IR round-trip; DSL `toJson` shape; escape helper edge cases (quotes,
   backslash, `<`/`&`, `$`, newlines).
3. **Demo app** regenerated under Mosaic as the end-to-end smoke; user performs the
   native Xcode/Android Studio build to validate the generated code compiles.
4. **TDD per fix:** each finding gets a failing test first, then the fix.

## Error Handling

- Gen-time validation fails fast with actionable messages (bad name, duplicate
  name, missing required IR child, unparseable timer target, missing config widget entry).
- Unsupported node types throw at gen-time (no silent `<!-- Unsupported -->` /
  invisible-stub degradation); gradient/list/border are now supported so the
  silent-stub paths are removed.
- Native runtime resolves missing bind keys to safe fallbacks (`"--"` text,
  hidden visibility, blank image) and logs.

## Rollout / Sequence

1. Rename (mechanical, must keep demo compiling) → green build/tests baseline.
2. Test scaffolding + golden harness.
3. Fix batches A→F, each TDD.
4. Runtime-dynamic features (extend DSL binds + native accessors).
5. Regenerate demo, update DOCS (ANDROID_SETUP, IOS_SETUP, DSL_REFERENCE, README).
6. Manual native build verification by user.

## Open Risks

- RemoteViews list support requires `RemoteViewsService`/`RemoteViewsFactory` — heavier than other handlers; if it can't be done safely it falls back to a gen-time error rather than a silent stub.
- App Group vs MODE_PRIVATE: Android uses app-private `widget_data` (shared across same-app processes); iOS requires App Group. Bridge `appGroupId` only meaningful on iOS — documented.
- Cannot verify native compilation in this environment; relies on golden tests + user's local native build.
