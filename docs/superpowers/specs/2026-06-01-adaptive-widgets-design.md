# Mosaic Sub-project A — Adaptive Widgets

**Date:** 2026-06-01
**Status:** Approved design
**Depends on:** the shipped Mosaic core (DSL → IR → native generators, runtime data binding).

## Summary

Add OS-adaptive capabilities to Mosaic widgets: dark/light + runtime-bind theming,
iOS lock-screen accessory widgets, and locale/RTL + locale-aware value formatting.
iOS-first; Android gets full theming/locale/RTL and a documented skip for
lock-screen accessory families (no general user lock-screen widgets on Android).

## Goals

1. **Theming** — `MColor` supports an OS dark variant AND a runtime `bind`; both resolve in generators.
2. **Lock-screen accessory widgets** — iOS `accessoryRectangular/Circular/Inline` families, gated iOS 16+, with `.widgetAccentable()`.
3. **Locale** — RTL auto-mirroring (leading/trailing, start/end; never left/right) and `MFormat` (decimal/currency/percent/date/relativeTime) on bound `MText`, formatted with the device locale at render.

## Non-Goals (A)
Full native string-table (.strings/strings.xml) generation, server-driven themes, Android lock-screen widgets, Live Activities (that is Sub-project B).

## Design

### Theming — `MColor`
- DSL: `MColor.hex(String hex, {String? dark, double opacity = 1.0})` and `MColor.bind(String key)`.
- `toJson`: `{hex, dark, opacity}` or `{bind: key, opacity}`. Backward compatible — existing `MColor.hex('#FFF')` produces the same JSON plus a null `dark`.
- **iOS:** generate a `Color(light:dark:)` helper in the shared core file that switches on `@Environment(\.colorScheme)`; bind colors resolve from `entry.data["key"]` (hex string → `Color(hex:)`), falling back to the light value/clear.
- **Android:** for adaptive colors emit a generated `res/values/mosaic_colors.xml` and `res/values-night/mosaic_colors.xml` pair and reference `@color/mosaic_<hash>`; for bind colors resolve at update via `MosaicData.resolveString` + `RemoteViews.setInt`/`setTextColor`/`setColorFilter`. Plain colors keep the current inline `#AARRGGBB` path.
- **Lock-screen rendering:** for iOS accessory families the OS renders content monochrome/tinted; emit `.widgetAccentable()` on accent-able content and document that custom colors are largely ignored there.

### Lock-screen accessory widgets (iOS 16+)
- `mosaic.yaml` `ios.families` accepts `accessoryRectangular`, `accessoryCircular`, `accessoryInline` in addition to the system* families. Generator maps each to the matching `WidgetFamily`, wraps accessory support in `if #available(iOS 16.0, *)`.
- Family-aware rendering: `accessoryRectangular` → the full small layout; `accessoryCircular` → a single gauge/progress or primary value; `accessoryInline` → leading image + single text. Provide sensible reduction of the DSL tree for the constrained families.
- **Android:** an accessory family in config is skipped for Android generation with a printed build-time notice; home-screen widgets are unaffected.

### Locale / RTL + formatting
- **RTL:** ensure generators never emit absolute left/right. iOS uses leading/trailing (SwiftUI auto-mirrors by locale). Android uses `start/end` gravity/padding (already largely) and the manifest needs `android:supportsRtl="true"` (documented; the CLI doctor can warn if false).
- **Formatting:** `enum MFormat { decimal, currency, percent, date, relativeTime }`; `MText(value, {MFormat? format})`. When `format` is set and the value is bound, generators format at render with the device locale:
  - iOS: `Double(...).formatted(.number/.currency/.percent)`, `Date(...).formatted(...)`, `Text(date, style: .relative)`.
  - Android: `NumberFormat.getInstance()/getCurrencyInstance()/getPercentInstance()`, `DateUtils.getRelativeTimeSpanString`, `DateFormat.getDateInstance()` — applied in `MosaicData`/provider at update.
  - Literal (non-bound) values may be pre-formatted at gen time when locale-independent; locale-dependent formats require a bind.

### DSL additions
`MColor.dark` + `MColor.bind`; `MFormat` enum + `MText.format`; accessory family parsing in config. The internal IR `__type` wire tags remain the stable `HW…` strings.

## Error handling
- Unknown `ios.families` value → clear gen-time error listing valid families.
- Accessory family on Android → documented skip with a notice (not an error).
- Bind color/format with a missing key → safe fallback (light color / "--") and log.

## Testing
Golden tests per feature:
- iOS adaptive color emits a colorScheme switch; Android emits `values/` + `values-night/` color entries.
- Bind color resolves at runtime on both platforms.
- Each accessory family maps to the right `WidgetFamily` under an availability gate.
- RTL: generators emit leading/trailing & start/end, never left/right (assert no `"left"`/`"right"` literals in layout gravity).
- Each `MFormat` emits the right formatter call.
Native gate (unchanged): `flutter build apk` (AAPT-valid) + `swiftc -typecheck` against the iOS SDK, now also exercising iOS-16 accessory code paths.

## Rollout
1. DSL: `MColor` dark/bind + `MFormat`/`MText.format` (pure Dart, no flutter dep — stays in dsl.dart).
2. iOS generator: adaptive/bind color, accessory families, formatting, RTL audit + tests.
3. Android generator: night-resource colors, bind color, formatting, RTL audit + tests.
4. CLI/config: accessory family parsing + doctor RTL/supportsRtl check.
5. Regenerate demo (add a lock-screen accessory widget + an adaptive-color + a formatted value as living examples); native build + typecheck.
6. Docs update.

## Risks
- RemoteViews color theming via night resources requires generating real color resource files and dedup; ensure AAPT-valid and cleaned by `clean` (extend the `hw_`/drawable clean to `values*/mosaic_colors.xml`).
- Accessory widget DSL reduction is opinionated; document the mapping so it's predictable.
