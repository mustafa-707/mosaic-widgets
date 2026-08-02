import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

part 'config.g.dart';

/// Top-level configuration for a Mosaic project, typically loaded from
/// `mosaic.yaml`.
///
/// Holds the shared [app] settings, the list of home-screen [widgets], and
/// the optional [liveActivities] list.
@JsonSerializable()
class MosaicConfig {
  /// Application-level settings shared by all widgets and live activities.
  final MosaicAppConfig app;

  /// Home-screen widget definitions declared in this project.
  final List<MosaicWidgetConfig> widgets;

  /// Live-activity definitions declared in this project.
  ///
  /// Maps to the `live_activities` key in YAML/JSON. Defaults to an empty
  /// list when the key is absent.
  @JsonKey(name: 'live_activities', defaultValue: <MosaicLiveActivityConfig>[])
  final List<MosaicLiveActivityConfig> liveActivities;

  /// Control definitions declared in this project.
  ///
  /// Maps to the `controls` key in YAML/JSON. Each entry declares a Control
  /// Center / Lock Screen control (iOS 18+) or Quick Settings tile (Android).
  /// Defaults to an empty list when the key is absent.
  @JsonKey(name: 'controls', defaultValue: <MosaicControlConfig>[])
  final List<MosaicControlConfig> controls;

  /// Android TV home-screen channels, declared under `tv_channels:`.
  ///
  /// Not widgets. The Android TV and Google TV launchers host **no AppWidgets
  /// at all** — a RemoteViews widget simply never appears there. What the TV
  /// home screen does show is *channels* of preview programs, published through
  /// `TvProvider`, and the launcher draws those cards itself. So a DSL tree has
  /// nothing to render on TV; what a channel needs is content.
  @JsonKey(name: 'tv_channels', defaultValue: <MosaicTvChannelConfig>[])
  final List<MosaicTvChannelConfig> tvChannels;

  /// Network sources a widget's refresh button may fetch directly, keyed by
  /// callback name (the `MActionCallback` / `MRefreshAction` name).
  ///
  /// Widget-extension AppIntents cannot run Dart, so without a source here a
  /// refresh button can only re-render already-stored data and defer the real
  /// work to the host app's next foreground. Declaring a source lets the
  /// generated intent fetch and store the data itself, so the button works
  /// while the app is closed. Defaults to an empty map when absent.
  /// A callback may declare a single source or a list of them — a list lets one
  /// button fetch several endpoints (e.g. the same reading in two units, or a
  /// "refresh everything" button).
  @JsonKey(name: 'refresh', fromJson: _refreshFromJson, toJson: _refreshToJson)
  final Map<String, List<MosaicRefreshSourceConfig>> refresh;

  /// Widget text by locale, keyed `locale → (key → value)`.
  ///
  /// A widget renders outside the Flutter engine, so Dart's localization stack
  /// is unavailable to it. These become real platform string resources —
  /// `Localizable.strings` and `values-<locale>/` — which the OS selects using
  /// the device language.
  ///
  /// The first locale listed is the default, used when the device language has
  /// no entry.
  @JsonKey(name: 'strings', defaultValue: <String, Map<String, String>>{})
  final Map<String, Map<String, String>> strings;

  /// Creates a [MosaicConfig] with the given [app] settings, [widgets], and
  /// optional [liveActivities], [controls], and [refresh] sources.
  MosaicConfig({
    required this.app,
    required this.widgets,
    this.liveActivities = const [],
    this.controls = const [],
    this.tvChannels = const [],
    this.refresh = const {},
    this.strings = const {},
  });

  /// The default locale for widget text — the first entry under `strings:`.
  String? get defaultLocale => strings.keys.isEmpty ? null : strings.keys.first;

  /// Every localization key declared, across all locales.
  Set<String> get stringKeys =>
      {for (final table in strings.values) ...table.keys};

  /// All refresh sources declared for [callback], in declaration order.
  List<MosaicRefreshSourceConfig> sourcesFor(String callback) =>
      refresh[callback] ?? const [];

  /// Parses a [MosaicConfig] from a YAML string (e.g. the contents of
  /// `mosaic.yaml`).
  factory MosaicConfig.fromYaml(String yamlString) {
    final yaml = loadYaml(yamlString) as YamlMap;
    return MosaicConfig.fromJson(_yamlToMap(yaml));
  }

