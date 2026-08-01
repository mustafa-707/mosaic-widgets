<p align="center">
  <img src="assets/mosaic_logo.png" alt="Mosaic — Flutter Widget Builder" width="320">
</p>

<p align="center">
  <a href="https://github.com/TheBSD/StandWithPalestine/blob/main/docs/README.md"><img src="https://raw.githubusercontent.com/TheBSD/StandWithPalestine/main/badges/StandWithPalestine.svg" alt="StandWithPalestine"></a>
  <a href="https://pub.dev/packages/mosaic_widgets"><img src="https://img.shields.io/pub/v/mosaic_widgets.svg" alt="Pub Package"></a>
</p>

<p align="center"><b>One DSL → native home-screen widgets on iOS and Android.</b></p>

Write a widget once in Flutter-style Dart. Mosaic generates real native **SwiftUI/WidgetKit** (iOS) and **RemoteViews/Kotlin** (Android) — including **Live Activities, Dynamic Island, and Lock Screen** widgets. Your app pushes live data; the OS draws the tile. No per-platform widget code.

```dart
import 'package:mosaic_widgets/dsl.dart';

MosaicDefinition buildNews() => MosaicDefinition(
  name: 'News',
  root: MContainer(
    background: const MColor.hex('#111827', dark: '#000000'),
    radius: 16,
    child: MPadding(const MInsets.all(12),
      MText(MBind('title'), style: const MTextStyle(color: MColor.hex('#FFFFFF'), bold: true))),
  ),
);
```

## Features

