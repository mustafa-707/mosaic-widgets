// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MosaicConfig _$MosaicConfigFromJson(Map<String, dynamic> json) => MosaicConfig(
      app: MosaicAppConfig.fromJson(json['app'] as Map<String, dynamic>),
      widgets: (json['widgets'] as List<dynamic>)
          .map((e) => MosaicWidgetConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      liveActivities: (json['live_activities'] as List<dynamic>?)
              ?.map((e) =>
                  MosaicLiveActivityConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MosaicConfigToJson(MosaicConfig instance) =>
    <String, dynamic>{
      'app': instance.app,
      'widgets': instance.widgets,
      'live_activities': instance.liveActivities,
    };

MosaicAppConfig _$MosaicAppConfigFromJson(Map<String, dynamic> json) =>
    MosaicAppConfig(
      bundleId: json['bundle_id'] as String,
      androidPackage: json['android_package'] as String,
      iosAppGroup: json['ios_app_group'] as String,
      deepLinkScheme: json['deep_link_scheme'] as String? ?? 'mosaic',
    );

Map<String, dynamic> _$MosaicAppConfigToJson(MosaicAppConfig instance) =>
    <String, dynamic>{
      'bundle_id': instance.bundleId,
      'android_package': instance.androidPackage,
      'ios_app_group': instance.iosAppGroup,
      'deep_link_scheme': instance.deepLinkScheme,
    };

MosaicWidgetConfig _$MosaicWidgetConfigFromJson(Map<String, dynamic> json) =>
    MosaicWidgetConfig(
      name: json['name'] as String,
      entry: json['entry'] as String,
      android: MosaicAndroidWidgetConfig.fromJson(
          json['android'] as Map<String, dynamic>),
      ios: MosaicIosWidgetConfig.fromJson(json['ios'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MosaicWidgetConfigToJson(MosaicWidgetConfig instance) =>
    <String, dynamic>{
      'name': instance.name,
      'entry': instance.entry,
      'android': instance.android,
      'ios': instance.ios,
    };

MosaicLiveActivityConfig _$MosaicLiveActivityConfigFromJson(
        Map<String, dynamic> json) =>
    MosaicLiveActivityConfig(
      name: json['name'] as String,
      entry: json['entry'] as String,
    );

Map<String, dynamic> _$MosaicLiveActivityConfigToJson(
        MosaicLiveActivityConfig instance) =>
    <String, dynamic>{
      'name': instance.name,
      'entry': instance.entry,
    };

MosaicAndroidWidgetConfig _$MosaicAndroidWidgetConfigFromJson(
        Map<String, dynamic> json) =>
    MosaicAndroidWidgetConfig(
      minSdk: (json['min_sdk'] as num).toInt(),
      sizes: (json['sizes'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$MosaicAndroidWidgetConfigToJson(
        MosaicAndroidWidgetConfig instance) =>
    <String, dynamic>{
      'min_sdk': instance.minSdk,
      'sizes': instance.sizes,
    };

MosaicIosWidgetConfig _$MosaicIosWidgetConfigFromJson(
        Map<String, dynamic> json) =>
    MosaicIosWidgetConfig(
      families:
          (json['families'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$MosaicIosWidgetConfigToJson(
        MosaicIosWidgetConfig instance) =>
    <String, dynamic>{
      'families': instance.families,
    };