  /// Deserializes a [MosaicConfig] from a JSON map.
  factory MosaicConfig.fromJson(Map<String, dynamic> json) =>
      _$MosaicConfigFromJson(json);

  /// Serializes this config to a JSON map.
  Map<String, dynamic> toJson() => _$MosaicConfigToJson(this);

  static Map<String, dynamic> _yamlToMap(YamlMap yaml) {
    final map = <String, dynamic>{};
    for (final entry in yaml.entries) {
      final key = entry.key as String;
      final value = entry.value;
      if (value is YamlMap) {
        map[key] = _yamlToMap(value);
      } else if (value is YamlList) {
        map[key] = value.map((e) => e is YamlMap ? _yamlToMap(e) : e).toList();
      } else {
        map[key] = value;
      }
    }
    return map;
  }
}

/// Application-level identifiers shared by all Mosaic widgets and live
/// activities within a project.
@JsonSerializable()
class MosaicAppConfig {
  /// The iOS/macOS bundle identifier of the host app (e.g. `com.example.app`).
  @JsonKey(name: 'bundle_id')
  final String bundleId;

  /// The Android application package name (e.g. `com.example.app`).
  @JsonKey(name: 'android_package')
  final String androidPackage;

  /// The App Group identifier used to share data between the iOS host app and
  /// its widget/live-activity extensions (e.g. `group.com.example.app`).
  @JsonKey(name: 'ios_app_group')
  final String iosAppGroup;

  /// The custom URL scheme used for deep-linking into the app from a widget.
  ///
  /// Defaults to `'mosaic'` when not specified in the config file.
  @JsonKey(name: 'deep_link_scheme', defaultValue: 'mosaic')
  final String deepLinkScheme;

  /// Creates a [MosaicAppConfig].
  MosaicAppConfig({
    required this.bundleId,
    required this.androidPackage,
    required this.iosAppGroup,
    this.deepLinkScheme = 'mosaic',
  });

  /// Deserializes a [MosaicAppConfig] from a JSON map.
  factory MosaicAppConfig.fromJson(Map<String, dynamic> json) =>
      _$MosaicAppConfigFromJson(json);

  /// Serializes this config to a JSON map.
  Map<String, dynamic> toJson() => _$MosaicAppConfigToJson(this);
}

/// Configuration for a single Mosaic home-screen widget.
@JsonSerializable()
class MosaicWidgetConfig {
  /// The widget's logical name, used to derive the builder function name
  /// (`build<Name>`) and to identify the widget in generated code.
  final String name;

  /// Path to the Dart entry file that exports the builder function for this
  /// widget. May be absolute or relative to the project root.
  final String entry;

  /// Opts this widget into WidgetKit push updates (iOS 26+).
  ///
  /// The extension receives an APNs token and forwards it to the app, which
  /// registers it with your server; the server then pushes
  /// `{"aps":{"content-changed":true}}` to reload the timeline with the app
  /// closed. Off by default — it only earns its keep when a server actually
  /// drives the data.
  @JsonKey(name: 'push', defaultValue: false)
  final bool push;

  /// The title shown in the OS widget picker. Defaults to [name].
  ///
  /// Without it Android falls back to the application label and icon, which is
  /// why an unconfigured Flutter project lists every widget under the Flutter
  /// logo.
  final String? label;

  /// One-line explanation shown under the title in the widget picker
  /// (Android 12+ / iOS widget gallery).
  final String? description;

  /// Android-specific configuration for this widget.
  ///
  /// Optional: every field it carries is reserved, so omitting the whole
  /// `android:` block changes nothing about the generated output.
  @JsonKey(name: 'android', defaultValue: null)
  final MosaicAndroidWidgetConfig? androidOrNull;

  /// iOS-specific configuration for this widget. Optional; defaults to
  /// [MosaicIosWidgetConfig.defaults] when the `ios:` block is omitted.
  @JsonKey(name: 'ios', defaultValue: null)
  final MosaicIosWidgetConfig? iosOrNull;

  /// Android configuration, or the defaults when none was declared.
  MosaicAndroidWidgetConfig get android =>
      androidOrNull ?? MosaicAndroidWidgetConfig();

  /// iOS configuration, or the defaults when none was declared.
  MosaicIosWidgetConfig get ios =>
      iosOrNull ?? MosaicIosWidgetConfig.defaults();

