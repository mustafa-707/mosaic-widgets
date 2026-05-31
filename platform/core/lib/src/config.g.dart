// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HWConfig _$HWConfigFromJson(Map<String, dynamic> json) => HWConfig(
  app: HWAppConfig.fromJson(json['app'] as Map<String, dynamic>),
  widgets: (json['widgets'] as List<dynamic>)
      .map((e) => HWWidgetConfig.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$HWConfigToJson(HWConfig instance) => <String, dynamic>{
  'app': instance.app,
  'widgets': instance.widgets,
};

HWAppConfig _$HWAppConfigFromJson(Map<String, dynamic> json) => HWAppConfig(
  bundleId: json['bundle_id'] as String,
  androidPackage: json['android_package'] as String,
  iosAppGroup: json['ios_app_group'] as String,
  deepLinkScheme: json['deep_link_scheme'] as String? ?? 'mosaic',
);

Map<String, dynamic> _$HWAppConfigToJson(HWAppConfig instance) =>
    <String, dynamic>{
      'bundle_id': instance.bundleId,
      'android_package': instance.androidPackage,
      'ios_app_group': instance.iosAppGroup,
      'deep_link_scheme': instance.deepLinkScheme,
    };

HWWidgetConfig _$HWWidgetConfigFromJson(Map<String, dynamic> json) =>
    HWWidgetConfig(
      name: json['name'] as String,
      entry: json['entry'] as String,
      android: HWAndroidWidgetConfig.fromJson(
        json['android'] as Map<String, dynamic>,
      ),
      ios: HWIosWidgetConfig.fromJson(json['ios'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$HWWidgetConfigToJson(HWWidgetConfig instance) =>
    <String, dynamic>{
      'name': instance.name,
      'entry': instance.entry,
      'android': instance.android,
      'ios': instance.ios,
    };

HWAndroidWidgetConfig _$HWAndroidWidgetConfigFromJson(
  Map<String, dynamic> json,
) => HWAndroidWidgetConfig(
  minSdk: (json['min_sdk'] as num).toInt(),
  sizes: (json['sizes'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$HWAndroidWidgetConfigToJson(
  HWAndroidWidgetConfig instance,
) => <String, dynamic>{'min_sdk': instance.minSdk, 'sizes': instance.sizes};

HWIosWidgetConfig _$HWIosWidgetConfigFromJson(Map<String, dynamic> json) =>
    HWIosWidgetConfig(
      families: (json['families'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$HWIosWidgetConfigToJson(HWIosWidgetConfig instance) =>
    <String, dynamic>{'families': instance.families};
