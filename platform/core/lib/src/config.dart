import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

part 'config.g.dart';

@JsonSerializable()
class HWConfig {
  final HWAppConfig app;
  final List<HWWidgetConfig> widgets;

  HWConfig({required this.app, required this.widgets});

  factory HWConfig.fromYaml(String yamlString) {
    final yaml = loadYaml(yamlString) as YamlMap;
    return HWConfig.fromJson(_yamlToMap(yaml));
  }

  factory HWConfig.fromJson(Map<String, dynamic> json) =>
      _$HWConfigFromJson(json);
  Map<String, dynamic> toJson() => _$HWConfigToJson(this);

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
class HWAppConfig {
  @JsonKey(name: 'bundle_id')
  final String bundleId;
  @JsonKey(name: 'android_package')
  final String androidPackage;
  @JsonKey(name: 'ios_app_group')
  final String iosAppGroup;

  HWAppConfig({
    required this.bundleId,
    required this.androidPackage,
    required this.iosAppGroup,
  });

  factory HWAppConfig.fromJson(Map<String, dynamic> json) =>
      _$HWAppConfigFromJson(json);
  Map<String, dynamic> toJson() => _$HWAppConfigToJson(this);
}

@JsonSerializable()
class HWWidgetConfig {
  final String name;
  final String entry;
  final HWAndroidWidgetConfig android;
  final HWIosWidgetConfig ios;

  HWWidgetConfig({
    required this.name,
    required this.entry,
    required this.android,
    required this.ios,
  });

  factory HWWidgetConfig.fromJson(Map<String, dynamic> json) =>
      _$HWWidgetConfigFromJson(json);
  Map<String, dynamic> toJson() => _$HWWidgetConfigToJson(this);
}

@JsonSerializable()
class HWAndroidWidgetConfig {
  @JsonKey(name: 'min_sdk')
  final int minSdk;
  final List<String> sizes;

  HWAndroidWidgetConfig({required this.minSdk, required this.sizes});

  factory HWAndroidWidgetConfig.fromJson(Map<String, dynamic> json) =>
      _$HWAndroidWidgetConfigFromJson(json);
  Map<String, dynamic> toJson() => _$HWAndroidWidgetConfigToJson(this);
}

@JsonSerializable()
class HWIosWidgetConfig {
  final List<String> families;

  HWIosWidgetConfig({required this.families});

  factory HWIosWidgetConfig.fromJson(Map<String, dynamic> json) =>
      _$HWIosWidgetConfigFromJson(json);
  Map<String, dynamic> toJson() => _$HWIosWidgetConfigToJson(this);
}