  /// Creates a [MosaicWidgetConfig].
  MosaicWidgetConfig({
    required this.name,
    required this.entry,
    MosaicAndroidWidgetConfig? android,
    MosaicIosWidgetConfig? ios,
    this.label,
    this.description,
    this.push = false,
  })  : androidOrNull = android,
        iosOrNull = ios;

  /// The picker title: [label] when given, otherwise [name].
  String get displayName => label ?? name;

  /// Deserializes a [MosaicWidgetConfig] from a JSON map.
  factory MosaicWidgetConfig.fromJson(Map<String, dynamic> json) =>
      _$MosaicWidgetConfigFromJson(json);

  /// Serializes this config to a JSON map.
  Map<String, dynamic> toJson() => _$MosaicWidgetConfigToJson(this);
}

/// Configuration for a single Mosaic Live Activity.
///
/// Live Activities appear on the iOS Lock Screen and Dynamic Island and are
/// declared under the `live_activities` key in `mosaic.yaml`.
@JsonSerializable()
class MosaicLiveActivityConfig {
  /// The live activity's logical name, used to derive the builder function name
  /// (`build<Name>`) and to identify it in generated code.
  final String name;

  /// Path to the Dart entry file that exports the builder function for this
  /// live activity. May be absolute or relative to the project root.
  final String entry;

  /// Whether this activity should also appear on a paired Apple Watch's
  /// Smart Stack (and in CarPlay), via `supplementalActivityFamilies`.
  ///
  /// Off by default because the API is iOS 18+, while Live Activities
  /// themselves work from 16.1. Turning it on raises *this activity's*
  /// minimum to iOS 18 — on 16.1–17 it is not registered at all. Nothing else
  /// in the project is affected.
  @JsonKey(name: 'watch', defaultValue: false)
  final bool watch;

  /// Creates a [MosaicLiveActivityConfig].
  MosaicLiveActivityConfig({
    required this.name,
    required this.entry,
    this.watch = false,
  });

  /// Deserializes a [MosaicLiveActivityConfig] from a JSON map.
  factory MosaicLiveActivityConfig.fromJson(Map<String, dynamic> j) =>
      _$MosaicLiveActivityConfigFromJson(j);

  /// Serializes this config to a JSON map.
  Map<String, dynamic> toJson() => _$MosaicLiveActivityConfigToJson(this);
}

/// An Android TV home-screen channel.
///
/// A channel is a row on the TV home screen; the app fills it with preview
/// programs at runtime via `MosaicTv.publish`. Declaring it here generates the
/// provider plumbing, the manifest permission and the install receiver that
/// creates the row.
@JsonSerializable(explicitToJson: true)
class MosaicTvChannelConfig {
  /// Identifies the channel in code and in `MosaicTv.publish`.
  final String name;

  /// The row title the user sees on the home screen.
  @JsonKey(name: 'display_name')
  final String displayName;

  /// Deep link opened when the user selects the channel itself. Optional.
  @JsonKey(name: 'app_link')
  final String? appLink;

  /// Creates a [MosaicTvChannelConfig].
  MosaicTvChannelConfig({
    required this.name,
    required this.displayName,
    this.appLink,
  });

  /// Deserializes from JSON.
  factory MosaicTvChannelConfig.fromJson(Map<String, dynamic> j) =>
      _$MosaicTvChannelConfigFromJson(j);

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => _$MosaicTvChannelConfigToJson(this);
}

/// Configuration for a single Mosaic Control.
///
/// Controls appear in iOS Control Center / Lock Screen / Action Button
/// (iOS 18+) and as Android Quick Settings tiles. They are declared under the
/// `controls` key in `mosaic.yaml`.
@JsonSerializable()
class MosaicControlConfig {
  /// The control's logical name, used to derive the builder function name
  /// (`build<Name>`) and to identify it in generated code.
  final String name;

  /// Path to the Dart entry file that exports the builder function for this
  /// control. May be absolute or relative to the project root.
  final String entry;

  /// Creates a [MosaicControlConfig].
  MosaicControlConfig({required this.name, required this.entry});

  /// Deserializes a [MosaicControlConfig] from a JSON map.
  factory MosaicControlConfig.fromJson(Map<String, dynamic> j) =>
      _$MosaicControlConfigFromJson(j);

  /// Serializes this config to a JSON map.
  Map<String, dynamic> toJson() => _$MosaicControlConfigToJson(this);
}

