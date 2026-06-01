# mosaic

[![StandWithPalestine](https://raw.githubusercontent.com/TheBSD/StandWithPalestine/main/badges/StandWithPalestine.svg)](https://github.com/TheBSD/StandWithPalestine/blob/main/docs/README.md) [![Pub Package](https://img.shields.io/pub/v/mosaic.svg)](https://pub.dev/packages/mosaic)

One DSL, native home-screen widgets on **both** platforms. Write a widget once in Flutter-style Dart and Mosaic generates native **SwiftUI/WidgetKit** (iOS) and **RemoteViews/Kotlin** (Android) — plus **Live Activities, Dynamic Island, and Lock Screen** widgets. Push live data from your app; the OS renders the tile.

- ✅ Single Dart DSL → real native widgets (no platform code to hand-write)
- ✅ Live runtime data binding (`MBind`) — text, images, progress, visibility, timers, colors
- ✅ Live Activities + **Dynamic Island** (iOS), ongoing-notification fallback (Android)
- ✅ Lock Screen **accessory** widgets (iOS 16+)
- ✅ Adaptive light/dark + runtime colors, locale-aware formatting (`MFormat`), auto **RTL**
- ✅ Interactive buttons (iOS 17 AppIntents), deep links, background callbacks, refresh
- ✅ **Configurable** widgets — user-editable params via the OS config UI
- ✅ Rich UI: gradients, borders, shadows, per-corner radius, gauges, icons, dividers, badges, lists
- ✅ CLI-driven codegen + automatic manifest/Info.plist wiring

## Install

```yaml
dependencies:
  mosaic:
    path: path/to/mosaic/platform/flutter
  mosaic_core:
    path: path/to/mosaic/platform/core

dev_dependencies:
  mosaic_cli:
    path: path/to/mosaic/platform/cli
```

> Monorepo packages: `mosaic` (DSL + bridge), `mosaic_core` (IR/config/runner), `mosaic_android` & `mosaic_ios` (generators), `mosaic_cli` (tooling).

## Quick start

**1. Define a widget** — definition files import the **pure-Dart DSL** (`package:mosaic/dsl.dart`) so the build runner can execute them:

```dart
import 'package:mosaic/dsl.dart';

MosaicDefinition buildNewsWidget() => MosaicDefinition(
  name: 'NewsWidget',
  width: 4, height: 1,
  root: MContainer(
    background: const MColor.hex('#111827', dark: '#000000'),
    radius: 16,
    child: MPadding(const MInsets.all(12),
      MText(MBind('news_title'),
        style: const MTextStyle(color: MColor.hex('#FFFFFF'), bold: true))),
  ),
);
```

**2. Register it** in `mosaic.yaml`:

```yaml
app:
  bundle_id: com.example.myapp
  android_package: com.example.myapp
  ios_app_group: group.com.example.myapp.widgets
widgets:
  - name: NewsWidget
    entry: lib/home_widgets/news.widget.dart
    android: { min_sdk: 21, sizes: [medium] }
    ios: { families: [systemMedium] }
```

**3. Generate native code:**

```bash
dart run mosaic_cli build
```

**4. Push data from your app** — app code imports the full barrel (`package:mosaic/mosaic.dart`):

```dart
import 'package:mosaic/mosaic.dart';

await MosaicBridge.setAppGroupId('group.com.example.myapp.widgets');
await MosaicBridge.saveString('news_title', 'Markets rally');
await MosaicBridge.refreshAll();
```

That's it — no per-platform widget code.

### Theming (adaptive + runtime colors, formatting)

```dart
// White in light mode, soft grey in dark — the OS switches automatically.
const MText('BTC/USD', style: MTextStyle(color: MColor.hex('#FFFFFF', dark: '#E5E7EB')))
// Locale-aware currency formatting of a bound numeric value.
MText(MBind('btc_price'), format: MFormat.currency)
// Runtime-bound color the app pushes as a hex string.
const MContainer(background: MColor.bind('accent'), child: MSpacer())
```

Layouts auto-mirror in RTL locales. `MFormat`: `decimal · currency · percent · date · relativeTime`.

### Lock Screen (iOS accessory widgets)

```yaml
ios: { families: [systemMedium, accessoryRectangular] } # also accessoryCircular, accessoryInline
```

### Live Activities & Dynamic Island

```dart
// lib/live_activities/order_tracker.live.dart  (import package:mosaic/dsl.dart)
MosaicLiveActivity buildOrderTracker() => MosaicLiveActivity(
  name: 'OrderTracker',
  lockScreen: MText(MBind('status')),
  dynamicIsland: MDynamicIsland(
    compactLeading: const MText('🛵'),
    compactTrailing: MText(MBind('eta')),
    minimal: const MText('🛵'),
    expanded: MExpanded(
      center: MText(MBind('status')),
      bottom: MProgressBar(value: MBind('progress')),
    ),
  ),
);
```

```dart
// Drive the lifecycle from your app (package:mosaic/mosaic.dart).
final id = await MosaicLiveActivities.start('OrderTracker',
    {'status': 'Preparing', 'progress': '10', 'eta': '25 min'});
await MosaicLiveActivities.update(id!, {'status': 'On the way', 'progress': '60', 'eta': '8 min'},
    alert: const MActivityAlert(title: 'Order update', body: 'Your courier is nearby'));
await MosaicLiveActivities.end(id, policy: MEndPolicy.afterDefault);
```

Register under `live_activities:` in `mosaic.yaml`. iOS needs `NSSupportsLiveActivities=true`. Full walkthrough: [Live Activities Guide](DOCS/LIVE_ACTIVITIES.md).

### Configurable widgets

```dart
params: const [
  MParam(key: 'city', label: 'City', type: MParamType.choice,
         defaultValue: 'London', choices: ['London', 'Paris', 'Tokyo']),
],
```

The chosen value is available anywhere via `MBind('city')`. iOS → AppIntentConfiguration (17+); Android → a configuration Activity.

### Interactivity

```dart
MButton(action: const MRefreshAction(), child: const MText('Refresh'))
MButton(action: const MActionCallback('sync'), child: const MText('Sync'))   // → registerBackgroundCallback
MButton(action: const MLaunchUrlAction('myapp://open'), child: const MText('Open'))
```

## CLI

| Command | What it does |
|---|---|
| `dart run mosaic_cli init` | Create `mosaic.yaml` + `lib/home_widgets/` |
| `dart run mosaic_cli add widget <Name>` | Scaffold a new widget definition |
| `dart run mosaic_cli build` | Generate native code + wire manifest/Info.plist |
| `dart run mosaic_cli doctor` | Diagnose project configuration |
| `dart run mosaic_cli clean` | Remove generated artifacts |

## Components

Layout: `MContainer` · `MColumn` · `MRow` · `MStack` · `MPositioned` · `MCenter` · `MPadding` · `MSpacer` · `MDivider`
Content: `MText` · `MImage` · `MIcon` · `MProgressBar` · `MGauge` · `MBadge` · `MTimer` · `MButton` · `MVisibility` · `MListView`
Style: `MColor` · `MTextStyle` · `MInsets` · `MLinearGradient` · `MBorder` · `MRadius` · `MShadow` · `MFormat`

Full attributes in the [DSL Reference](DOCS/DSL_REFERENCE.md).

## Platform support

| | iOS | Android |
|---|---|---|
| Home-screen widgets | ✅ WidgetKit (14+) | ✅ AppWidget |
| Lock Screen / accessory | ✅ (16+) | — (no user lock-screen widgets) |
| Live Activities | ✅ ActivityKit (16.1+) | ⚠️ ongoing-notification fallback |
| Dynamic Island | ✅ | — |
| Interactive buttons | ✅ AppIntent (17+) / deep-link (14–16) | ✅ |
| Configurable widgets | ✅ (17+) | ✅ config Activity |

## 🤖 AI / Agent support

Mosaic ships a self-contained agent skill so AI assistants build with the **real** API (Mosaic is newer than most model training data):

- **Skill:** [`skills/mosaic-widgets/SKILL.md`](skills/mosaic-widgets/SKILL.md) — install with `cp -r skills/mosaic-widgets ~/.claude/skills/`
- **LLM index:** [`llms.txt`](llms.txt) · **Contributor guide:** [`AGENTS.md`](AGENTS.md)

## Docs

- [DSL Reference](DOCS/DSL_REFERENCE.md) · [iOS Setup](DOCS/IOS_SETUP.md) · [Android Setup](DOCS/ANDROID_SETUP.md)
- [Live Activities Guide](DOCS/LIVE_ACTIVITIES.md) · [Roadmap](docs/ROADMAP.md) · [Publishing](docs/PUBLISHING.md)

## Support

If Mosaic helped you, consider supporting the author:

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-1.svg)](https://buymeacoffee.com/is10vmust)
