# Mosaic Roadmap — Widgets & Features for Any Business

Mosaic turns one Dart DSL into native iOS (WidgetKit / Live Activities / Dynamic Island)
and Android (AppWidget) experiences. This roadmap maps **what businesses ask for** to the
**components and capabilities** Mosaic needs, and lays out a prioritized build plan.

Status legend: ✅ shipped · 🔨 planned-this-program · 🔭 future.

---

## 1. What's already shipped ✅

- Layout: Container, Column, Row, Stack, Positioned, Center, Padding, Spacer
- Content: Text (+ bindings), Image (asset/file/bind, fit modes), ProgressBar, Timer, Button, Visibility(+replacement), ListView (iOS real; Android pending)
- Styling: gradients, borders, radius, adaptive (light/dark) + runtime-bind colors, text styles
- Interactivity: deep links, background callbacks, refresh; **iOS-17 AppIntent buttons**
- Live Activities + **Dynamic Island** (compact/minimal/expanded); Android ongoing-notification fallback
- Lock-screen accessory widgets (iOS 16+)
- Locale: RTL auto-mirroring + `MFormat` (currency/decimal/percent/date/relativeTime)
- Runtime data binding from the app via `MosaicBridge`

---

## 2. Business verticals → what they need

| Vertical | Widget ideas | Components/capabilities required |
|---|---|---|
| **Finance / Crypto** | Price ticker, portfolio value, watchlist, P/L sparkline | 🔨 Sparkline/line chart, 🔨 trend arrow icon, ✅ currency format, 🔨 marquee/ticker, ✅ lists (Android) |
| **Delivery / Logistics** | Order tracking, courier ETA, route step | ✅ Live Activity + Dynamic Island, 🔨 static map image, 🔨 step/stepper indicator, ✅ progress |
| **Fitness / Health** | Activity rings, step/calorie goals, streak, water intake | 🔨 Ring/gauge progress, 🔨 multi-ring, ✅ progress, 🔨 icon set, 🔨 chart (bars) |
| **Productivity / Tasks** | Today's tasks, habit tracker, countdown to event, focus timer | 🔨 Checklist/list rows, ✅ timer, 🔨 calendar/agenda layout, 🔨 configurable (which list) |
| **Weather** | Current conditions, hourly strip, 5-day, sunrise/sunset arc | 🔨 Icon (SF Symbols/Material), 🔨 horizontal strip, 🔨 gauge/arc, 🔨 chart |
| **Commerce / Retail** | Deal of the day, loyalty points, order status, cart count | 🔨 Badge, ✅ image, 🔨 barcode/QR image, ✅ Live Activity (order), 🔨 configurable (store) |
| **Media / Entertainment** | Now-playing, podcast progress, up-next, sports scores | 🔨 Now-playing controls (AppIntent buttons), ✅ progress/timer, 🔨 live score Live Activity, 🔨 rounded artwork + shadow |
| **Social / Comms** | Unread counts, latest message, presence, streaks | 🔨 Badge/avatar, ✅ text bind, 🔨 avatar (rounded image), 🔨 configurable (account) |
| **Travel / Airlines** | Boarding pass, flight status, gate/seat, itinerary | ✅ Live Activity + Dynamic Island, 🔨 QR/barcode, 🔨 divider, 🔨 icon |
| **Smart Home / IoT** | Device status, scene toggles, thermostat, camera snapshot | 🔨 Interactive toggle (AppIntent), 🔨 gauge, ✅ image (snapshot), 🔨 configurable (device) |
| **News / Content** | Headlines, category, reading list | ✅ lists (iOS), 🔨 lists (Android), 🔨 truncation/line-clamp, 🔨 configurable (feed) |

---

## 3. Component & capability catalog (prioritized)

### Tier 1 — Components pack (🔨 this program, highest reach)
Small, broadly-useful additions; each lands on both platforms with golden tests.
- **MDivider** — horizontal/vertical rule (thickness, color, inset).
- **MIcon** — SF Symbols on iOS, Material/named drawable on Android; size + color (+ adaptive/bind).
- **MGauge / MRing** — circular/arc progress (value, max, track + fill color, line width) — fitness/weather/finance.
- **Shadow / elevation** — drop shadow on Container (iOS `.shadow`, Android elevation/outline).
- **Per-corner radius** — `MRadius.only(topLeft, …)` (iOS `clipShape`, Android shape `<corners>` per-corner).
- **Text truncation & alignment** — maxLines/ellipsis + `MTextAlign` (start/center/end).
- **Gradient angle / direction** — `MLinearGradient(angle:)` or begin/end alignment; radial gradient.
- **Badge** — count/dot overlay (commerce/social).

### Tier 2 — Data-viz (🔨/🔭)
- **MSparkline / MLineChart** — series bind → path (iOS Path/Canvas, Android pre-rendered or `setImageViewBitmap`).
- **MBarChart** — simple bars.
- **Android ListView** — implement `RemoteViewsService`/`RemoteViewsFactory` (currently throws) — unlocks all list use-cases on Android. (BIG)

### Tier 3 — Platform capabilities (🔨 this program)
- **Configurable widgets** — user-editable params: iOS `AppIntentConfiguration`, Android configuration Activity; DSL config schema (enum/text/toggle params). Serves "pick a city/stock/account".
- **Push-updatable Live Activities** — APNs token from `start`, server-driven `update`/`end`. (iOS)
- **Interactive toggles/steppers** — AppIntent-backed controls beyond buttons (smart home, now-playing).

### Tier 4 — Reach & polish (🔭 future)
- **Accessibility** — `semanticLabel` per node → iOS `.accessibilityLabel`, Android `contentDescription`.
- **iOS Control Widgets** (iOS 18 Control Center) and **watchOS complications**.
- **Android Material You** dynamic color (`@android:color/system_accent1_*`), themed-icon.
- **Multiple widget sizes / galleries**, **preview gallery snapshots**, **per-widget intents catalog**.
- **String tables** (compile-time localization) — deferred from locale work.
- **Server-driven layout** (ship IR over the air) — the big optional architecture.
- **Animations / transitions** within budget (WidgetKit/RemoteViews constraints).

---

## 4. Build plan for THIS program

1. **Components pack (Tier 1)** — MDivider, MIcon, MGauge/MRing, shadow, per-corner radius, text truncation+align, gradient angle, badge. Both platforms, TDD, native-verified.
2. **Configurable widgets (Tier 3)** — config-param schema in `mosaic.yaml`/DSL → iOS AppIntentConfiguration + Android configuration Activity.
3. **Push-updatable Live Activities (Tier 3)** — APNs push token surfaced through the bridge; server update/end path; docs.
4. **Android ListView (Tier 2)** — RemoteViewsService implementation to remove the current "unsupported" error (high business value: lists everywhere).
5. **Prepare-for-publish** — finalize metadata, dep-swap plan documented, `pub publish --dry-run` pana check; **do not publish** until explicitly approved and a real repo URL is set.

Each item ships behind the existing quality gate: unit/golden tests + `flutter build apk` (AAPT-valid) + `swiftc -typecheck` at iOS 16.1 and 17.0.

---

## 5. Known gaps / honest notes
- **Android ListView** currently throws by design — Tier 2 item #3 fixes it.
- **Android live activity** is an ongoing-notification approximation; Dynamic Island has no Android equivalent.
- **On-device runtime** (widgets actually rendering on a home screen / Dynamic Island / lock screen) requires adding generated files to the Xcode Widget Extension target and running on device — compilation is proven in CI-style checks; live render is a manual gate.
- **Repo URL** in pubspecs is a placeholder pending the real GitHub URL.
