import 'package:json_annotation/json_annotation.dart';

part 'ir.g.dart';

/// A fully-described intermediate-representation (IR) widget or live-activity
/// definition emitted by the Mosaic builder.
///
/// Each [IRDefinition] carries the tree of [IRNode]s rooted at [root], along
/// with layout metadata such as [width], [height], and [resizeMode].
@JsonSerializable(explicitToJson: true)
class IRDefinition {
  /// The logical name of this widget or live activity (matches
  /// [MosaicWidgetConfig.name] / [MosaicLiveActivityConfig.name]).
  final String name;

  /// The root node of the IR node tree.
  final IRNode root;

  /// Optional polling interval in seconds. `null` means no automatic update.
  final int? updateInterval;

  /// Grid columns occupied by this widget in its default size. Defaults to 2.
  final int width;

  /// Grid rows occupied by this widget in its default size. Defaults to 2.
  final int height;

  /// Optional path or URL for the widget preview image shown in the picker.
  final String? previewImage;

  /// How the widget content should be resized when the container changes size.
  /// Defaults to `'none'`.
  final String resizeMode;

  /// Creates an [IRDefinition].
  IRDefinition({
    required this.name,
    required this.root,
    this.updateInterval,
    this.width = 2,
    this.height = 2,
    this.previewImage,
    this.resizeMode = 'none',
  });

  /// Deserializes an [IRDefinition] from a JSON map.
  factory IRDefinition.fromJson(Map<String, dynamic> json) =>
      _$IRDefinitionFromJson(json);

  /// Serializes this definition to a JSON map.
  Map<String, dynamic> toJson() => _$IRDefinitionToJson(this);
}

/// A single node in the Mosaic IR tree.
///
/// On the wire each node is a flat JSON object where the special key
/// `__type` identifies the node kind and all remaining keys are the node's
/// fields. [IRNode] splits this into [type] (the `__type` tag) and [data]
/// (every other field), and re-merges them in [toJson].
@JsonSerializable(createFactory: false, createToJson: false)
class IRNode {
  /// The `__type` wire tag identifying the kind of node
  /// (e.g. `'HWText'`, `'HWColumn'`).
  @JsonKey(name: '__type')
  final String type;

  /// All node fields other than `__type`. The exact keys depend on [type].
  final Map<String, dynamic> data;

  /// Creates an [IRNode] with the given [type] tag and [data] fields.
  IRNode({required this.type, required this.data});

  /// Deserializes an [IRNode] from a JSON map, splitting the `__type` key
  /// into [type] and leaving the rest in [data].
  factory IRNode.fromJson(Map<String, dynamic> json) {
    return IRNode(
      type: json['__type'] as String,
      data: Map<String, dynamic>.from(json)..remove('__type'),
    );
  }

  /// Serializes this node back to the flat wire format, re-inserting
  /// `__type` as the first key.
  Map<String, dynamic> toJson() {
    return {'__type': type, ...data};
  }
}

/// A data-binding reference used inside an IR node's [data] map.
///
/// When a widget field is driven by live data rather than a literal value,
/// it is encoded as an [IRBind] with a [key] that the runtime resolves
/// against the current data context. Serializes to
/// `{"__type": "HWBind", "key": "<key>"}`.
class IRBind {
  /// The binding key resolved at runtime against the widget's data context.
  final String key;

  /// Creates an [IRBind] for the given [key].
  IRBind({required this.key});

  /// Deserializes an [IRBind] from a JSON map.
  factory IRBind.fromJson(Map<String, dynamic> json) =>
      IRBind(key: json['key'] as String);

  /// Serializes this bind reference to its wire format.
  Map<String, dynamic> toJson() => {'__type': 'HWBind', 'key': key};
}