/// Normalizes `refresh:` entries, accepting either a single source map or a
/// list of them so both spellings are valid YAML.
Map<String, List<MosaicRefreshSourceConfig>> _refreshFromJson(Object? json) {
  if (json is! Map) return const {};
  return json.map((key, value) {
    final sources = value is List ? value : [value];
    return MapEntry(
      key as String,
      sources
          .whereType<Map>()
          .map((e) =>
              MosaicRefreshSourceConfig.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  });
}

Map<String, dynamic> _refreshToJson(
  Map<String, List<MosaicRefreshSourceConfig>> refresh,
) =>
    refresh.map(
        (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()));

/// A network source a refresh button fetches directly from the widget
/// extension, declared under the `refresh` key in `mosaic.yaml`.
///
/// The response is parsed as JSON and each entry in [map] stores one value in
/// the App Group under its key, where the widget's bindings already read it.
@JsonSerializable()
class MosaicRefreshSourceConfig {
  /// The absolute URL to fetch.
  final String url;

  /// The HTTP method. Defaults to `GET`.
  @JsonKey(defaultValue: 'GET')
  final String method;

  /// Extra HTTP headers to send. Defaults to none.
  @JsonKey(defaultValue: <String, String>{})
  final Map<String, String> headers;

  /// Maps an App Group key to a path into the JSON response.
  ///
  /// Paths are dot-separated with optional `[n]` array indices and an optional
  /// leading `$.`, e.g. `articles[0].title` or `$.current.temp_f`.
  final Map<String, String> map;

  /// Creates a [MosaicRefreshSourceConfig].
  MosaicRefreshSourceConfig({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    required this.map,
  });

  /// Deserializes a [MosaicRefreshSourceConfig] from a JSON map.
  factory MosaicRefreshSourceConfig.fromJson(Map<String, dynamic> j) =>
      _$MosaicRefreshSourceConfigFromJson(j);

  /// Serializes this config to a JSON map.
  Map<String, dynamic> toJson() => _$MosaicRefreshSourceConfigToJson(this);
}

/// Android-specific configuration for a Mosaic home-screen widget.
@JsonSerializable()
class MosaicAndroidWidgetConfig {
  /// Reserved: the minimum Android SDK this widget needs (`min_sdk` in YAML).
  ///
  /// Accepted for forward compatibility but **not currently applied** — the
  /// app module's own `minSdk` governs, and the generator emits no per-widget
  /// gate. Optional; omit it unless you are tracking the intent.
  @JsonKey(name: 'min_sdk')
  final int minSdk;

  /// Reserved: informational size labels.
  ///
  /// **Not used by the generator.** A widget's grid footprint comes from
  /// `MosaicDefinition(width:, height:)` in the DSL, and its resize behaviour
  /// from `resizeMode` — so this list has no effect on output. Optional.
  final List<String> sizes;

  /// Creates a [MosaicAndroidWidgetConfig].
  ///
  /// Both fields are optional: neither reaches the generated output, so
  /// requiring them only made every widget's config longer.
  MosaicAndroidWidgetConfig({this.minSdk = 21, this.sizes = const []});

  /// Deserializes a [MosaicAndroidWidgetConfig] from a JSON map.
  factory MosaicAndroidWidgetConfig.fromJson(Map<String, dynamic> json) =>
      _$MosaicAndroidWidgetConfigFromJson(json);

  /// Serializes this config to a JSON map.
  Map<String, dynamic> toJson() => _$MosaicAndroidWidgetConfigToJson(this);
}

/// iOS-specific configuration for a Mosaic home-screen widget.
@JsonSerializable()
class MosaicIosWidgetConfig {
  /// The WidgetKit families supported by this widget
  /// (e.g. `['systemSmall', 'systemMedium', 'systemLarge']`).
  final List<String> families;

  /// Creates a [MosaicIosWidgetConfig].
  MosaicIosWidgetConfig({required this.families});

  /// The families used when a widget declares no `ios:` block: the two
  /// home-screen sizes every widget can render at.
  factory MosaicIosWidgetConfig.defaults() =>
      MosaicIosWidgetConfig(families: const ['systemSmall', 'systemMedium']);

  /// Deserializes a [MosaicIosWidgetConfig] from a JSON map.
  factory MosaicIosWidgetConfig.fromJson(Map<String, dynamic> json) =>
      _$MosaicIosWidgetConfigFromJson(json);

  /// Serializes this config to a JSON map.
  Map<String, dynamic> toJson() => _$MosaicIosWidgetConfigToJson(this);
}
