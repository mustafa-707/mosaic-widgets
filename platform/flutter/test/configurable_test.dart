import 'package:mosaic/dsl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MParam choice serializes with choices', () {
    final j = const MParam(
      key: 'city',
      label: 'City',
      type: MParamType.choice,
      defaultValue: 'London',
      choices: ['London', 'Paris', 'Tokyo'],
    ).toJson();
    expect(j, {
      'key': 'city',
      'label': 'City',
      'type': 'choice',
      'defaultValue': 'London',
      'choices': ['London', 'Paris', 'Tokyo'],
    });
  });

  test('MParam toggle with default serializes', () {
    final j = const MParam(
      key: 'compact',
      label: 'Compact mode',
      type: MParamType.toggle,
      defaultValue: true,
    ).toJson();
    expect(j['key'], 'compact');
    expect(j['label'], 'Compact mode');
    expect(j['type'], 'toggle');
    expect(j['defaultValue'], true);
    expect(j['choices'], isNull);
  });

  test('MParam defaults to text type', () {
    expect(const MParam(key: 'q', label: 'Query').toJson()['type'], 'text');
  });

  test('MosaicDefinition serializes params with two MParams', () {
    final def = MosaicDefinition(
      name: 'Weather',
      root: const MText('hello'),
      params: const [
        MParam(
          key: 'city',
          label: 'City',
          type: MParamType.choice,
          defaultValue: 'London',
          choices: ['London', 'Paris', 'Tokyo'],
        ),
        MParam(
          key: 'compact',
          label: 'Compact mode',
          type: MParamType.toggle,
          defaultValue: false,
        ),
      ],
    );
    final params = def.toJson()['params'] as List;
    expect(params, hasLength(2));
    expect(params[0], {
      'key': 'city',
      'label': 'City',
      'type': 'choice',
      'defaultValue': 'London',
      'choices': ['London', 'Paris', 'Tokyo'],
    });
    expect((params[1] as Map)['type'], 'toggle');
    expect((params[1] as Map)['defaultValue'], false);
  });

  test('MosaicDefinition without params emits empty list', () {
    final def = MosaicDefinition(name: 'Plain', root: const MText('x'));
    expect(def.toJson()['params'], <dynamic>[]);
  });
}
