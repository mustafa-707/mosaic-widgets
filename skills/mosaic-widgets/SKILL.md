---
name: mosaic-widgets
description: Use when building or editing native iOS/Android home-screen widgets, lock-screen (accessory) widgets, Live Activities, or Dynamic Island with the Mosaic Flutter framework — e.g. a project containing a mosaic.yaml, files importing package:mosaic, or *.widget.dart / *.live.dart definition files.
---

# Mosaic Widgets

## Overview
Mosaic generates **native** iOS (WidgetKit / Live Activities / Dynamic Island) and Android
(AppWidget / RemoteViews) code from a single Dart DSL. You write declarative `MosaicDefinition`
(widget) and `MosaicLiveActivity` (Live Activity) builder functions; the `mosaic_cli build`
command runs them and emits native Swift/Kotlin/XML. The app pushes live data through
`MosaicBridge`; the OS renders the widget. Mosaic is NOT in model training data — use the real
API below, do not invent classes or imports.

## The one rule that trips everyone up
- **Widget/Live-Activity definition files import `package:mosaic/dsl.dart`** (pure Dart — the build
  runner executes them under `dart run`, which cannot compile Flutter).
- **App code** (using `MosaicBridge` / `MosaicLiveActivities`) imports `package:mosaic/mosaic.dart`.
Putting `package:mosaic/mosaic.dart` in a definition file breaks `mosaic_cli build`.

## Workflow
1. `dart run mosaic_cli init` → creates `mosaic.yaml` + `lib/home_widgets/`.
2. `dart run mosaic_cli add widget MyWidget` → scaffolds `lib/home_widgets/mywidget.widget.dart`.
3. Define the widget: a top-level `MosaicDefinition build<Name>()` (convention: `build` + the
   config `name`). Live activities: a `MosaicLiveActivity build<Name>()` in a `*.live.dart` file.
4. Register it in `mosaic.yaml` (see Config). The `entry:` path is arbitrary — relative to the
   project root; any directory works (the scaffold default is `lib/home_widgets/`, but e.g.
   `lib/platform/widgets/` is fine). The config `name:` must match the `build<Name>()` suffix
   **exactly, case-sensitive** (`name: NewsWidget` ⇒ `MosaicDefinition buildNewsWidget()`).
5. `dart run mosaic_cli build` → generates native code (idempotent; `clean` removes it).
6. iOS: add the generated files to your Widget Extension target in Xcode (one-time). Wire
   `AppDelegate.swift` / `MainActivity.kt` from the generated templates (see DOCS/IOS_SETUP.md,
   DOCS/ANDROID_SETUP.md). `doctor` checks setup.

## Minimal widget
```dart
import 'package:mosaic/dsl.dart';

MosaicDefinition buildNews() => MosaicDefinition(
  name: 'News',                 // must match the mosaic.yaml entry name
  width: 4, height: 1,
  root: MContainer(
    background: const MColor.hex('#111827', dark: '#000000'),
    radius: 16,
    child: MPadding(const MInsets.all(12), MColumn(
      crossAxisAlignment: MCrossAxisAlignment.start,
      [
        const MText('Headlines', style: MTextStyle(color: MColor.hex('#FFFFFF'), bold: true)),
        MText(MBind('headline'), maxLines: 2),   // live value pushed by the app
      ],
    )),
  ),
);
```

## Quick reference

**Definition:** `MosaicDefinition({required name, required root, Duration? updateInterval, int width=2, int height=2, String? previewImage, MResizeMode resizeMode, List<MParam> params})`.

**Layout nodes:** `MContainer({required child, MColor? background, MLinearGradient? gradient, double radius, MBorder? border, double? width, double? height, MInsets? margin, MShadow? shadow, MRadius? corners})`, `MColumn(children, {mainAxisAlignment, crossAxisAlignment})`, `MRow(...)`, `MPadding(insets, child)`, `MStack(children)`, `MPositioned({required child, top,left,right,bottom})`, `MCenter({required child})`, `MSpacer()`, `MDivider({thickness, color, vertical, indent})`.

**Content nodes:** `MText(textOrBind, {MTextStyle style, MFormat? format, int? maxLines, MTextAlign? align})`, `MImage(source, {MBoxFit fit})`, `MIcon({sfSymbol, androidDrawable, size, MColor? color})`, `MProgressBar({required value, double max, MColor color})`, `MGauge({required value, max, trackColor, fillColor, lineWidth})`, `MBadge({required child, required count, MColor? color})`, `MTimer({required target, bool countUp, MTextStyle style})`, `MButton({required child, required MAction action})`, `MVisibility({required bind, required child, MNode? replacement})`, `MListView({required bind, required itemTemplate})`.

