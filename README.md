<p align="center">
  <img src="assets/mosaic_logo.png" alt="Mosaic — Flutter Widget Builder" width="320">
</p>

<p align="center">
  <a href="https://github.com/TheBSD/StandWithPalestine/blob/main/docs/README.md"><img src="https://raw.githubusercontent.com/TheBSD/StandWithPalestine/main/badges/StandWithPalestine.svg" alt="StandWithPalestine"></a>
  <a href="https://pub.dev/packages/mosaic"><img src="https://img.shields.io/pub/v/mosaic.svg" alt="Pub Package"></a>
</p>

<p align="center"><b>One DSL → native home-screen widgets on iOS and Android.</b></p>

Write a widget once in Flutter-style Dart. Mosaic generates real native **SwiftUI/WidgetKit** (iOS) and **RemoteViews/Kotlin** (Android) — including **Live Activities, Dynamic Island, and Lock Screen** widgets. Your app pushes live data; the OS draws the tile. No per-platform widget code.

```dart
import 'package:mosaic/dsl.dart';

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
- ✅ **Live Activities + Dynamic Island** (iOS); ongoing-notification fallback (Android)
- ✅ **Lock Screen** accessory widgets (iOS 16+)
- ✅ **Configurable** widgets — user-editable params via the OS config UI
- ✅ Adaptive light/dark + runtime colors, locale formatting (`MFormat`), auto RTL
- ✅ Interactive buttons (iOS 17 AppIntents), deep links, refresh, background callbacks
- ✅ Rich UI: gradients, borders, shadows, gauges, icons, dividers, badges, lists
- ✅ AI-ready — ships an agent skill so assistants use the real API

## Install

```yaml
dependencies:
  mosaic: { path: path/to/mosaic/platform/flutter }
  mosaic_core: { path: path/to/mosaic/platform/core }
dev_dependencies:
  mosaic_cli: { path: path/to/mosaic/platform/cli }
```

## Use it in 4 steps

1. **Define** a widget in `lib/home_widgets/news.widget.dart` — definition files import the pure-Dart DSL `package:mosaic/dsl.dart` (see the example above; the function must be `build<Name>()`).
2. **Register** it in `mosaic.yaml`:
   ```yaml
   app: { bundle_id: com.example.app, android_package: com.example.app, ios_app_group: group.com.example.app.widgets }
   widgets:
     - name: News
       entry: lib/home_widgets/news.widget.dart
       android: { min_sdk: 21, sizes: [medium] }
       ios: { families: [systemMedium] }   # add accessoryRectangular for Lock Screen
   ```
3. **Generate** native code: `dart run mosaic_cli build`
4. **Push data** from your app (uses the full barrel `package:mosaic/mosaic.dart`):
   ```dart
   import 'package:mosaic/mosaic.dart';
   await MosaicBridge.setAppGroupId('group.com.example.app.widgets'); // iOS
   await MosaicBridge.saveString('title', 'Markets rally');
   await MosaicBridge.refreshAll();
   ```

> One-time native wiring (Xcode Widget Extension target, AppDelegate/MainActivity) is in the setup guides. Run `dart run mosaic_cli doctor` to check your project.

## CLI

`init` · `add widget <Name>` · `build` · `doctor` · `clean` — all via `dart run mosaic_cli <cmd>`.

## Platform support

| | iOS | Android |
|---|---|---|
| Home-screen widgets | ✅ WidgetKit (14+) | ✅ AppWidget |
| Lock Screen widgets | ✅ (16+) | — |
| Live Activities | ✅ ActivityKit (16.1+) | ⚠️ ongoing notification |
| Dynamic Island | ✅ | — |
| Interactive buttons | ✅ AppIntent (17+) / deep-link | ✅ |
| Configurable widgets | ✅ (17+) | ✅ |

## 🤖 AI-ready

Mosaic is newer than most model training data, so it ships a self-contained **agent skill** that teaches assistants the real API. Install it once:

```bash
cp -r skills/mosaic-widgets ~/.claude/skills/
```

Any assistant then auto-loads it on seeing a `mosaic.yaml`, a `package:mosaic` import, or a `*.widget.dart` / `*.live.dart` file. See also [`llms.txt`](llms.txt) and [`AGENTS.md`](AGENTS.md).

## Docs

[DSL Reference](DOCS/DSL_REFERENCE.md) · [iOS Setup](DOCS/IOS_SETUP.md) · [Android Setup](DOCS/ANDROID_SETUP.md) · [Live Activities](DOCS/LIVE_ACTIVITIES.md) · [Roadmap](docs/ROADMAP.md)

## Support

If Mosaic helped you, consider supporting the author:

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-1.svg)](https://buymeacoffee.com/is10vmust)
