import 'package:mosaic_core/mosaic_core.dart';

IRDefinition irDef(Map<String, dynamic> rootJson, {String name = 'TestW'}) =>
    IRDefinition(name: name, root: IRNode.fromJson(rootJson));

/// Builds an [IRDefinition] carrying user-configurable [params]. Each param map
/// mirrors the DSL `MParam.toJson()` shape:
/// `{key, label, type, defaultValue, choices}`.
IRDefinition irDefWithParams(
  Map<String, dynamic> rootJson, {
  String name = 'TestW',
  required List<Map<String, dynamic>> params,
}) =>
    IRDefinition(name: name, root: IRNode.fromJson(rootJson), params: params);

/// Convenience builder for a single configurable param entry.
Map<String, dynamic> param(
  String key,
  String type, {
  String? label,
  Object? defaultValue,
  List<String>? choices,
}) =>
    {
      'key': key,
      'label': label ?? key,
      'type': type,
      'defaultValue': defaultValue,
      'choices': choices ?? const <String>[],
    };

Map<String, dynamic> text(Object value, {Map<String, dynamic>? style}) =>
    {'__type': 'HWText', 'text': value, 'style': style ?? <String, dynamic>{}};

Map<String, dynamic> bind(String key) => {'__type': 'HWBind', 'key': key};

Map<String, dynamic> container(Map<String, dynamic> child,
        {Map<String, dynamic>? extra}) =>
    {'__type': 'HWContainer', 'child': child, ...?extra};
