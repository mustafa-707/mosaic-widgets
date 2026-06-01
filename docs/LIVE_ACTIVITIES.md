# Live Activities & Dynamic Island

Mosaic Live Activities give you a glanceable, updating presentation outside your app:

- **iOS (16.1+)** — a full ActivityKit Live Activity: a Lock Screen / banner view **and** the Dynamic Island (compact, minimal, and expanded presentations).
- **Android** — a best-effort **ongoing notification** built from the Lock Screen tree. There is no true Live Activity and **no Dynamic Island** on Android (those regions are ignored).

A Live Activity is driven by a `Map<String, String>` *content state*. `MBind('key')` inside the activity resolves against that map, and `MFormat` formats bound numeric/date values with the device locale at render time.

---

## 1. Define a `.live.dart`

Create an entry file that imports the pure-Dart DSL and exports a `MosaicLiveActivity build<Name>()` function. This is the demo's `examples/demo_app/lib/platform/live_activities/order_tracker.live.dart`:

```dart
import 'package:mosaic/dsl.dart';

/// A delivery-tracking Live Activity driven by a {status, progress, eta} map.
MosaicLiveActivity buildOrderTracker() {
  return MosaicLiveActivity(
    name: 'OrderTracker',
    lockScreen: MContainer(
      background: const MColor.hex('#111827', dark: '#000000'),
      radius: 16,
      child: MPadding(
        const MInsets.all(12),
        MColumn(
          crossAxisAlignment: MCrossAxisAlignment.start,
          [
            const MText('Order on the way',
                style: MTextStyle(color: MColor.hex('#FFFFFF'), size: 14, bold: true)),
            MText(MBind('status'),
                style: const MTextStyle(color: MColor.hex('#9CA3AF'), size: 12)),
            MProgressBar(value: MBind('progress'), color: const MColor.hex('#34D399')),
            MRow([
              const MText('ETA ',
                  style: MTextStyle(color: MColor.hex('#9CA3AF'), size: 12)),
              MText(MBind('eta'),
                  style: const MTextStyle(color: MColor.hex('#FFFFFF'), size: 12, bold: true)),
            ]),
          ],
        ),
      ),
    ),
    dynamicIsland: MDynamicIsland(
      compactLeading: const MText('🛵', style: MTextStyle(size: 14)),
      compactTrailing: MText(MBind('eta'),
          style: const MTextStyle(color: MColor.hex('#FFFFFF'), size: 12, bold: true)),
      minimal: const MText('🛵', style: MTextStyle(size: 12)),
      expanded: MExpanded(
        leading: const MText('Order',
            style: MTextStyle(color: MColor.hex('#FFFFFF'), size: 12, bold: true)),
        trailing: MText(MBind('eta'),
            style: const MTextStyle(color: MColor.hex('#34D399'), size: 12, bold: true)),
        center: MText(MBind('status'),
            style: const MTextStyle(color: MColor.hex('#FFFFFF'), size: 12)),
        bottom: MProgressBar(value: MBind('progress'), color: const MColor.hex('#34D399')),
      ),
    ),
  );
}
```

**Components** (full reference in [DSL_REFERENCE.md](DSL_REFERENCE.md)):

- `MosaicLiveActivity(name, lockScreen, dynamicIsland)` — `name` must match `mosaic.yaml`.
- `MDynamicIsland(compactLeading, compactTrailing, minimal, expanded)` — the iOS Dynamic Island regions.
- `MExpanded(leading, trailing, center, bottom)` — the long-press expanded layout slots (all optional).

> The `dynamicIsland` is required by the DSL even though Android ignores it, so a single definition serves both platforms.

---

## 2. Register it in `mosaic.yaml`

Add the activity under a `live_activities:` list (name + entry), alongside your `widgets:`:

```yaml
live_activities:
  - name: OrderTracker
    entry: lib/platform/live_activities/order_tracker.live.dart
```

Then regenerate native code:

```bash
dart run mosaic_cli build
```

This emits the iOS `MosaicActivityAttributes.swift` + `<Name>LiveActivity.swift` (registered in the widget bundle under an iOS 16.1 gate) and the Android `MosaicLiveActivityManager`.

---

## 3. Drive the lifecycle from Flutter

App code uses `MosaicLiveActivities` from the full barrel `package:mosaic/mosaic.dart`. State is always a `Map<String, String>` (stringify numbers/dates; let `MFormat` do locale formatting at render).

