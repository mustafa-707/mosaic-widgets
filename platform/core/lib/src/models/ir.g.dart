// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ir.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IRDefinition _$IRDefinitionFromJson(Map<String, dynamic> json) => IRDefinition(
  name: json['name'] as String,
  root: IRNode.fromJson(json['root'] as Map<String, dynamic>),
  updateInterval: (json['updateInterval'] as num?)?.toInt(),
  width: (json['width'] as num?)?.toInt() ?? 2,
  height: (json['height'] as num?)?.toInt() ?? 2,
  previewImage: json['previewImage'] as String?,
  resizeMode: json['resizeMode'] as String? ?? 'none',
);

Map<String, dynamic> _$IRDefinitionToJson(IRDefinition instance) =>
    <String, dynamic>{
      'name': instance.name,
      'root': instance.root.toJson(),
      'updateInterval': instance.updateInterval,
      'width': instance.width,
      'height': instance.height,
      'previewImage': instance.previewImage,
      'resizeMode': instance.resizeMode,
    };

IRNode _$IRNodeFromJson(Map<String, dynamic> json) => IRNode(
  type: json['__type'] as String,
  data: json['data'] as Map<String, dynamic>,
);

Map<String, dynamic> _$IRNodeToJson(IRNode instance) => <String, dynamic>{
  '__type': instance.type,
  'data': instance.data,
};
