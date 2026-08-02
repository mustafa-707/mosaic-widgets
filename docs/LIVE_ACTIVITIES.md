# Live Activities & Dynamic Island

Mosaic Live Activities give you a glanceable, updating presentation outside your app:

- **iOS (16.1+)** — a full ActivityKit Live Activity: a Lock Screen / banner view **and** the Dynamic Island (compact, minimal, and expanded presentations).
- **Android** — a best-effort **ongoing notification** built from the Lock Screen tree. There is no true Live Activity and **no Dynamic Island** on Android (those regions are ignored).

A Live Activity is driven by a `Map<String, String>` *content state*. `MBind('key')` inside the activity resolves against that map, and `MFormat` formats bound numeric/date values with the device locale at render time.

---

## 1. Define a `.live.dart`

Create an entry file that imports the pure-Dart DSL and exports a `MosaicLiveActivity build<Name>()` function. This is the demo's `examples/demo_app/lib/platform/live_activities/order_tracker.live.dart`:

```dart
import 'package:mosaic_widgets/dsl.dart';

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
    watch: true      # optional — also show on Apple Watch / CarPlay
```

### `watch:` — Apple Watch and CarPlay

`watch: true` adds `supplementalActivityFamilies([.small, .medium])`, so the
activity appears in a paired Apple Watch's Smart Stack and in CarPlay. It reuses
the lock-screen layout you already wrote — there is no second tree to build.

The modifier is **iOS 18+**, while Live Activities start at 16.1, and a
`WidgetConfiguration` is an opaque type that cannot branch on availability
inside its own body. So opting in raises **that activity's** minimum to iOS 18:
below 18 it is not registered, and `Activity.request` for it does nothing. Every
other activity, widget and control in the project is unaffected. Leave it off if
you still support iOS 16–17.

Then regenerate native code:

```bash
dart run mosaic_widgets:mosaic build
```

This emits the iOS `MosaicActivityAttributes.swift` + `<Name>LiveActivity.swift` (registered in the widget bundle under an iOS 16.1 gate) and the Android `MosaicLiveActivityManager`.

---

## 3. Drive the lifecycle from Flutter

App code uses `MosaicLiveActivities` from the full barrel `package:mosaic_widgets/mosaic_widgets.dart`. State is always a `Map<String, String>` (stringify numbers/dates; let `MFormat` do locale formatting at render).

```dart
import 'package:mosaic_widgets/mosaic_widgets.dart';

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
| `start` | `Future<String?> start(String activityType, Map<String,String> initialState, {bool push = false})` | Returns the activity id, or `null` if unavailable. `push: true` requests a per-activity APNs token (iOS only) on `onPushToken` — see section 6. |
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
- For push updates, the AppDelegate reads `push` from the `startActivity` args (passing it to `MosaicActivityController.start`) and sets `MosaicActivityController.onPushToken` to forward each token over the channel as `liveActivityPushToken {id, token}` — see section 6.
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
2. **Registration** — `mosaic.yaml` lists it under `live_activities:` so `dart run mosaic_widgets:mosaic build` generates the native code.
3. **iOS wiring** — `ios/Runner/Info.plist` sets `NSSupportsLiveActivities`, and `ios/Runner/AppDelegate.swift` routes the lifecycle to `MosaicActivityController`.
4. **Android wiring** — `MainActivity.kt` routes the lifecycle to `MosaicLiveActivityManager`.
5. **Driving it** — from app code, call `MosaicLiveActivities.start('OrderTracker', {...})`, push updates (e.g. as the order progresses) with `update(...)`, and finish with `end(...)`, exactly as in section 3.

---

## 6. Push updates (APNs, iOS only)

By default a Live Activity is driven locally with `MosaicLiveActivities.update(...)`. iOS 16.1+ can additionally update (and end) an activity **remotely via APNs** — useful when the update is driven by your backend (an order ships, a score changes) rather than the foreground app, including while the app is killed.

### Enable push at start

Pass `push: true` when starting the activity:

```dart
final id = await MosaicLiveActivities.start(
  'OrderTracker',
  {'status': 'Preparing your order', 'progress': '0.1', 'eta': '25 min'},
  push: true, // request a per-activity APNs push token
);
```

This requests the activity with `pushType: .token` on the iOS side.

### Receive the token via `onPushToken`

iOS issues a **per-activity** APNs push token (and may rotate it during the activity's lifetime). Each token is delivered to Flutter on the `MosaicLiveActivities.onPushToken` broadcast stream as a lowercase hex string:

```dart
final sub = MosaicLiveActivities.onPushToken.listen((MosaicPushToken t) {
  // t.id    -> the activity id (same id returned by start)
  // t.token -> the APNs push token, hex-encoded
  myApi.registerLiveActivityToken(activityId: t.id, pushToken: t.token);
});
// ... cancel the subscription when you no longer need updates: sub.cancel();
```

Start listening **before** (or right as) you call `start(..., push: true)` so the first token isn't missed; the stream is a broadcast stream, so multiple listeners are fine.

### Send updates from your server (out of scope)

Once your server has the token it pushes updates/ends directly to APNs — **Mosaic does not do this part, and the APNs/server integration is the app's responsibility**. In outline:

1. Send a push to APNs with topic `<your.bundle.id>.push-type.liveactivity` and header `apns-push-type: liveactivity`.
2. The payload's `aps` contains `"event": "update"` (or `"end"`), a `"content-state"` matching the activity's content state (here the `{ "data": { ... } }` shape of `MosaicActivityAttributes.ContentState`), and a `"timestamp"`. An `"alert"` is optional for a Lock Screen / Dynamic Island banner.
3. Authenticate to APNs with your key/certificate exactly as for normal push.

The token can change; always use the latest value delivered on `onPushToken`. See Apple's "Updating and ending your Live Activity with ActivityKit push notifications" for the exact payload schema.

### Android

Android has **no push-token equivalent**. The Android "live activity" is an ongoing notification updated **locally only** via `MosaicLiveActivities.update(...)` from the app process; there is no remote/APNs path and `onPushToken` never emits on Android. `push: true` is simply ignored there.

### ActivityKit constraints

- `pushType: .token` and `activity.pushTokenUpdates` are iOS 16.1+ (the whole controller is gated `@available(iOS 16.1, *)`).
- The token is observed for the activity's lifetime because ActivityKit may rotate it; each new token re-emits on `onPushToken`.
- The host `Info.plist` still needs `NSSupportsLiveActivities = true`; remote pushes additionally require your APNs configuration (push capability + key/cert) on the **main app** target.

---

## Limitations

- **Per-activity typed content states** are not generated; all state is a generic `Map<String,String>`.
- The Android ongoing notification is **not** a true Live Activity equivalent, and there is no Dynamic Island emulation.