**Bindings:** `MBind('key')` anywhere a value is accepted (text, image path, progress value, visibility, timer target, gauge value, color). The app supplies values via `MosaicBridge`. `MText` `format:` (`MFormat.currency/decimal/percent/date/relativeTime`) formats a bound value in the device locale; `date`/`relativeTime` expect **epoch milliseconds**.

**Colors/theme:** `MColor.hex('#RRGGBB', {String? dark, double opacity})` (OS light/dark) or `MColor.bind('key')` (runtime). **Style:** `MTextStyle({double? size, MColor? color, double? opacity, bool? bold})`. **Insets:** `MInsets.all(v)` / `.symmetric(vertical:, horizontal:)` / `.only(...)`. **Gradient:** `MLinearGradient({required List<MColor> colors, List<double>? stops, double angle})`. **Shape:** `MBorder({required color, width})`, `MRadius({topLeft,topRight,bottomLeft,bottomRight})`/`MRadius.all(v)`, `MShadow({color, blur, dx, dy})`. Enums: `MBoxFit`, `MMainAxisAlignment`, `MCrossAxisAlignment`, `MTextAlign`, `MResizeMode`.

**Actions (for MButton):** `MLaunchUrlAction('myapp://path')`, `MActionCallback('name')` (→ Dart `registerBackgroundCallback`), `MRefreshAction()`. iOS buttons are real (AppIntent) on iOS 17+, deep-link on 14–16.

**Image sources:** `MAssetImage('icon.png')`, `MFileImage(pathOrBind)`.

**Named-arg examples:** `MIcon(sfSymbol: 'cloud.sun.fill', androidDrawable: 'ic_weather', size: 32, color: MColor.hex('#FFD700'))`; `MProgressBar(value: MBind('p'), max: 100, color: MColor.hex('#34D399'))`; `MGauge(value: MBind('pct'), fillColor: MColor.hex('#FF0000'))`.

