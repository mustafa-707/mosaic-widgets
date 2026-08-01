// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ir.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IRDefinition _$IRDefinitionFromJson(Map<String, dynamic> json) => IRDefinition(
      name: json['name'] as String,
      root: IRNode.fromJson(json['root'] as Map<String, dynamic>),
      compactRoot: json['compactRoot'] == null
          ? null
          : IRNode.fromJson(json['compactRoot'] as Map<String, dynamic>),
      updateInterval: (json['updateInterval'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt() ?? 2,
      height: (json['height'] as num?)?.toInt() ?? 2,
      previewImage: json['previewImage'] as String?,
      resizeMode: json['resizeMode'] as String? ?? 'none',
      params: (json['params'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$IRDefinitionToJson(IRDefinition instance) =>
    <String, dynamic>{
      'name': instance.name,
      'root': instance.root.toJson(),
      'compactRoot': instance.compactRoot?.toJson(),
      'updateInterval': instance.updateInterval,
      'width': instance.width,
      'height': instance.height,
      'previewImage': instance.previewImage,
      'resizeMode': instance.resizeMode,
      'params': instance.params,
    };
