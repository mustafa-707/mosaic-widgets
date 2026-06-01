import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> baseJson({Object? params}) => {
    'name': 'Weather',
    'root': {'__type': 'HWText', 'text': 'hi'},
    'updateInterval': null,
    'width': 2,
    'height': 2,
    'previewImage': null,
    'resizeMode': 'none',
    if (params != null) 'params': params,
  };

  test('IRDefinition.fromJson reads a params list and round-trips it', () {
    final params = [
      {
        'key': 'city',
        'label': 'City',
        'type': 'choice',
        'defaultValue': 'London',
        'choices': ['London', 'Paris', 'Tokyo'],
      },
      {
        'key': 'compact',
        'label': 'Compact mode',
        'type': 'toggle',
        'defaultValue': false,
        'choices': null,
      },
    ];
    final def = IRDefinition.fromJson(baseJson(params: params));
    expect(def.params, hasLength(2));
    expect(def.params[0]['key'], 'city');
    expect(def.params[0]['choices'], ['London', 'Paris', 'Tokyo']);
    expect(def.params[1]['type'], 'toggle');

    final out = def.toJson();
    expect(out['params'], params);
  });

  test('IRDefinition.fromJson defaults absent params to empty list', () {
    final def = IRDefinition.fromJson(baseJson());
    expect(def.params, isEmpty);
    expect(def.toJson()['params'], <dynamic>[]);
  });
}
