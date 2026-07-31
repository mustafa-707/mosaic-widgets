// Control Center / Lock Screen controls (iOS 18+) and their AppIntents.
part of '../mosaic_ios.dart';

extension IosControlEmitters on IosGenerator {
  Future<void> generateControls(String projectRoot) async {
    if (controls.isEmpty) return;

    final iosDir = Directory(p.join(projectRoot, 'ios', 'HomeWidgetExtension'));
    if (!iosDir.existsSync()) iosDir.createSync(recursive: true);

    for (final c in controls) {
      final name = c['name'] as String;
      final file = File(p.join(iosDir.path, '${name}Control.swift'));
      await file.writeAsString(_generateControl(c));
    }

    final intentsFile =
        File(p.join(iosDir.path, 'MosaicControlIntents.swift'));
    await intentsFile.writeAsString(_generateControlIntents());
  }

  /// The `SetValueIntent` struct name for a toggle control of the given [name].
  String _controlIntentName(String name) => '${name}SetValueIntent';

  /// Emits a single `<Name>Control.swift` `ControlWidget`. Toggles use
  /// `ControlWidgetToggle` whose current `isOn` value is supplied by a
  /// `ControlValueProvider` reading the App Group bool at `valueKey`; the toggle
  /// dispatches the generated `SetValueIntent`. Buttons use
  /// `ControlWidgetButton` dispatching the shared `MosaicCallbackIntent`.
  String _generateControl(Map<String, dynamic> c) {
    final name = c['name'] as String;
    final kind = c['kind'] as String;
    final label = swiftEscape(c['label'] as String);
    final sfSymbol = swiftEscape((c['sfSymbol'] as String?) ?? '');

    if (kind == 'toggle') {
      // valueKey is optional in the DSL, so a hard cast crashed generation
      // with "type 'Null' is not a subtype of type 'String'". `validateControls`
      // reports the real problem; this keeps the generator from dying first.
      final valueKey =
          swiftEscape((c['valueKey'] as String?) ?? '${name}_on');
      final intentName = _controlIntentName(name);
      // StaticControlConfiguration with a ControlValueProvider supplying the
      // current bool. ControlWidgetToggle(_:isOn:action:) takes the value, the
      // intent (a SetValueIntent — its `value` is bound to the new state), and a
      // ValueLabel builder.
      return '''$kGeneratedSentinel
import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct ${name}Control: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "${config.app.iosAppGroup}.$name",
            provider: ${name}ValueProvider()
        ) { value in
            ControlWidgetToggle(
                "$label",
                isOn: value,
                action: $intentName()
            ) { isOn in
                Label("$label", systemImage: "$sfSymbol")
            }
        }
        .displayName("$label")
    }
}

/// Supplies the current toggle state by reading the App Group bool at the
/// control's `valueKey`. `ControlValueProvider` is iOS 18.0+.
@available(iOS 18.0, *)
struct ${name}ValueProvider: ControlValueProvider {
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool {
        UserDefaults(suiteName: kMosaicAppGroup)?.bool(forKey: "$valueKey") ?? false
    }
}
''';
    }

    // button: a ControlWidgetButton dispatching the shared callback intent.
    final action = c['action'] as Map<String, dynamic>?;
    String intentExpr;
    if (action != null && action['__type'] == 'HWLaunchUrlAction') {
      // Launch the host app via an OpenURLIntent (iOS 18 Control buttons accept
      // an OpenIntent-style AppIntent). MLaunchUrlAction maps to OpenURLIntent.
      final url = swiftEscape(action['url'] as String);
      intentExpr = 'OpenURLIntent(URL(string: "$url")!)';
    } else if (action != null && action['__type'] == 'HWActionCallback') {
      final callbackName = swiftEscape(action['callbackName'] as String);
      intentExpr = 'MosaicCallbackIntent(callbackName: "$callbackName")';
    } else {
      intentExpr = 'MosaicRefreshIntent()';
    }

    return '''$kGeneratedSentinel
import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct ${name}Control: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "${config.app.iosAppGroup}.$name"
        ) {
            ControlWidgetButton(action: $intentExpr) {
                Label("$label", systemImage: "$sfSymbol")
            }
        }
        .displayName("$label")
    }
}
''';
  }

  /// Emits `MosaicControlIntents.swift`: one `SetValueIntent`-conforming intent
  /// per toggle control. `perform()` writes the new bool into the App Group
  /// under the control's `valueKey`, records the callback into
  /// `mosaic_pending_callback` (mirroring `MosaicCallbackIntent`) so the host
  /// app can fire the Dart `backgroundCallback` on resume, then reloads the
  /// control of this kind so Control Center re-renders.
  ///
  /// `SetValueIntent` and `ControlCenter.shared.reloadControls(ofKind:)` are
  /// iOS 18.0+, so every intent is `@available(iOS 18.0, *)`.
  String _generateControlIntents() {
    final structs = <String>[];
    for (final c in controls) {
      if (c['kind'] != 'toggle') continue;
      final name = c['name'] as String;
      final intentName = _controlIntentName(name);
      final label = swiftEscape(c['label'] as String);
      // valueKey is optional in the DSL, so a hard cast crashed generation
      // with "type 'Null' is not a subtype of type 'String'". `validateControls`
      // reports the real problem; this keeps the generator from dying first.
      final valueKey =
          swiftEscape((c['valueKey'] as String?) ?? '${name}_on');
      final action = c['action'] as Map<String, dynamic>?;
      final callbackName =
          (action != null && action['__type'] == 'HWActionCallback')
              ? swiftEscape(action['callbackName'] as String)
              : '';
      final kind = '${config.app.iosAppGroup}.$name';

      final callbackBlock = callbackName.isEmpty
          ? ''
          : '''
            let payload: [String: Any] = [
                "callback": "$callbackName",
                "timestamp": Date().timeIntervalSince1970,
            ]
            defaults.set(payload, forKey: "mosaic_pending_callback")
''';

      structs.add('''
@available(iOS 18.0, *)
struct $intentName: SetValueIntent {
    static let title: LocalizedStringResource = "$label"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Value")
    var value: Bool

    init() {}

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: kMosaicAppGroup) {
            defaults.set(value, forKey: "$valueKey")
$callbackBlock        }
        ControlCenter.shared.reloadControls(ofKind: "$kind")
        return .result()
    }
}''');
    }

    return '''$kGeneratedSentinel
import AppIntents
import WidgetKit
import Foundation

// iOS 18 Control Widget toggles dispatch these SetValueIntents from
// ControlWidgetToggle(action:). They run inside the widget extension process
// and CANNOT call the Flutter engine, so (like MosaicCallbackIntent) they
// record the request into the App Group (`mosaic_pending_callback`); the host
// app must read & clear that key on resume to fire the Dart backgroundCallback.

${structs.join('\n\n')}
''';
  }

  /// Emits the ActivityKit Live Activity sources for every entry in
  /// [liveActivities]. Produces:
  ///  - a single shared `MosaicActivityAttributes.swift` (the
  ///    [ActivityAttributes] type whose `ContentState.data` carries the bound
  ///    string values), and
  ///  - one `<Name>LiveActivity.swift` per activity wrapping an
  ///    `ActivityConfiguration` + `DynamicIsland`.
  ///
  /// Availability: every emitted type is gated on `@available(iOS 16.1, *)`
  /// because ActivityKit's `ActivityConfiguration`/`DynamicIsland`/`Widget`
  /// `body: some WidgetConfiguration` Live Activity APIs are iOS 16.1+. Nothing
  /// is written when there are no live activities.
}
