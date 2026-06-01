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

  /// Creates a [MosaicConfig] with the given [app] settings, [widgets], and
  /// optional [liveActivities].
  MosaicConfig({
    required this.app,
    required this.widgets,
    this.liveActivities = const [],
  });

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

  /// Android-specific configuration for this widget.
  final MosaicAndroidWidgetConfig android;

  /// iOS-specific configuration for this widget.
  final MosaicIosWidgetConfig ios;

  /// Creates a [MosaicWidgetConfig].
  MosaicWidgetConfig({
    required this.name,
    required this.entry,
    required this.android,
    required this.ios,
  });

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

  /// Creates a [MosaicLiveActivityConfig].
  MosaicLiveActivityConfig({required this.name, required this.entry});

  /// Deserializes a [MosaicLiveActivityConfig] from a JSON map.
  factory MosaicLiveActivityConfig.fromJson(Map<String, dynamic> j) =>
      _$MosaicLiveActivityConfigFromJson(j);

  /// Serializes this config to a JSON map.
  Map<String, dynamic> toJson() => _$MosaicLiveActivityConfigToJson(this);
}

/// Android-specific configuration for a Mosaic home-screen widget.
@JsonSerializable()
class MosaicAndroidWidgetConfig {
  /// The minimum Android SDK version required by this widget
  /// (maps to the `min_sdk` YAML key).
  @JsonKey(name: 'min_sdk')
  final int minSdk;

  /// The supported widget sizes as strings (e.g. `['1x1', '2x2']`).
  final List<String> sizes;

  /// Creates a [MosaicAndroidWidgetConfig].
  MosaicAndroidWidgetConfig({required this.minSdk, required this.sizes});

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

  /// Deserializes a [MosaicIosWidgetConfig] from a JSON map.
  factory MosaicIosWidgetConfig.fromJson(Map<String, dynamic> json) =>
      _$MosaicIosWidgetConfigFromJson(json);

  /// Serializes this config to a JSON map.
  Map<String, dynamic> toJson() => _$MosaicIosWidgetConfigToJson(this);
}
