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
      controls: (json['controls'] as List<dynamic>?)
              ?.map((e) =>
                  MosaicControlConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      refresh: json['refresh'] == null
          ? const {}
          : _refreshFromJson(json['refresh']),
      strings: (json['strings'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, Map<String, String>.from(e as Map)),
          ) ??
          {},
    );

Map<String, dynamic> _$MosaicConfigToJson(MosaicConfig instance) =>
    <String, dynamic>{
      'app': instance.app,
      'widgets': instance.widgets,
      'live_activities': instance.liveActivities,
      'controls': instance.controls,
      'refresh': _refreshToJson(instance.refresh),
      'strings': instance.strings,
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
      android: json['android'] == null
          ? null
          : MosaicAndroidWidgetConfig.fromJson(
              json['android'] as Map<String, dynamic>),
      ios: json['ios'] == null
          ? null
          : MosaicIosWidgetConfig.fromJson(json['ios'] as Map<String, dynamic>),
      label: json['label'] as String?,
      description: json['description'] as String?,
      push: json['push'] as bool? ?? false,
    );

Map<String, dynamic> _$MosaicWidgetConfigToJson(MosaicWidgetConfig instance) =>
    <String, dynamic>{
      'name': instance.name,
      'entry': instance.entry,
      'push': instance.push,
      'label': instance.label,
      'description': instance.description,
      'android': instance.android,
      'ios': instance.ios,
    };

MosaicLiveActivityConfig _$MosaicLiveActivityConfigFromJson(
        Map<String, dynamic> json) =>
    MosaicLiveActivityConfig(
      name: json['name'] as String,
      entry: json['entry'] as String,
      watch: json['watch'] as bool? ?? false,
    );

Map<String, dynamic> _$MosaicLiveActivityConfigToJson(
        MosaicLiveActivityConfig instance) =>
    <String, dynamic>{
      'name': instance.name,
      'entry': instance.entry,
      'watch': instance.watch,
    };

MosaicControlConfig _$MosaicControlConfigFromJson(Map<String, dynamic> json) =>
    MosaicControlConfig(
      name: json['name'] as String,
      entry: json['entry'] as String,
    );

Map<String, dynamic> _$MosaicControlConfigToJson(
        MosaicControlConfig instance) =>
    <String, dynamic>{
      'name': instance.name,
      'entry': instance.entry,
    };

MosaicRefreshSourceConfig _$MosaicRefreshSourceConfigFromJson(
        Map<String, dynamic> json) =>
    MosaicRefreshSourceConfig(
      url: json['url'] as String,
      method: json['method'] as String? ?? 'GET',
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          {},
      map: Map<String, String>.from(json['map'] as Map),
    );

Map<String, dynamic> _$MosaicRefreshSourceConfigToJson(
        MosaicRefreshSourceConfig instance) =>
    <String, dynamic>{
      'url': instance.url,
      'method': instance.method,
      'headers': instance.headers,
      'map': instance.map,
    };

MosaicAndroidWidgetConfig _$MosaicAndroidWidgetConfigFromJson(
        Map<String, dynamic> json) =>
    MosaicAndroidWidgetConfig(
      minSdk: (json['min_sdk'] as num?)?.toInt() ?? 21,
      sizes:
          (json['sizes'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
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
