# Mosaic Roadmap — Widgets & Features for Any Business

Mosaic turns one Dart DSL into native iOS (WidgetKit / Live Activities / Dynamic Island)
and Android (AppWidget) experiences. This roadmap maps **what businesses ask for** to the
**components and capabilities** Mosaic needs, and lays out a prioritized build plan.

Status legend: ✅ shipped · 🔨 planned-this-program · 🔭 future.

---

## 1. What's already shipped ✅

- Layout: Container, Column, Row, Stack, Positioned, Center, Padding, Spacer
- Content: Text (+ bindings, maxLines), Image (asset/file/network/bind, fit modes, radius/circle), ProgressBar, Timer, Button, Visibility(+replacement), ListView (both platforms)
- Styling: gradients, borders, radius, adaptive (light/dark) + runtime-bind colors, text styles
- Interactivity: deep links, background callbacks, refresh; **iOS-17 AppIntent buttons**
- Live Activities + **Dynamic Island** (compact/minimal/expanded); **Android 16 Live Updates** (`Notification.ProgressStyle` + promoted-ongoing, API 36+) with ongoing-notification fallback on pre-36
- Lock-screen accessory widgets (iOS 16+)
- **Control Widgets** — iOS 18 Control Center / Lock Screen (`ControlWidgetToggle` / `ControlWidgetButton`, gated iOS 18+); Android Quick Settings tiles (`TileService`, API 24+, user-added; `<service>` auto-registered by `dart run mosaic_widgets:mosaic build`)
- Locale: RTL auto-mirroring + `MFormat` (currency/decimal/percent/date/relativeTime)
- Runtime data binding from the app via `MosaicBridge`

---

## 2. Business verticals → what they need

| Vertical | Widget ideas | Components/capabilities required |
|---|---|---|
| **Finance / Crypto** | Price ticker, portfolio value, watchlist, P/L sparkline | ✅ sparkline, ✅ icon, ✅ currency format, ✅ lists |
| **Delivery / Logistics** | Order tracking, courier ETA, route step | ✅ Live Activity + Dynamic Island, ✅ network image (map snapshot), ✅ progress, 🔨 step indicator |
| **Fitness / Health** | Activity rings, step/calorie goals, streak, water intake | ✅ gauge/ring, ✅ progress, ✅ icon, 🔨 multi-ring, ✅ bar chart |
| **Productivity / Tasks** | Today's tasks, habit tracker, countdown to event, focus timer | ✅ list rows, ✅ timer, ✅ configurable, 🔨 calendar/agenda layout |
| **Weather** | Current conditions, hourly strip, 5-day, sunrise/sunset arc | ✅ icon, ✅ gauge/arc, ✅ list (hourly strip), ✅ chart |
| **Commerce / Retail** | Deal of the day, loyalty points, order status, cart count | ✅ badge, ✅ image, ✅ Live Activity, ✅ configurable, 🔨 barcode/QR |
| **Media / Entertainment** | Now-playing, podcast progress, up-next, sports scores | ✅ AppIntent buttons, ✅ progress/timer, ✅ rounded artwork + shadow, ✅ Live Activity |
| **Social / Comms** | Unread counts, latest message, presence, streaks | ✅ badge, ✅ text bind, ✅ circular avatar, ✅ configurable |
| **Travel / Airlines** | Boarding pass, flight status, gate/seat, itinerary | ✅ Live Activity + Dynamic Island, ✅ divider, ✅ icon, 🔨 QR/barcode |
| **Smart Home / IoT** | Device status, scene toggles, thermostat, camera snapshot | ✅ interactive toggle, ✅ gauge, ✅ image, ✅ configurable, ✅ Control Center tile |

---

## 3. Component & capability catalog (prioritized)

### Tier 1 — Components pack ✅ shipped
All landed on both platforms with tests:
- ✅ **MDivider**, ✅ **MIcon** (SF Symbols / Android drawable), ✅ **MGauge**,
  ✅ **MShadow**, ✅ **MRadius** (per-corner), ✅ **maxLines** + **MTextAlign**,
  ✅ **MLinearGradient(angle:)**, ✅ **MBadge**.