```dart
import 'package:mosaic/mosaic.dart';

// Check availability (iOS: Live Activities enabled; Android: notifications enabled).
if (!await MosaicLiveActivities.areEnabled()) return;

// Start — returns the OS-assigned id (null when unavailable on this device/OS).
final id = await MosaicLiveActivities.start('OrderTracker', {
  'status': 'Preparing your order',
  'progress': '0.1',
  'eta': '25 min',
});

// Update — push new state. Optionally show an alert on the Lock Screen / Dynamic Island.
await MosaicLiveActivities.update(
  id!,
  {'status': 'On the way', 'progress': '0.6', 'eta': '8 min'},
  alert: const MActivityAlert(title: 'Order update', body: 'Your courier is nearby'),
);

// End — optionally show a final state, and choose when the UI is dismissed.
await MosaicLiveActivities.end(
  id,
  finalState: {'status': 'Delivered', 'progress': '1.0', 'eta': 'Now'},
  policy: MEndPolicy.afterDefault, // or MEndPolicy.immediate
);

// List currently active activity ids managed by this app.
final ids = await MosaicLiveActivities.active();
```

### API summary

| Method | Signature | Notes |
|--------|-----------|-------|
| `start` | `Future<String?> start(String activityType, Map<String,String> initialState)` | Returns the activity id, or `null` if unavailable. |
| `update` | `Future<void> update(String id, Map<String,String> state, {MActivityAlert? alert})` | `alert` shows a Lock Screen / Dynamic Island notification. |
| `end` | `Future<void> end(String id, {Map<String,String>? finalState, MEndPolicy policy})` | `policy` defaults to `MEndPolicy.afterDefault`. |
| `areEnabled` | `Future<bool> areEnabled()` | Whether Live Activities (iOS) / notifications (Android) are enabled. |
| `active` | `Future<List<String>> active()` | Ids of active activities managed by this app. |

- `MActivityAlert({required String title, required String body})`.
- `MEndPolicy { immediate, afterDefault }` — `immediate` removes the UI at once; `afterDefault` keeps it briefly per the system default.

---

## 4. Platform behavior & setup

### iOS (full, 16.1+)

- Add `NSSupportsLiveActivities` → `true` to the **main app** `Info.plist`.
- The generated `MosaicActivityController` is invoked from your `AppDelegate.swift` `mosaic_bridge` handler (`startActivity` / `updateActivity` / `endActivity` / `activitiesEnabled` / `activeActivities`), all gated `@available(iOS 16.1, *)`. Import `ActivityKit`.
- Lock Screen view + Dynamic Island compact/minimal/expanded are all rendered.

See [IOS_SETUP.md](IOS_SETUP.md) section 8.

### Android (best-effort)

- A live activity becomes an **ongoing notification** with `RemoteViews` built from the `lockScreen` tree; Dynamic Island regions are ignored.
- Requires `POST_NOTIFICATIONS` on **API 33+** (request it at runtime before starting).
- `MainActivity.kt` routes the lifecycle calls to the generated `MosaicLiveActivityManager`. An `alert` on update produces a heads-up notification.

See [ANDROID_SETUP.md](ANDROID_SETUP.md) section 5.

---

## 5. OrderTracker demo walkthrough

The demo at `examples/demo_app` ships a complete reference:

1. **Definition** — `lib/platform/live_activities/order_tracker.live.dart` (above): a `{status, progress, eta}` delivery tracker with a Lock Screen banner and a Dynamic Island (scooter glyph + ETA compact, status + progress expanded).
2. **Registration** — `mosaic.yaml` lists it under `live_activities:` so `dart run mosaic_cli build` generates the native code.
3. **iOS wiring** — `ios/Runner/Info.plist` sets `NSSupportsLiveActivities`, and `ios/Runner/AppDelegate.swift` routes the lifecycle to `MosaicActivityController`.
4. **Android wiring** — `MainActivity.kt` routes the lifecycle to `MosaicLiveActivityManager`.
5. **Driving it** — from app code, call `MosaicLiveActivities.start('OrderTracker', {...})`, push updates (e.g. as the order progresses) with `update(...)`, and finish with `end(...)`, exactly as in section 3.

---

## Limitations

- **Push (APNs) updates** of Live Activities are not yet supported — updates flow through the app (`MosaicLiveActivities.update`).
- **Per-activity typed content states** are not generated; all state is a generic `Map<String,String>`.
- The Android ongoing notification is **not** a true Live Activity equivalent, and there is no Dynamic Island emulation.
