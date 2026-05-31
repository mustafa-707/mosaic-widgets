import 'package:json_annotation/json_annotation.dart';

part 'ir.g.dart';

@JsonSerializable(explicitToJson: true)
class IRDefinition {
  final String name;
  final IRNode root;
  final int? updateInterval;
  final int width;
  final int height;
  final String? previewImage;
  final String resizeMode;

  IRDefinition({
    required this.name,
    required this.root,
    this.updateInterval,
    this.width = 2,
    this.height = 2,
    this.previewImage,
    this.resizeMode = 'none',
  });

  factory IRDefinition.fromJson(Map<String, dynamic> json) =>
      _$IRDefinitionFromJson(json);
  Map<String, dynamic> toJson() => _$IRDefinitionToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: false)
class IRNode {
  @JsonKey(name: '__type')
  final String type;
  final Map<String, dynamic> data;

  IRNode({required this.type, required this.data});

  factory IRNode.fromJson(Map<String, dynamic> json) {
    return IRNode(
      type: json['__type'] as String,
      data: Map<String, dynamic>.from(json)..remove('__type'),
    );
  }

  Map<String, dynamic> toJson() {
    return {'__type': type, ...data};
  }
}

class IRBind {
  final String key;
  IRBind({required this.key});

  factory IRBind.fromJson(Map<String, dynamic> json) =>
      IRBind(key: json['key'] as String);
  Map<String, dynamic> toJson() => {'__type': 'HWBind', 'key': key};
}