- ✅ One Dart DSL → native iOS + Android widgets (no Swift/Kotlin to hand-write)
- ✅ Live data binding (`MBind`) — text, images, progress, visibility, timers, colors
- ✅ **Live Activities + Dynamic Island** (iOS); **Android 16 Live Updates** (`Notification.ProgressStyle`, API 36+) with ongoing-notification fallback
- ✅ **Lock Screen** accessory widgets (iOS 16+)
- ✅ **Control Widgets** — iOS 18 Control Center / Lock Screen controls + Android Quick Settings tiles
- ✅ **Configurable** widgets — user-editable params via the OS config UI
- ✅ Adaptive light/dark + runtime colors, locale formatting (`MFormat`), auto RTL
- ✅ Interactive buttons (iOS 17 AppIntents), deep links, refresh, background callbacks
- ✅ Rich UI: gradients, borders, shadows, gauges, icons, dividers, badges, lists
- ✅ **Refresh with the app closed** — declare an endpoint under `refresh:` and the widget fetches and stores it itself
- ✅ **Network images**, cached on disk by the widget process; rounded or circular (`radius` / `circle`) for avatars
- ✅ **Device metrics** — battery, charging, storage and RAM, read *in the widget process*, so they stay correct when the app has not run for days ([one iOS exception](docs/DSL_REFERENCE.md#device-metrics))
- ✅ **Accessibility** — `MSemantics` → VoiceOver / TalkBack labels
- ✅ **Translated widget text** — `MLocalized` compiles to real `values-<locale>/` and `.lproj` resources, so the OS picks the language even though `intl` cannot reach the widget process
- ✅ **Per-size layouts** — `compactRoot:` gives small tiles their own tree instead of a squeezed large one
- ✅ **Material You** — `MColor.system(...)` picks up the user's wallpaper palette on Android 12+
- ✅ **Tinted-mode aware** (iOS 18+) — photos keep their colour when users tint widgets
- ✅ **Server-driven updates** — WidgetKit push (iOS 26+) reloads a widget's timeline remotely
- ✅ **In-app "Add to Home Screen"** — `MosaicBridge.requestPinWidget()` opens the launcher's add-widget dialog (Android 8+), the single biggest lever on widget adoption
- ✅ **One-line host integration** — generated `MosaicPlugin` for both platforms; no method-channel boilerplate
- ✅ AI-ready — ships an agent skill so assistants use the real API

Widgets render static snapshots on both platforms, so there is no general
animation and **Lottie is not possible**. What is available: an animated spinner
and self-cycling content on Android, digit-roll transitions on iOS 17+, and live
timers on both — each documented with its platform limits rather than degrading
silently.

## Install

```yaml
dependencies:
  mosaic_widgets: ^0.1.0      # the DSL + the app-side bridge
dev_dependencies:
  mosaic_cli: ^0.1.0          # the code generator, dev-only
```

`mosaic_cli` is a `dev_dependency` on purpose: it generates native code at build
time and ships nothing into your app.

## Use it in 4 steps

1. **Scaffold**: `dart run mosaic_cli init` writes `mosaic.yaml`, reading your
   real `bundle_id` and `android_package` from the Android and iOS projects, then
   `dart run mosaic_cli add widget News` creates the definition file and registers
   it. A widget entry needs only a name and an entry:
   ```yaml
   widgets:
     - name: News                         # requires a top-level buildNews()
       entry: lib/home_widgets/news.widget.dart
       ios: { families: [systemMedium] }  # optional; accessoryRectangular = Lock Screen
   ```
2. **Design** it in that file — definition files import the pure-Dart DSL
   `package:mosaic_widgets/dsl.dart` (see the example above).
3. **Generate** native code: `dart run mosaic_cli build`
4. **Push data** from your app (uses the full barrel `package:mosaic_widgets/mosaic_widgets.dart`):
   ```dart
   import 'package:mosaic_widgets/mosaic_widgets.dart';
   await MosaicBridge.setAppGroupId('group.com.example.app.widgets'); // iOS
   await MosaicBridge.saveString('title', 'Markets rally');
   await MosaicBridge.refreshAll();
   ```

> One-time native wiring (Xcode Widget Extension target, AppDelegate/MainActivity) is in the setup guides. Run `dart run mosaic_cli doctor` to check your project.

## CLI

All via `dart run mosaic_cli <cmd>`:

| Command | What it does |
|---|---|
| `init` | Writes `mosaic.yaml`, reading your real `applicationId` and `PRODUCT_BUNDLE_IDENTIFIER` so the App Group is right first time |
| `add widget <Name>` | Scaffolds the definition file **and** registers it, in whichever directory your existing entries use |
| `add live-activity <Name>` | Scaffolds a Live Activity (lock screen + Dynamic Island) and creates `live_activities:` if needed |
| `add control <Name>` | Scaffolds a Control Center / Quick Settings toggle |
| `build` | Generates native code; fails fast on missing drawables, undeclared string keys, mismatched deep-link schemes and misconfigured controls; prunes files left by removed widgets |
| `list` | Every declared entry with its status — missing builder, missing native output — plus refresh callbacks and locales. `--paths` shows generated file paths |
| `doctor` | 15 setup checks. Exits non-zero on fatal ones |
| `doctor --fix` | Repairs what has one right answer: `supportsRtl`, package mismatch, `group.` prefix, entitlements files, `NSSupportsLiveActivities`. Never edits your Xcode project |
| `clean` | Removes generated code, keeps yours |

`doctor` catches the failures that are otherwise silent — a widget that renders
blank because the App Group is unset, a deep link that resolves to nothing, a
generated Swift file with no Xcode target to compile it.

## Platform support

| | iOS | Android |
|---|---|---|
| Home-screen widgets | ✅ WidgetKit (14+) | ✅ AppWidget |
| Lock Screen widgets | ✅ (16+) | — |
| Live Activities | ✅ ActivityKit (16.1+) | ⚠️ ongoing notification (Live Updates on Android 16 / API 36+) |
| Dynamic Island | ✅ | — |
| Controls | ✅ Control Center (18+) | ✅ Quick Settings tile (API 24+, user-added) |
| Interactive buttons | ✅ AppIntent (17+) / deep-link | ✅ |
| Configurable widgets | ✅ (17+) | ✅ |

## 🤖 AI-ready

Mosaic is newer than most model training data, so it ships a self-contained **agent skill** that teaches assistants the real API. Install it once:

```bash
cp -r skills/mosaic-widgets ~/.claude/skills/
```

Any assistant then auto-loads it on seeing a `mosaic.yaml`, a `package:mosaic_widgets` import, or a `*.widget.dart` / `*.live.dart` file. See also [`llms.txt`](llms.txt) and [`AGENTS.md`](AGENTS.md).

## Docs

[DSL Reference](docs/DSL_REFERENCE.md) · [iOS Setup](docs/IOS_SETUP.md) · [Android Setup](docs/ANDROID_SETUP.md) · [Live Activities](docs/LIVE_ACTIVITIES.md) · [Roadmap](docs/ROADMAP.md)

## Support

If Mosaic helped you, consider supporting the author:

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-1.svg)](https://buymeacoffee.com/is10vmust)
