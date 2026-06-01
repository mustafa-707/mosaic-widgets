# Mosaic Sub-project B — Live Activities + Dynamic Island

**Date:** 2026-06-01
**Status:** Approved direction (iOS-first, Android best-effort), design self-authored under "do all now".
**Depends on:** Mosaic core (DSL → IR → native generators, node→SwiftUI / node→RemoteViews handlers, runtime bind resolution via a `bindSource` token).

## Summary

Add a Live Activity subsystem: a `MosaicLiveActivity` DSL describing a lock-screen/banner
presentation plus Dynamic Island regions, a Flutter lifecycle API (start/update/end + alerts),
and generators that emit iOS ActivityKit code (full) and an Android ongoing-notification
fallback (best-effort). Dynamic Island is iOS-only (documented N/A on Android).

## Key architectural choice — generic string content state

ActivityKit requires an `ActivityAttributes` with a `ContentState`. Rather than generating a
typed struct per activity, Mosaic uses ONE generic attributes type whose content state carries a
`[String: String] data` map (and an `activityType: String`). This mirrors the existing widget
data-binding model: `MBind('key')` inside a live activity resolves against `context.state.data["key"]`
via the generators' existing `bindSource` mechanism. The Flutter app pushes/updates a `Map<String,String>`.
Numbers/dates are stringified (with `MFormat` handling locale formatting at render, as in Sub-project A).

## DSL

```dart
class MosaicLiveActivity {
  final String name;
  final MNode lockScreen;              // banner / lock-screen presentation
  final MDynamicIsland dynamicIsland;  // iOS 16.1+ Dynamic Island
}

class MDynamicIsland {
  final MNode compactLeading;
  final MNode compactTrailing;
  final MNode minimal;
  final MExpanded expanded;            // expanded (long-press) regions
}

class MExpanded {
  final MNode? leading;
  final MNode? trailing;
  final MNode? center;
  final MNode? bottom;
}
```
Binds in any of these trees resolve against the activity content-state data map. `toJson` produces
an IR with `__type` tags (e.g. `HWLiveActivity`, `HWDynamicIsland`, `HWExpanded`) consistent with the
stable internal-wire convention. Config: live activities are declared in `mosaic.yaml` under a new
`live_activities:` list (name + entry), parsed like widgets.

## Flutter lifecycle API (`MosaicLiveActivities`)

```dart
Future<String?> start(String activityType, Map<String,String> initialState);
Future<void> update(String id, Map<String,String> state, {MActivityAlert? alert});
Future<void> end(String id, {Map<String,String>? finalState, MEndPolicy policy});
Future<bool> areEnabled();
Future<List<String>> active();
```
`MActivityAlert { title, body }`. New method-channel methods on the existing `mosaic_bridge`
channel: `startActivity/updateActivity/endActivity/activitiesEnabled/activeActivities`.

## iOS generation (full, iOS 16.1+)

- Generate `MosaicActivityAttributes.swift` (shared): `struct MosaicActivityAttributes: ActivityAttributes { public struct ContentState: Codable, Hashable { var data: [String:String] }; var activityType: String }`. Sentinel first line, `@available(iOS 16.1, *)` where needed.
- Per live activity, generate a `<Name>LiveActivity.swift` with an `ActivityConfiguration(for: MosaicActivityAttributes.self)` whose:
  - lock-screen view = node→SwiftUI of `lockScreen` with `bindSource = context.state.data`.
  - `DynamicIsland { expanded { ... regions ... } compactLeading: ... compactTrailing: ... minimal: ... }` from the DI trees.
- Register all live activities in the existing WidgetBundle (gated `if #available(iOS 16.1, *)`).
- Generate ActivityKit method-channel handlers (in a generated helper the AppDelegate template calls): `Activity<MosaicActivityAttributes>.request(...)` for start, lookup by id + `activity.update(using:alert:)` for update, `activity.end(...)` for end; map `MEndPolicy` → `ActivityUIDismissalPolicy`. `Info.plist` requires `NSSupportsLiveActivities=true` (doctor check + docs).

## Android generation (best-effort)

- Map a live activity to an **ongoing notification** with custom `RemoteViews` built from the `lockScreen` tree (reuse the RemoteViews node handlers, sharing the data store). Dynamic Island regions are ignored (documented N/A).
- Generated `MosaicLiveActivityManager.kt`: `start(type, data) -> id` posts an ongoing notification (a generated channel), `update(id, data, alert)` rebuilds RemoteViews + re-notifies (alert → heads-up), `end(id)` cancels. Needs `POST_NOTIFICATIONS` (API 33+) — documented; the app requests the runtime permission.
- The bind data is passed in the notification update path (not SharedPreferences) so updates are immediate.

## Testing

Golden tests:
- iOS: `<Name>LiveActivity.swift` contains `ActivityConfiguration(for: MosaicActivityAttributes.self)`, a `DynamicIsland {`, the four compact/minimal/expanded regions, and `context.state.data[` bind resolution; bundle registers it under an iOS-16.1 gate.
- Android: notification manager Kotlin builds RemoteViews from the lockScreen tree and exposes start/update/end.
- DSL: `MosaicLiveActivity`/`MDynamicIsland`/`MExpanded` toJson shapes; bridge method argument shapes.
Native gate: `swiftc -typecheck` of the generated live-activity Swift against the iOS SDK (ActivityKit + WidgetKit are in the SDK); demo APK build with a sample live activity.

## Demo

Add one live activity (e.g. a delivery/timer-style "OrderTracker") to the demo: lock-screen layout + Dynamic Island compact/expanded, wired in `main.dart` with start/update/end buttons, and `NSSupportsLiveActivities` in the demo Info.plist.

## Non-Goals (B)
Push-token (APNs) updates of Live Activities (document as a future pass), per-activity typed content-state schemas, Android Dynamic-Island emulation.

## Risks
- ActivityKit APIs are iOS 16.1+ and must be availability-gated to keep the extension compiling for lower targets.
- Live Activity views have strict size/energy budgets; the node reduction for Dynamic Island regions is opinionated (document it).
- Android ongoing-notification "live" updates are not a true equivalent; set expectations in docs.
- AppDelegate template must call the generated ActivityKit handlers — the demo AppDelegate becomes the reference.