**`const` tip:** nodes with only literal args can be `const` (e.g. `const MText('Hi')`), but anything containing `MBind(...)` cannot be `const` (it's a runtime binding) — drop `const` on the enclosing node then.

## Data binding (app side)
```dart
import 'package:mosaic/mosaic.dart';
await MosaicBridge.setAppGroupId('group.com.example.app.widgets'); // iOS
await MosaicBridge.saveString('headline', 'Markets rally');
await MosaicBridge.saveJson('item', {...});  // also saveList / saveBool
await MosaicBridge.refresh('News');          // or refreshAll()
MosaicBridge.onDeepLink.listen((url) { ... });
MosaicBridge.registerBackgroundCallback((name) async { ... });
```

## Live Activities + Dynamic Island (iOS 16.1+)
```dart
// in a *.live.dart file, imports package:mosaic/dsl.dart
MosaicLiveActivity buildOrder() => MosaicLiveActivity(
  name: 'Order',
  lockScreen: MText(MBind('status')),
  dynamicIsland: MDynamicIsland(
    compactLeading: const MText('🛵'),
    compactTrailing: MText(MBind('eta')),
    minimal: const MText('🛵'),
    expanded: MExpanded(center: MText(MBind('status')), bottom: MProgressBar(value: MBind('progress'))),
  ),
);
```
Register under `live_activities:` in `mosaic.yaml`. Control from the app (import `package:mosaic/mosaic.dart`):
```dart
final id = await MosaicLiveActivities.start('Order', {'status':'On the way','eta':'12m','progress':'40'}, push: false);
await MosaicLiveActivities.update(id!, {'progress':'80'}, alert: const MActivityAlert(title:'Almost there', body:'2 min'));
await MosaicLiveActivities.end(id, policy: MEndPolicy.afterDefault);
MosaicLiveActivities.onPushToken.listen((t) { /* send t.token to your server for APNs push */ });
```
iOS needs `NSSupportsLiveActivities=true` in Info.plist. Binds in a Live Activity resolve from its
content-state (the Map passed to start/update), not the widget data store. Android renders a
best-effort ongoing notification (no Dynamic Island; updates are local, no push token).

## Configurable widgets
Declare `params` on a `MosaicDefinition`; the chosen value is available via `MBind(param.key)`:
```dart
params: const [ MParam(key:'city', label:'City', type: MParamType.choice, defaultValue:'London', choices:['London','Paris']) ],
```
`MParamType { text, number, toggle, choice }`. iOS → AppIntentConfiguration (iOS 17+); Android → a config Activity.

## Config (mosaic.yaml)
```yaml
app:
  bundle_id: com.example.app
  android_package: com.example.app
  ios_app_group: group.com.example.app.widgets
  deep_link_scheme: mosaic        # optional (default 'mosaic')
widgets:
  - name: News
    entry: lib/home_widgets/news.widget.dart
    android: { min_sdk: 21, sizes: [medium] }
    ios: { families: [systemMedium, accessoryRectangular] }   # accessory* = lock screen, iOS 16+
live_activities:
  - name: Order
    entry: lib/live_activities/order.live.dart
```

## CLI
`dart run mosaic_cli init | add widget <Name> | build | doctor | clean`.

## Common mistakes
| Mistake | Fix |
|---|---|
| Definition file imports `package:mosaic/mosaic.dart` | Use `package:mosaic/dsl.dart` in definition files |
| Function named wrong | It must be `build<Name>()` where `<Name>` matches the `mosaic.yaml` entry |
| Forgot to register in `mosaic.yaml` | Add it under `widgets:` / `live_activities:` |
| Bound date shows wrong | `MFormat.date`/`relativeTime` expect epoch **milliseconds** |
| iOS Live Activity never starts | Add `NSSupportsLiveActivities=true`; wire AppDelegate from the generated template |
| Expecting Dynamic Island on Android | Not supported — Android live activity is an ongoing notification |
| `MGauge` arc on Android | Android approximates it as a linear ProgressBar (RemoteViews has no arc) |
| Container shadow on Android | Ignored (RemoteViews has no drop shadow) |

## Control Widgets (iOS 18 Control Center / Android Quick Settings)

Control widgets are separate from home-screen widgets. They live in `*.control.dart` files (import `package:mosaic/dsl.dart`, no Flutter), export `MControl build<Name>()`, and are registered under `controls:` in `mosaic.yaml`.

```dart
import 'package:mosaic/dsl.dart';

MControl buildTorch() => const MControl(
  name: 'Torch',
  kind: MControlKind.toggle,   // or MControlKind.button
  label: 'Flashlight',
  sfSymbol: 'flashlight.on.fill',   // iOS SF Symbol
  androidIcon: 'ic_torch',          // Android drawable (optional)
  valueKey: 'torch_on',             // toggles only — shared-store bool key
  action: MActionCallback('toggle_torch'),
);
```

`mosaic.yaml` registration (parallel to `widgets:` and `live_activities:`):
```yaml
controls:
  - name: Torch
    entry: lib/platform/controls/torch.control.dart
```

**`MControl` constructor** — all named args: `name` (String, required), `kind` (MControlKind, required), `label` (String, required), `sfSymbol` (String?), `androidIcon` (String?), `valueKey` (String?, toggles), `action` (MAction, required). `MActionCallback`, `MLaunchUrlAction`, and `MRefreshAction` are all valid actions.

**iOS behaviour (iOS 18+):** `mosaic_cli build` emits a `<Name>Control.swift` (`ControlWidgetToggle` / `ControlWidgetButton`) into `ios/HomeWidgetExtension/`, gated `@available(iOS 18.0, *)`. The toggle reads its current state from the App Group `UserDefaults` bool at `valueKey`; tapping writes the new value back and fires the action. A shared `MosaicControlIntents.swift` (also emitted) provides the `SetValueIntent`. Controls are registered in `HomeWidgetBundle.swift` under an iOS 18 gate. Controls are part of the same Widget Extension used for home-screen widgets — no additional Xcode target is required.

**Android behaviour (API 24+, user-added):** A `<Name>TileService.kt` (`TileService` subclass) is emitted under `mosaic_generated`. For toggles `onStartListening` reads `widget_data` SharedPreferences under `valueKey` and sets `STATE_ACTIVE`/`STATE_INACTIVE`; `onClick` flips the bool and broadcasts a `MOSAIC_CALLBACK` intent (same path as widget buttons). For buttons `onClick` fires the callback directly. The `<service>` tag (with `BIND_QUICK_SETTINGS_TILE` permission and the QS tile intent-filter) is **auto-added to `AndroidManifest.xml`** by `mosaic_cli build`. QS tiles are user-added from the Quick Settings edit panel.

## Platform notes
- Widget definitions, live activities, and control widgets are **pure data** — no Flutter widgets, no `setState`, no runtime logic; all dynamism comes from `MBind` + the data the app pushes.
- iOS deployment: configurable widgets and AppIntent buttons need iOS 17+; Live Activities/Dynamic Island/accessory widgets need iOS 16+/16.1+; Control widgets need iOS 18+. Non-configurable home widgets work on iOS 14+.
- Android live activities use **Android 16 Live Updates** (`Notification.ProgressStyle` + promoted-ongoing) on API 36+; the custom-RemoteViews ongoing notification is the pre-36 fallback.
- iOS ActivityKit code uses the non-deprecated iOS 16.2+ `ActivityContent` APIs with a 16.1 fallback.
- Deeper docs in the repo: `DOCS/DSL_REFERENCE.md`, `DOCS/IOS_SETUP.md`, `DOCS/ANDROID_SETUP.md`, `DOCS/LIVE_ACTIVITIES.md`, `docs/ROADMAP.md`.
