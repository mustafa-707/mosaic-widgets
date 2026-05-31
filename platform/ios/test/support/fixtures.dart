import 'package:hw_core/hw_core.dart';

IRDefinition irDef(Map<String, dynamic> rootJson, {String name = 'TestW'}) =>
    IRDefinition(name: name, root: IRNode.fromJson(rootJson));

Map<String, dynamic> text(Object value, {Map<String, dynamic>? style}) =>
    {'__type': 'HWText', 'text': value, 'style': style ?? <String, dynamic>{}};

Map<String, dynamic> bind(String key) => {'__type': 'HWBind', 'key': key};

Map<String, dynamic> container(Map<String, dynamic> child,
        {Map<String, dynamic>? extra}) =>
    {'__type': 'HWContainer', 'child': child, ...?extra};
