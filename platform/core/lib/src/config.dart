import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

part 'config.g.dart';

@JsonSerializable()
class MosaicConfig {
  final MosaicAppConfig app;
  final List<MosaicWidgetConfig> widgets;
  @JsonKey(name: 'live_activities', defaultValue: <MosaicLiveActivityConfig>[])
  final List<MosaicLiveActivityConfig> liveActivities;

  MosaicConfig({
    required this.app,
    required this.widgets,
    this.liveActivities = const [],
  });

  factory MosaicConfig.fromYaml(String yamlString) {
    final yaml = loadYaml(yamlString) as YamlMap;
    return MosaicConfig.fromJson(_yamlToMap(yaml));
  }

  factory MosaicConfig.fromJson(Map<String, dynamic> json) =>
      _$MosaicConfigFromJson(json);
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

@JsonSerializable()
class MosaicAppConfig {
  @JsonKey(name: 'bundle_id')
  final String bundleId;
  @JsonKey(name: 'android_package')
  final String androidPackage;
  @JsonKey(name: 'ios_app_group')
  final String iosAppGroup;
  @JsonKey(name: 'deep_link_scheme', defaultValue: 'mosaic')
  final String deepLinkScheme;

  MosaicAppConfig({
    required this.bundleId,
    required this.androidPackage,
    required this.iosAppGroup,
    this.deepLinkScheme = 'mosaic',
  });

  factory MosaicAppConfig.fromJson(Map<String, dynamic> json) =>
      _$MosaicAppConfigFromJson(json);
  Map<String, dynamic> toJson() => _$MosaicAppConfigToJson(this);
}

@JsonSerializable()
class MosaicWidgetConfig {
  final String name;
  final String entry;
  final MosaicAndroidWidgetConfig android;
  final MosaicIosWidgetConfig ios;

  MosaicWidgetConfig({
    required this.name,
    required this.entry,
    required this.android,
    required this.ios,
  });

  factory MosaicWidgetConfig.fromJson(Map<String, dynamic> json) =>
      _$MosaicWidgetConfigFromJson(json);
  Map<String, dynamic> toJson() => _$MosaicWidgetConfigToJson(this);
}

@JsonSerializable()
class MosaicLiveActivityConfig {
  final String name;
  final String entry;

  MosaicLiveActivityConfig({required this.name, required this.entry});

  factory MosaicLiveActivityConfig.fromJson(Map<String, dynamic> j) =>
      _$MosaicLiveActivityConfigFromJson(j);
  Map<String, dynamic> toJson() => _$MosaicLiveActivityConfigToJson(this);
}

@JsonSerializable()
class MosaicAndroidWidgetConfig {
  @JsonKey(name: 'min_sdk')
  final int minSdk;
  final List<String> sizes;

  MosaicAndroidWidgetConfig({required this.minSdk, required this.sizes});

  factory MosaicAndroidWidgetConfig.fromJson(Map<String, dynamic> json) =>
      _$MosaicAndroidWidgetConfigFromJson(json);
  Map<String, dynamic> toJson() => _$MosaicAndroidWidgetConfigToJson(this);
}

@JsonSerializable()
class MosaicIosWidgetConfig {
  final List<String> families;

  MosaicIosWidgetConfig({required this.families});

  factory MosaicIosWidgetConfig.fromJson(Map<String, dynamic> json) =>
      _$MosaicIosWidgetConfigFromJson(json);
  Map<String, dynamic> toJson() => _$MosaicIosWidgetConfigToJson(this);
}