- Added since: ✅ **MSizedBox**, ✅ **MAlign**, ✅ **MFlexible**, ✅ **MNetworkImage**
  (disk-cached, radius/circle), ✅ **MActivityIndicator**, ✅ **MFlipper**,
  ✅ **MSemantics**, ✅ **MLocalized**, ✅ **MDeviceValue**, ✅ **MContainer(padding:)**.

### Tier 2 — Data-viz (🔨/🔭)
- ✅ **MSparkline** — series bind → SwiftUI `Path` on iOS, `Canvas`-rasterised bitmap on Android. Verified rendering on-device.
- ✅ **MBarChart** — scaled from zero; SwiftUI shapes on iOS, rasterised on Android. Verified on-device.
- ✅ **Android ListView** — shipped: generated `RemoteViewsService`/`RemoteViewsFactory`, `<service>` auto-registered, verified rendering four bound rows on-device.

### Tier 3 — Platform capabilities ✅ shipped
- ✅ **Configurable widgets** — `MParam` → iOS `AppIntentConfiguration` + Android configuration Activity.
- ✅ **Push-updatable widgets & Live Activities** — `push: true` surfaces the APNs token through `MosaicBridge.widgetPushTokens()` (WidgetKit push is iOS 26+).
- ✅ **Interactive toggles** — `MToggleAction` flips stored state entirely on-device, so it works with the app closed.

### Tier 4 — Reach & polish (🔭 future)
- ✅ **Accessibility** — `MSemantics` → iOS `.accessibilityLabel`, Android `contentDescription`.
- ✅ **String tables** — `MLocalized` + `strings:` → real `.lproj` / `values-<locale>` resources.
- 🔭 **watchOS complications**.
- 🔭 **Android Material You** dynamic color (`@android:color/system_accent1_*`), themed-icon.
- ✅ **Per-family layouts** — `MosaicDefinition(compactRoot:)` renders a second
  tree at small sizes on both platforms: `@Environment(\.widgetFamily)` on iOS,
  `RemoteViews(Map<SizeF, RemoteViews>)` (API 31+) on Android, falling back to
  `root` below 31.
- 🔭 **Preview gallery snapshots**.
- **Server-driven layout** (ship IR over the air) — the big optional architecture.
- **Animations / transitions** within budget (WidgetKit/RemoteViews constraints).

---

## 4. Build plan for THIS program

1. ✅ **Components pack (Tier 1)** — shipped.
2. ✅ **Configurable widgets (Tier 3)** — shipped.
3. ✅ **Push-updatable widgets (Tier 3)** — shipped.
4. ✅ **Android ListView (Tier 2)** — RemoteViewsService implementation shipped and verified on-device.
5. **Prepare-for-publish** — finalize metadata, dep-swap plan documented, `pub publish --dry-run` pana check; **do not publish** until explicitly approved and a real repo URL is set.

Each item ships behind the CI quality gate:

| Job | Proves |
|---|---|
| `dart` / `flutter` | Every package analyzes with `--fatal-infos` and its tests pass. |
| `android-build` | `dart run mosaic_widgets:mosaic build` succeeds, `doctor` reports no fatal problem, and the generated XML and Kotlin survive **AAPT and kotlinc**. |
| `greenfield` | A project scaffolded from `flutter create` onward — `init`, `add widget`/`live-activity`/`control`, `build`, `flutter build apk` — and that `doctor` still *reports* the iOS wiring Xcode has to do. |
| `swift-typecheck` | Generated Swift typechecks at every gated iOS version: 16.0, 16.1, 17.0, 18.0. |

The two compile jobs exist because unit tests assert on generated *strings*. A
Kotlin reference to an out-of-scope variable passes `dart analyze` and all 300+
unit tests, and fails only at `assembleDebug` — which is how several bugs
reached the demo before that job existed.

---

## 5. Known gaps / honest notes
- **Android live activity** uses `Notification.ProgressStyle` + promoted-ongoing on API 36+ (Android 16 Live Updates) and an ongoing-notification approximation on pre-36. Dynamic Island has no Android equivalent.
- **On-device runtime**: Android widgets are verified rendering on an emulator (all six, including the list, interactive refresh, toggles and deep links). **iOS live render is still a manual gate** — the generated Swift compiles into the `.appex` in CI-style checks, but adding a Widget Extension target and placing a widget needs Xcode by hand.
- **Repo URL** in pubspecs is a placeholder pending the real GitHub URL.
